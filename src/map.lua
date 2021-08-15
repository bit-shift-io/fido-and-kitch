package.path = package.path .. ';res/?.lua;src/entities/?.lua'

local sti = require('lib/sti')

local Map   = {}
Map.__index = Map

local function createStaticPhysicsBodies(layer)
	local colliders = {}

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

	return colliders
end


local function createStaticPhysicsBodyBoundary(map)
	local width = map.width * map.tilewidth
	local height = map.height * map.tileheight

	local b = Collider{shape_type='Edge', shape_arguments={0, height, width, height}, body_type='static'}
	b:addShape{shape_type='Edge', shape_arguments={0, 0, width, 0}}
	b:addShape{shape_type='Edge', shape_arguments={0, 0, 0, height}}
	b:addShape{shape_type='Edge', shape_arguments={width, 0, width, height}}
	return b
end



local function createEntitiesFromObjectGroupLayers(map)
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
				-- move to a util function with option to supress error
				local ok, err = pcall(require, object.type) 
				if not ok then
					print('Entity Error: ' .. err)
				else
					local entity = err(object)
					table.insert(layer.entities, entity)
				end
			end
		end
	end
end

function Map:new(path, world, debug)

	-- https://stackoverflow.com/questions/68771724/lua-inheritance-on-existing-object
	local map = sti(path, { "box2d" })

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

	createEntitiesFromObjectGroupLayers(map)
	createStaticPhysicsBodyBoundary(map)

	for li, layer in ipairs(map.layers) do
		layer.map = map
		-- custom properties physics=true
		if (layer.properties.physics) then
			createStaticPhysicsBodies(layer)
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
	return map
end

--function Map:init(path, plugins, ox, oy)
--	local p = self.path
--	self.__index.init(self, path, plugins, ox, oy)
--end

function Map:update(dt)
	print('YAY! we have done it!')
	self.map:update(dt)
end

function Map:draw()
	self.map:draw()

	-- Draw Collision Map (useful for debugging)
	if self.debug then
		love.graphics.setColor(1, 0, 0)
		self.map:box2d_draw()
	end
end

return Map