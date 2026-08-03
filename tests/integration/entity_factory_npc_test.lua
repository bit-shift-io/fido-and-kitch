-- tests/integration/entity_factory_npc_test.lua
local GameHarness = require('tests.support.game_harness')

local function test_entityFactory_usesRegistryForNPCs()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    -- Manually ensure globals are set (bootGlobals may have early-returned)
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    -- Now that globals are set, we can require NPC modules
    local NPCRegistry = require('src.npc.npc_registry')
    local NPCBase = require('src.npc.npc_base')
    local Class = _G.Class
    
    -- Mock NPC type
    local TestNPC = Class{__includes = NPCBase}
    function TestNPC:init(props)
        NPCBase.init(self, props)
        self.testType = 'test'
    end
    
    NPCRegistry.clear()
    NPCRegistry.registerType('test_npc', TestNPC)
    
    -- Add an NPC object to the game object layer (layer 2 = "game")
    local map = _G.map
    local gameLayer = map.layers[2]  -- "game" objectgroup
    table.insert(gameLayer.objects, {type = 'test_npc', x = 100, y = 100, properties = {maxSpeed = 120}})
    
    -- Now trigger entity creation
    local entityFactory = require('src.map.entity_factory')
    local factory = entityFactory:new({}, {}, map)
    local entities = factory:createEntities(map)
    
    -- Should have created the NPC via registry
    local npcs = NPCRegistry.getAll()
    assert(#npcs == 1, 'should have spawned 1 NPC via registry')
    assert(npcs[1].config.maxSpeed == 120, 'should pass properties')
    print('test_entityFactory_usesRegistryForNPCs: PASS')
end

local function test_entityFactory_skipsUnknownTypes()
    local game = GameHarness.startGame('tests/fixtures/flat_ground.lua')
    
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local NPCRegistry = require('src.npc.npc_registry')
    
    io.stderr:write("DEBUG: Before clear, registry count = " .. #NPCRegistry.getAll() .. "\n")
    io.stderr:flush()
    NPCRegistry.clear()
    io.stderr:write("DEBUG: After clear, registry count = " .. #NPCRegistry.getAll() .. "\n")
    io.stderr:flush()
    
    local map = _G.map
    local gameLayer = map.layers[2]  -- "game" objectgroup
    table.insert(gameLayer.objects, {type = 'unknown_npc_type', x = 100, y = 100, properties = {}})
    
    local entityFactory = require('src.map.entity_factory')
    local factory = entityFactory:new({}, {}, map)
    local entities = factory:createEntities(map)
    
    io.stderr:write("DEBUG: After createEntities, registry count = " .. #NPCRegistry.getAll() .. "\n")
    io.stderr:flush()
    
    local npcs = NPCRegistry.getAll()
    assert(#npcs == 0, 'should not spawn unknown NPC types, got ' .. #npcs)
    print('test_entityFactory_skipsUnknownTypes: PASS')
end

test_entityFactory_usesRegistryForNPCs()
test_entityFactory_skipsUnknownTypes()
print('All EntityFactory NPC tests passed')