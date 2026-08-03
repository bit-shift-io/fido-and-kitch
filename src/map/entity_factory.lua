local Log = require('src.utils.log')
local NPCRegistry = require('src.npc.npc_registry')

local EntityFactory = {}
EntityFactory.__index = EntityFactory

-- `map` (the owning Map instance) is threaded through to every constructed
-- entity as a second constructor arg (see loadEntity below) instead of
-- entities reaching for the `map` global themselves at construction time --
-- lets a unit test construct e.g. Switch/Cage/Teleport directly against a
-- stub map, without a whole Map/World stack running first.
function EntityFactory:new(searchPaths, typeIgnores, map)
	return setmetatable({
		searchPaths = searchPaths,
		typeIgnores = typeIgnores,
		map = map,
	}, EntityFactory)
end

-- Walks every object layer, wiring update/draw and object:exec, and loads
-- an entity for each object via self:loadEntity (which also appends it to
-- layer.entities -- no separate insert needed here).
function EntityFactory:createEntities(map, world)
	for li, layer in ipairs(map.layers) do
		if layer.type == "objectgroup" then
			local objects = layer.objects
			layer.entities = {}

			function layer:update(dt)
				local remove_keys = {}
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
					if eventStr then
						for k, v in pairs(object.properties) do
							local sub = string.format('map:getObjectById(object.properties.%s.id).entity:', k)
							eventStr = eventStr:gsub(string.format('%s:', k), sub)
						end

						Log.debug("exec script:", eventStr)

						local fn = utils.loadCode(eventStr, {
							object = object,
							entity = entity
						})
						fn()
					end
				end

				self:loadEntity(object.type, layer, object)
			end
		end
	end
end

function EntityFactory:loadEntity(entityName, layer, object)
	-- Handle NPC types via registry first
	if NPCRegistry._types[entityName] then
		local props = object.properties or {}
		local npc = NPCRegistry.spawn(entityName, object.x, object.y, props)
		if npc then
			npc.mapData = object
			object.entity = npc
			if layer and layer.entities then
				table.insert(layer.entities, npc)
			end
			return npc
		end
	end
	
	local in_ignore_list = tbl.findIndexEq(self.typeIgnores, entityName)
	if in_ignore_list == nil then
		local lastErr
		for k, pattern in pairs(self.searchPaths) do
			local path = pattern:gsub('%?', entityName)
			local ok, err = pcall(require, path)
			if not ok then
				lastErr = err
			else
				local entity = err(object, self.map)
				entity.mapData = object
				object.entity = entity
				if layer and layer.entities then
					table.insert(layer.entities, entity)
				end
				return entity
			end
		end
		Log.error('Entity Error: ' .. tostring(lastErr))
	end
	return nil
end

return EntityFactory