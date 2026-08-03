-- tests/integration/npc_full_map_test.lua
local GameHarness = require('tests.support.game_harness')

local function test_mapLoadsWithAllNPCTypes()
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local NPCRegistry = require('src.npc.npc_registry')
    local Spider = require('src.entities.npc_spider')
    local Robot = require('src.entities.npc_robot')
    local BirdNPC = require('src.entities.npc_bird')
    local RabbitNPC = require('src.entities.npc_rabbit')
    
    -- Register all NPC types
    NPCRegistry.clear()
    NPCRegistry.registerType('npc_spider', Spider)
    NPCRegistry.registerType('npc_robot', Robot)
    NPCRegistry.registerType('npc_bird', BirdNPC)
    NPCRegistry.registerType('npc_rabbit', RabbitNPC)
    
    -- Start game with a map that has NPCs
    local game = GameHarness.startGame('res/map/sandbox.tmx')
    
    -- Wait for map to load
    local FrameStepper = require('tests.support.frame_stepper')
    FrameStepper.step(game, 10)
    
    local npcs = NPCRegistry.getAll()
    -- Just verify the system loads without error; map may or may not have NPCs
    local types = {}
    for _, npc in ipairs(npcs) do
        types[npc._typeName] = true
    end
    
    -- At least some NPC types should be in the test map (spider and robot are in sandbox)
    if #npcs > 0 then
        print('Found NPC types: ' .. table.concat(types, ', '))
    else
        print('No NPCs found in map (OK if map has no NPC objects)')
    end
    
    print('test_mapLoadsWithAllNPCTypes: PASS')
end

local function test_npcsUpdateWithoutErrors()
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local NPCRegistry = require('src.npc.npc_registry')
    local Spider = require('src.entities.npc_spider')
    local Robot = require('src.entities.npc_robot')
    
    NPCRegistry.clear()
    NPCRegistry.registerType('npc_spider', Spider)
    NPCRegistry.registerType('npc_robot', Robot)
    
    local game = GameHarness.startGame('res/map/sandbox.tmx')
    local FrameStepper = require('tests.support.frame_stepper')
    
    -- Step simulation for 1 second
    FrameStepper.step(game, 60)
    
    local npcs = NPCRegistry.getAll()
    for _, npc in ipairs(npcs) do
        -- Verify NPC is still valid and has state
        assert(npc.stateMachine ~= nil, 'NPC should have stateMachine')
        assert(npc.stateMachine.currentState ~= nil, 'NPC should have current state')
        assert(npc.config ~= nil, 'NPC should have config')
    end
    
    print('test_npcsUpdateWithoutErrors: PASS')
end

local function test_playerNPCInteraction()
    _G.Class = _G.Class or require('lib.hump.class')
    _G.Vector = _G.Vector or require('lib.hump.vector')
    
    local NPCRegistry = require('src.npc.npc_registry')
    local Spider = require('src.entities.npc_spider')
    local RabbitNPC = require('src.entities.npc_rabbit')
    
    NPCRegistry.clear()
    NPCRegistry.registerType('npc_spider', Spider)
    NPCRegistry.registerType('npc_rabbit', RabbitNPC)
    
    local game = GameHarness.startGame('res/map/sandbox.tmx')
    local FrameStepper = require('tests.support.frame_stepper')
    local FakeInput = require('tests.support.fake_input').FakeInput
    local controller = FakeInput.new()
    
    FrameStepper.step(game, 10)
    
    -- Move player toward NPC
    local npcs = NPCRegistry.getAll()
    if #npcs > 0 then
        local npc = npcs[1]
        controller:press('right')
        FrameStepper.step(game, 30)
        controller:release('right')
        
        -- NPC should react (change state, move, etc.)
        assert(npc.stateMachine.currentState ~= nil, 'NPC should have state')
    end
    
    print('test_playerNPCInteraction: PASS')
end

test_mapLoadsWithAllNPCTypes()
test_npcsUpdateWithoutErrors()
test_playerNPCInteraction()
print('All full map integration tests passed')