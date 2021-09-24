package.path = package.path .. ';res/?.lua;src/entities/?.lua'

local sti = require('lib/sti')

local lg    =  love.graphics

local Map   = {}
Map.__index = Map


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
			shape_type='Rectangle',
			shape_arguments={center_x, center_y, width, height},
		}
	end
end







function Map:new(path, world, debug)
	_G.map = self

	-- https://stackoverflow.com/questions/68771724/lua-inheritance-on-existing-object
	local map = sti(path, { "box2d" })
	self.map = map
	utils.proxyClass(self, self.map)

	self.typeIgnores = {'', 'spawn'}

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
	if world then
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
				local col = Collider{
					shape_type='Rectangle', 
					shape_arguments={quadX, quadY, width, height}, 
					body_type='static'
				}
				table.insert(colliders, col)
			end
		end
	end -- tile layer


	return colliders
end

function Map:createStaticPhysicsBodyBoundary()
	local map = self.map
	local width = map.width * map.tilewidth
	local height = map.height * map.tileheight

	local b = Collider{shape_type='Edge', shape_arguments={0, height, width, height}, body_type='static'}
	b:addShape{shape_type='Edge', shape_arguments={0, 0, width, 0}}
	b:addShape{shape_type='Edge', shape_arguments={0, 0, 0, height}}
	b:addShape{shape_type='Edge', shape_arguments={width, 0, width, height}}
	return b
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

				local in_ignore_list = utils.tableFind(thisMap.typeIgnores, object.type)
				if in_ignore_list == nil then
					-- move to a util function with option to supress error
					local ok, err = pcall(require, object.type) 
					if not ok then
						print('Entity Error: ' .. err)
					else
						local entity = err(object)
						entity.mapData = object -- store the map data in the entity
						object.entity = entity
						table.insert(layer.entities, entity)
					end
				end
			end
		end
	end
end

--function Map:init(path, plugins, ox, oy)
--	local p = self.path
--	self.__index.init(self, path, plugins, ox, oy)
--end

function Map:update(dt)
	self.map:update(dt)
end

function Map:resize(w, h)
	if lg.isCreated then
		-- scale map to fit the screen
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

		self.map.canvas = lg.newCanvas(mw, mh)
		self.map.canvas:setFilter("nearest", "nearest")
	end
end

function Map:draw()
	self:draw2(self.tx, self.ty, self.sx, self.sy)

	-- Draw Collision Map (useful for debugging)
	if self.debug then
		love.graphics.setColor(1, 0, 0)
		self.map:box2d_draw()
	end
end

function Map:draw2(tx, ty, sx, sy)
	local current_canvas = lg.getCanvas()
	lg.setCanvas(self.canvas)
	lg.clear()

	-- Scale map to 1.0 to draw onto canvas, this fixes tearing issues
	-- Map is translated to correct position so the right section is drawn
	lg.push()
	lg.origin()

	for _, layer in ipairs(self.layers) do
		if layer.visible and layer.opacity > 0 then
			self:drawLayer(layer)
		end
	end

	lg.pop()

	-- Draw canvas at 0,0; this fixes scissoring issues
	-- Map is scaled to correct scale so the right section is shown
	lg.push()
	lg.origin()
	lg.translate(math.floor(tx or 0), math.floor(ty or 0))
	lg.scale(sx or 1, sy or sx or 1)

	lg.setCanvas(current_canvas)
	lg.draw(self.canvas)

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