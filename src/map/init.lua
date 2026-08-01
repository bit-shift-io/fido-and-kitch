local sti = require('lib.sti')
local Tmx = require('src.map.tmx')
local EntityFactory = require('src.map.entity_factory')
local CollisionBuilder = require('src.map.collision_builder')
local ParallaxRenderer = require('src.map.parallax_renderer')
local lg = love.graphics

local Map = {}
Map.__index = Map

local function loadSti(path, plugins)
	if path:sub(-4) == '.tmx' then
		return sti(Tmx.parse(path), plugins)
	end
	return sti(path, plugins)
end

local function fileExists(path)
	if love and love.filesystem and love.filesystem.getInfo then
		return love.filesystem.getInfo(path) ~= nil
	end

	local file = io.open(path, 'r')
	if file then
		file:close()
		return true
	end
	return false
end

local function resolveMapFile(basePath)
	if basePath:match('%.tmx$') or basePath:match('%.lua$') then
		return basePath
	end
	if fileExists(basePath .. '.tmx') then
		return basePath .. '.tmx'
	end
	return basePath .. '.lua'
end

Map.resolveMapFile = resolveMapFile

function Map:new(path, world, debug)
	_G.map = self

	local map = loadSti(path, { "box2d" })
	self.map = map
	utils.proxyClass(self, self.map)

	self.typeIgnores = {'', 'spawn'}
	self.searchPaths = {
		'src.entities.?',
		'src.entities.?.?',
	}

	if world and world.type == 'love' then
		map:box2d_init(world._world)
	end

	self.entityFactory = EntityFactory:new(self.searchPaths, self.typeIgnores)
	self.collisionBuilder = CollisionBuilder:new()
	self.parallaxRenderer = ParallaxRenderer:new()

	self.entityFactory:createEntities(map, world)

	for li, layer in ipairs(map.layers) do
		layer.map = map
		if layer.properties.collision then
			self.collisionBuilder:createStaticPhysicsBodies(layer)
		end
		if layer.properties.ladder then
			self.collisionBuilder:createLadderVolumes(layer)
		end
	end

	self.collisionBuilder:createStaticPhysicsBodyBoundary(map)

	self:resize()

	local bgName = self.map.properties.background
	if type(bgName) == 'string' and bgName ~= '' then
		self.backgroundName = bgName
		self.backgroundMap = loadSti(resolveMapFile('res/backgrounds/' .. bgName))
	end

	return self
end

function Map:update(dt)
	self.map:update(dt)
end

function Map:resize(w, h)
	local windowOpen = love.window and love.window.isOpen and love.window.isOpen()
	if windowOpen or lg.isCreated then
		w = w or lg.getWidth()
		h = h or lg.getHeight()

		local mw = self.map.width * self.map.tilewidth
		local mh = self.map.height * self.map.tileheight

		local sx = w / mw
		local sy = h / mh

		local s = math.min(sx, sy)
		self.sx = s
		self.sy = s

		local tx = (w - (mw * self.sx)) / 2
		local ty = (h - (mh * self.sy)) / 2
		self.tx = tx
		self.ty = ty
	end
end

function Map:draw()
	self:draw2(self.tx, self.ty, self.sx, self.sy)
end

function Map:draw2(tx, ty, sx, sy)
	self.parallaxRenderer:draw(self, tx, ty, sx, sy)
end

function Map:getObjectById(id)
	return self.map.objects[id]
end

function Map:loadEntity(entityName, layer, object)
	return self.entityFactory:loadEntity(entityName, layer, object)
end

return Map