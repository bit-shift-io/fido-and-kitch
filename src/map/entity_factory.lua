local EntityFactory = {}
EntityFactory.__index = EntityFactory

local function loadEntity(entityName, searchPaths, typeIgnores, object)
	local in_ignore_list = tbl.findIndexEq(typeIgnores, entityName)
	if in_ignore_list == nil then
		local lastErr
		for k, pattern in pairs(searchPaths) do
			local path = pattern:gsub('%?', entityName)
			local ok, err = pcall(require, path)
			if not ok then
				lastErr = err
			else
				local entity = err(object)
				entity.mapData = object
				object.entity = entity
				return entity
			end
		end
		print('Entity Error: ' .. tostring(lastErr))
	end
	return nil
end

local function createEntitiesFromObjectGroupLayers(map, searchPaths, typeIgnores, world)
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

						print("exec script:", eventStr)

						local fn = utils.loadCode(eventStr, {
							object = object,
							entity = entity
						})
						fn()
					end
				end

				local entity = loadEntity(object.type, searchPaths, typeIgnores, object)
				if entity then
					table.insert(layer.entities, entity)
				end
			end
		end
	end
end

function EntityFactory:new(searchPaths, typeIgnores)
	return setmetatable({
		searchPaths = searchPaths,
		typeIgnores = typeIgnores,
	}, EntityFactory)
end

function EntityFactory:createEntities(map, world)
	createEntitiesFromObjectGroupLayers(map, self.searchPaths, self.typeIgnores, world)
end

function EntityFactory:loadEntity(entityName, layer, object)
	local in_ignore_list = tbl.findIndexEq(self.typeIgnores, entityName)
	if in_ignore_list == nil then
		local lastErr
		for k, pattern in pairs(self.searchPaths) do
			local path = pattern:gsub('%?', entityName)
			local ok, err = pcall(require, path)
			if not ok then
				lastErr = err
			else
				local entity = err(object)
				entity.mapData = object
				object.entity = entity
				if layer and layer.entities then
					table.insert(layer.entities, entity)
				end
				return entity
			end
		end
		print('Entity Error: ' .. tostring(lastErr))
	end
	return nil
end

return EntityFactory