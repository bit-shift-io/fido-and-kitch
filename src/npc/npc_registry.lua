-- src/npc/npc_registry.lua
local NPCRegistry = {}
local EventBus = require('src.utils.event_bus')

NPCRegistry._types = {}
NPCRegistry._instances = {}

function NPCRegistry.registerType(name, class)
    NPCRegistry._types[name] = class
end

function NPCRegistry.spawn(typeName, x, y, props)
    local class = NPCRegistry._types[typeName]
    if not class then
        return nil
    end
    
    props = props or {}
    props.x = x
    props.y = y
    
    local npc = class(props)
    npc._typeName = typeName  -- Store type name on instance for getByType
    table.insert(NPCRegistry._instances, npc)
    
    return npc
end

function NPCRegistry.despawn(npc)
    for i, inst in ipairs(NPCRegistry._instances) do
        if inst == npc then
            table.remove(NPCRegistry._instances, i)
            break
        end
    end
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
            EventBus.off('npc_death', npc._deathListener)
        end
        npc:queueRemove()
    end
    NPCRegistry._instances = {}
    -- Note: _types is NOT cleared - registered types persist across map loads
end

function NPCRegistry.clearAll()
    NPCRegistry.clear()
    NPCRegistry._types = {}
end

function NPCRegistry.onMapLoad(map)
    -- Clear instances but keep registered types
    for _, npc in ipairs(NPCRegistry._instances) do
        if npc._deathListener then
            EventBus.off('npc_death', npc._deathListener)
        end
        npc:queueRemove()
    end
    NPCRegistry._instances = {}
    
    if not map or not map.layers then return end
    
    for i, layer in ipairs(map.layers) do
        if layer.type == "objectgroup" and layer.objects then
            for j, obj in ipairs(layer.objects) do
                if obj.type and NPCRegistry._types[obj.type] then
                    local props = obj.properties or {}
                    props._typeName = obj.type  -- Track type for getByType
                    NPCRegistry.spawn(obj.type, obj.x, obj.y, props)
                end
            end
        end
    end
end

function NPCRegistry.onMapUnload()
    NPCRegistry.clear()
end

return NPCRegistry