-- src/npc/npc_registry.lua
local NPCRegistry = {}
local EventBus = require("src.utils.event_bus")

NPCRegistry._types = {}
NPCRegistry._instances = {}

function NPCRegistry.registerType(name, class)
	NPCRegistry._types[name] = class
end

function NPCRegistry.spawn(typeName, object, props)
	local class = NPCRegistry._types[typeName]
	if not class then
		return nil
	end

	props = props or {}
	-- Set x/y from object if not already in props
	if object then
		if props.x == nil then
			props.x = object.x
		end
		if props.y == nil then
			props.y = object.y
		end
		-- Width/height: entity type defaults (bird=155, rabbit=142, etc.)
		-- take precedence over Tiled object size (which is just the editor
		-- tile size, not the intended runtime sprite size).  Only copy from
		-- the Tiled object when the entity type hasn't defined its own.
		-- NPCBase falls back to 16 if nothing is set.
	end

	-- Pass tiledObject (second arg) so NPCBase can use Rect.centreOfMapObject
	local npc = class(props, object)
	npc._typeName = typeName -- Store type name on instance for getByType
	table.insert(NPCRegistry._instances, npc)

	return npc
end

function NPCRegistry.getAll()
	return NPCRegistry._instances
end

function NPCRegistry.getByType(typeName)
	local result = {}
	for _, npc in ipairs(NPCRegistry._instances) do
		if npc._typeName == typeName then
			table.insert(result, npc)
		end
	end
	return result
end

function NPCRegistry.clear()
	for _, npc in ipairs(NPCRegistry._instances) do
		if npc._deathListener then
			EventBus.off("npc_death", npc._deathListener)
		end
		npc:queueRemove()
	end
	NPCRegistry._instances = {}
	-- Note: _types is NOT cleared - registered types persist across map loads
end

return NPCRegistry
