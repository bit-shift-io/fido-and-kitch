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

	self.entityFactory = EntityFactory:new(self.searchPaths, self.typeIgnores, self)
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

-- Map size in pixels. Previously recomputed inline at each of its three call
-- sites (here, and twice in src/states/ingame_state.lua for the camera).
function Map:getPixelSize()
	return self.map.width * self.map.tilewidth, self.map.height * self.map.tileheight
end

function Map:resize(w, h)
	local windowOpen = love.window and love.window.isOpen and love.window.isOpen()
	if windowOpen or lg.isCreated then
		w = w or lg.getWidth()
		h = h or lg.getHeight()

		local mw, mh = self:getPixelSize()

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

-- Draws every object-layer entity in screen space, using the same tx/ty/sx/sy
-- transform the camera computed for the background/parallax draw (Map:draw2).
-- Kept as its own call (not folded into draw2) so InGameState can interleave
-- the debug overlay and HUD, which draw in a different space.
function Map:drawEntities(tx, ty, sx, sy)
	lg.push()
	lg.origin()
	lg.translate(math.floor(tx or 0), math.floor(ty or 0))
	lg.scale(sx or 1, sy or sx or 1)

	for _, layer in ipairs(self.map.layers) do
		if layer.type == "objectgroup" and layer.entities then
			for _, entity in ipairs(layer.entities) do
				entity:draw()
			end
		end
	end

	lg.pop()
end

function Map:getObjectById(id)
	return self.map.objects[id]
end

function Map:getEntitiesByType(entityType)
    local entities = {}
    for _, layer in ipairs(self.map.layers) do
        if layer.type == "objectgroup" and layer.entities then
            for _, entity in ipairs(layer.entities) do
                if entity.type == entityType then
                    table.insert(entities, entity)
                end
            end
        end
    end
    return entities
end

function Map:loadEntity(entityName, layer, object)
	return self.entityFactory:loadEntity(entityName, layer, object)
end

return Map