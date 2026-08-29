local Log = require('src.utils.log')
local NPCRegistry = require('src.npc.npc_registry')
local LadderMerger = require('src.map.ladder_merger')
local TjTemplate = require('src.map.tj_template')

local EntityFactory = {}
EntityFactory.__index = EntityFactory

-- Per-process probe cache for res/entities/<type>.tj resolution: true/table
-- once a template parsed, false when the file doesn't exist (NPCs, players).
local templateCache = {}

-- Mirrors tmj.lua's raw-array property coercion for template default props
-- merged in below, so a value lands on the entity the same way a real
-- template reference would have delivered it.
local function coerceProp(prop)
	if prop.type == 'bool' then
		return prop.value == true or prop.value == 'true'
	elseif prop.type == 'int' or prop.type == 'float' then
		return tonumber(prop.value)
	elseif prop.type == 'object' then
		return { id = tonumber(prop.value) }
	end
	return prop.value
end

-- `map` (the owning Map instance) is threaded through to every constructed
-- entity as a second constructor arg (see loadEntity below) instead of
-- entities reaching for the `map` global themselves at construction time --
-- lets a unit test construct e.g. Switch/Cage/Teleport directly against a
-- stub map, without a whole Map/World stack running first.
function EntityFactory:new(searchPaths, typeIgnores, map)
	local ignores = {}
	for _, v in ipairs(typeIgnores or {}) do ignores[v] = true end
	return setmetatable({
		searchPaths = searchPaths,
		typeIgnores = ignores,
		map = map,
	}, EntityFactory)
end

-- Pre-pass over a layer's objects that folds per-rung ladder tile objects
-- into logical ladders (see src/map/ladder_merger.lua) and annotates each
-- rung object with its merged family rect (`ladderFamily`) and a `leadRung`
-- flag on the lowest rung. Pure and headless-safe: no World, no I/O.
-- Behavior is unchanged by the annotation itself -- entities just read the
-- annotations later (see src/entities/ladder.lua).
function EntityFactory.annotateLadders(objects)
	local rungs = {}
	for _, object in ipairs(objects or {}) do
		if object.type == 'ladder' then
			table.insert(rungs, object)
		end
	end

	local groups = LadderMerger.merge(rungs)
	for _, group in ipairs(groups) do
		-- one shared Rect per family so every rung's ladder.rect carries
		-- the real centre()/colliderShapeArgs() API player code expects
		local family = Rect(group.rect)
		for i, rung in ipairs(group.rungs) do
			rung.ladderFamily = family
			rung.leadRung = (i == #group.rungs)
		end
	end
	return groups
end

-- Walks every object layer, wiring update/draw and object:exec, and loads
-- an entity for each object via self:loadEntity (which also appends it to
-- layer.entities -- no separate insert needed here).
function EntityFactory:createEntities(map, world)
	for li, layer in ipairs(map.layers) do
		if layer.type == "objectgroup" then
			local objects = layer.objects
			layer.entities = {}

			self.annotateLadders(objects)

			function layer:update(dt)
				local remove_keys = {}
				for i, entity in pairs(self.entities) do
					if entity.remove_from_map_flag then
						table.insert(remove_keys, i)
					else
						entity:update(dt)
					end
				end

				table.sort(remove_keys)
				for i = #remove_keys, 1, -1 do
					local v = remove_keys[i]
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
	-- Map objects authored without a template reference (and runtime mock
	-- objects from replicator/cage/etc) still get the entity type's .tj
	-- defaults: template first, the object's own props win. Real templated
	-- instances were already merged at map parse, so they're skipped.
	if object.template == nil
		and not self.typeIgnores[entityName]
		and not NPCRegistry._types[entityName] then
		self:_mergeTemplateProps(entityName, object)
	end

	-- Handle NPC types via registry first
	if NPCRegistry._types[entityName] then
		local props = object.properties or {}
		local npc = NPCRegistry.spawn(entityName, object, props)
		if npc then
			npc.mapData = object
			object.entity = npc
			if layer and layer.entities then
				table.insert(layer.entities, npc)
			end
			return npc
		end
	end
	
	if not self.typeIgnores[entityName] then
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

-- Folds res/entities/<entityName>.tj defaults into object.properties when the
-- object carries none of its own (template keys untouched). Probe is cached:
-- a missing template (NPCs, players, unknown types) stays false for the
-- process lifetime. Entities that opt into template data read the merged
-- result via SpriteProps.fromObject at construction.
function EntityFactory:_mergeTemplateProps(entityName, object)
	local cached = templateCache[entityName]
	if cached == false then return end
	if cached == nil then
		local ok, result = pcall(TjTemplate.resolve, 'res/entities/' .. entityName .. '.tj')
		cached = ok and result or false
		templateCache[entityName] = cached
	end
	if not cached or not cached.object then return end

	local base = cached.object.properties
	if not base then return end

	local merged = {}
	if object.properties then
		for name, value in pairs(object.properties) do
			merged[name] = value
		end
	end
	for _, prop in ipairs(base) do
		if merged[prop.name] == nil then
			merged[prop.name] = coerceProp(prop)
		end
	end
	-- Sprite art's single source of truth is the template's inline tileset
	-- tile (what the editor previews), so a runtime mock inherits it too.
	if merged.image == nil and cached.tilesetImage then
		merged.image = cached.tilesetImage
	end
	object.properties = merged
end

return EntityFactory