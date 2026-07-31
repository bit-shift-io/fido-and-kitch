local sti = require('lib.sti')
local mapParallax = require('src.map_parallax')
local Tmx = require('src.map.tmx')
local lg    =  love.graphics

local Map   = {}
Map.__index = Map

-- .tmx is parsed directly and handed to STI as a pre-built table; .lua
-- (Tiled's own export, or a hand-authored fixture) loads exactly as before.
-- Both map-construction sites below route through this, so levels and
-- background presets behave identically. See docs/adr/0004-direct-tmx-loading.md.
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

--- Resolves `basePath` (no extension) to its .tmx source if one exists,
-- falling back to its .lua export/fixture otherwise -- lets both formats
-- coexist during the .tmx migration (see docs/adr/0004-direct-tmx-loading.md)
-- without every caller needing to know which one a given map uses.
-- Also accepts a path that already has an extension (.tmx or .lua) and returns it as-is.
local function resolveMapFile(basePath)
	-- If the path already has an extension, use it as-is
	if basePath:match('%.tmx$') or basePath:match('%.lua$') then
		return basePath
	end
	if fileExists(basePath .. '.tmx') then
		return basePath .. '.tmx'
	end
	return basePath .. '.lua'
end

Map.resolveMapFile = resolveMapFile


local function getColliderFromShape(obj)
	if (obj.shape == 'rectangle') then
		-- rectangle is 4 point clockwise from topleft
		local rect = obj.rectangle
		local x = rect[1].x
		local y = rect[1].y
		local width = rect[3].x - x
		local height = rect[3].y - y
		local center_x = x + width * 0.5
		local center_y = y + height * 0.5
		return Collider{
			shape_type='rectangle',
			shape_arguments={center_x, center_y, width, height},
			body_type='static'
		}
	end
end







function Map:new(path, world, debug)
	_G.map = self

	-- https://stackoverflow.com/questions/68771724/lua-inheritance-on-existing-object
	local map = loadSti(path, { "box2d" })
	self.map = map
	utils.proxyClass(self, self.map)

	self.typeIgnores = {'', 'spawn'}
	self.searchPaths = {
		'src.entities.?',    -- src/entities/foo.lua
		'src.entities.?.?',  -- src/entities/foo/foo.lua
	}

	--local mmeta = getmetatable(map)

	--Map.__index = mmeta
	--Map2 = setmetatable(Map, mmeta)
	--map.__index = Map
	--map = setmetatable(map, Map)

	--map.__includes = Map
	--map = Class.new(map)

	--local midx = map.__index
	--local sidx = self.__index
	--map.__index = self.__index
	--map.__index.__index = midx

	--setmetatable(self, map)
	--setmetatable(map, Map)

	--map._map = map
	--set_funcs(w, w._world)

	--utils.set_funcs(self, self._map)

	-- Prepare collision objects
	if world and world.type == 'love' then
		map:box2d_init(world._world)
	end

	self:createEntitiesFromObjectGroupLayers()
	self:createStaticPhysicsBodyBoundary(map)

	for li, layer in ipairs(map.layers) do
		layer.map = map
		if (layer.properties.collision) then -- custom properties collisions=true
			self:createStaticPhysicsBodies(layer)
		end
		if (layer.properties.ladder) then -- custom properties ladders=true
			self:createLadderVolumes(layer)
		end
	end
--[[
	return setmetatable({
		--map = map,
		debug = debug or false
	  },
	  Map
	)
	]]--

	self:resize()

	-- Load background map if specified in map properties
	local bgName = self.map.properties.background
	if type(bgName) == 'string' and bgName ~= '' then
		self.backgroundName = bgName
		self.backgroundMap = loadSti(resolveMapFile('res/backgrounds/' .. bgName))
	end

	return self
end

function Map:createLadderVolumes(layer)
	local volumes = {}

	if (layer.type == 'objectgroup' and layer.objects) then -- object layer
		for i, obj in pairs(layer.objects) do -- loop rows
			local col = getColliderFromShape(obj)
			col:setType('static')
			col:setSensor(true)
			table.insert(volumes, col)
		end
	end -- object layer

	return volumes
end

function Map:createStaticPhysicsBodies(layer)
	local colliders = {}

	if (layer.type == 'objectgroup' and layer.objects) then -- object layer
		for i, obj in pairs(layer.objects) do -- loop rows
			local col = getColliderFromShape(obj)
			col:setType('static')
			table.insert(colliders, col)
		end
	end -- object layer


	if (layer.type == 'tilelayer' and layer.data) then -- tile layer
		for y, row in pairs(layer.data) do -- loop rows

			local prev = 0

			for x, cell in pairs(row) do -- loop columns
				local tileset = layer.map.tilesets[cell.tileset]
				local width   = cell.width
				local height   = cell.height
				local margin  = tileset.margin
				local spacing = tileset.spacing
				local offset_x = cell.offset.x + width * 0.5
				local offset_y = cell.offset.y + height * 0.5
				local quadX = ((x - 1) * width + margin + (x - 1) * spacing) + offset_x
				local quadY = ((y - 1) * height + margin + (y - 1) * spacing) + offset_y

				if (prev > 0) then
					local dx = quadX - prev
					if (dx ~= 32) then
						print('dx:', dx)
					end
				end
				print('rect:', quadX, quadY, width, height)
				local col = Collider{
					shape_type='rectangle', 
					shape_arguments={quadX, quadY, width, height}, 
					body_type='static'
				}
				table.insert(colliders, col)

				prev = quadX
			end
		end
	end -- tile layer


	return colliders
end

function Map:createStaticPhysicsBodyBoundary()
	local map = self.map
	local width = map.width * map.tilewidth
	local height = map.height * map.tileheight

	local depth = 10
	local boundaryLeft = Collider{shape_type='rectangle', shape_arguments={-depth * 0.5, height * 0.5, depth, height + (2 * depth)}, body_type='static'}
	local boundaryTop = Collider{shape_type='rectangle', shape_arguments={width * 0.5, -depth * 0.5, width + (2 * depth), depth}, body_type='static'}
	local boundaryRight = Collider{shape_type='rectangle', shape_arguments={width + (depth * 0.5), height * 0.5, depth, height + (2 * depth)}, body_type='static'}
	local boundaryBottom = Collider{shape_type='rectangle', shape_arguments={width * 0.5, height + (depth * 0.5), width + (2 * depth), depth}, body_type='static'}
--[[

	local b = Collider{shape_type='edge', shape_arguments={0, height, width, height}, body_type='static'}
	b:addShape{shape_type='edge', shape_arguments={0, 0, width, 0}}
	b:addShape{shape_type='edge', shape_arguments={0, 0, 0, height}}
	b:addShape{shape_type='edge', shape_arguments={width, 0, width, height}}
	]]--
	--return b
end

function Map:createEntitiesFromObjectGroupLayers()
	local thisMap = self
	local map = self.map
	-- we basically take each object layer and replace
	-- them with entities
	-- so the layer order is the render order
	for li, layer in ipairs(map.layers) do
		if layer.type == "objectgroup" then
			local objects = layer.objects
			layer.entities = {}

			function layer:update(dt) 
				remove_keys = {}
				for i, entity in pairs(self.entities) do
					if entity.remove_from_map_flag then
						table.insert(remove_keys, i)
					else
						entity:update(dt)
					end
				end

				for i, v in pairs(remove_keys) do
					local entity = self.entities[v]
					table.remove(self.entities, v)
					if entity.destroy_flag then
						entity:destroy()
					end
				end
			end

			function layer:draw() 
				for _, entity in pairs(self.entities) do
					entity:draw()
				end
			end

			for _, object in ipairs(objects) do

				function object:exec(propertyName, entity)
					local eventStr = object.properties[propertyName]
					if (eventStr) then
						for k, v in pairs(object.properties) do
							local sub = string.format('map:getObjectById(object.properties.%s.id).entity:', k)
							eventStr = eventStr:gsub(string.format('%s:', k), sub)
						end

						-- http://www.computercraft.info/forums2/index.php?/topic/8617-loadstring-has-some-issues-with-variable-scope/
						print("exec script:", eventStr)

						local fn = utils.loadCode(eventStr, {
							object=object,
							entity=entity
						})
						fn()
					end
				end

				thisMap:loadEntity(object.type, object.layer, object)
			end
		end
	end
end

function Map:loadEntity(entityName, layer, object)
	local in_ignore_list = tbl.findIndexEq(self.typeIgnores, entityName)
	if in_ignore_list == nil then
		-- move to a util function with option to supress error
		local lastErr
		for k, pattern in pairs(self.searchPaths) do
			local path = pattern:gsub('%?', entityName)
			local ok, err = pcall(require, path)
			if not ok then
				lastErr = err
			else
				local entity = err(object)
				entity.mapData = object -- store the map data in the entity
				object.entity = entity
				table.insert(layer.entities, entity)
				return entity
			end
		end
		print('Entity Error: ' .. tostring(lastErr))
	end

	return nil
end

--function Map:init(path, plugins, ox, oy)
--	local p = self.path
--	self.__index.init(self, path, plugins, ox, oy)
--end

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

		-- center the map
		local tx = (w - (mw * self.sx)) / 2
		local ty = (h - (mh * self.sy)) / 2
		self.tx = tx
		self.ty = ty
	end
end

function Map:draw()
	self:draw2(self.tx, self.ty, self.sx, self.sy)

	-- Draw Collision Map (useful for debugging)
	--if self.debug then
	--	love.graphics.setColor(1, 0, 0)
	--	self.map:box2d_draw()
	--end
end

function Map:draw2(tx, ty, sx, sy)
	local screenW, screenH = lg.getWidth(), lg.getHeight()
	
	-- Draw background in screen space, covering the full screen
	if self.backgroundMap then
		local cx, cy = mapParallax.computeCameraCenter(tx, ty, sx, sy, screenW, screenH)

		lg.origin()
		lg.setColor(1, 1, 1, 1)

		-- Map's on-screen bounds (where the map canvas will be drawn)
		local mapDrawW = self.map.width * self.map.tilewidth * sx
		local mapDrawH = self.map.height * self.map.tileheight * sy

		for _, layer in ipairs(self.backgroundMap.layers) do
			if layer.visible and layer.type == 'imagelayer' and layer.image and layer.opacity > 0 then
				local parallaxx = layer.parallaxx or 1
				local parallaxy = layer.parallaxy or 1

				-- Parallax: interpolate between screen center (parallax=0) and map on-screen center (parallax=1)
				local mapCenterX = tx + mapDrawW * 0.5
				local mapCenterY = ty + mapDrawH * 0.5
				local offsetX = (1 - parallaxx) * screenW * 0.5 + parallaxx * mapCenterX + (layer.offsetx or 0) * sx
				local offsetY = (1 - parallaxy) * screenH * 0.5 + parallaxy * mapCenterY + (layer.offsety or 0) * sy

				-- Scale image to cover the SCREEN (fit-to-cover on screenW/screenH)
				local imgW, imgH = layer.image:getWidth(), layer.image:getHeight()
				local s = math.max(screenW / imgW, screenH / imgH)
				local drawW, drawH = imgW * s, imgH * s

				-- offsetX/offsetY are the screen-space center positions
				local drawX = offsetX - drawW * 0.5
				local drawY = offsetY - drawH * 0.5

				lg.setColor(1, 1, 1, layer.opacity)
				lg.draw(layer.image, drawX, drawY, 0, s, s)
				lg.setColor(1, 1, 1, 1)
			end
		end
	end

	-- Draw main map layers in screen space (at camera scale)
	lg.push()
	lg.origin()
	lg.translate(math.floor(tx or 0), math.floor(ty or 0))
	lg.scale(sx or 1, sy or sx or 1)
	lg.setColor(1, 1, 1, 1)

	-- Draw tile layers and image layers only (object layers with entities drawn separately in InGameState)
	for _, layer in ipairs(self.layers) do
		if layer.visible and layer.opacity > 0 and (layer.type == 'tilelayer' or layer.type == 'imagelayer') then
			self:drawLayer(layer)
		end
	end

	if (conf.drawphysics) then
		world:draw()
	end
	
	lg.pop()
end

function Map:getObjectById(id)
	
	--for _, object in pairs(self.map.objects) do
	--	if object.id == id then
	--		return object
--		end
--	end
--
--	return nil
	return self.map.objects[id]
end

return Map