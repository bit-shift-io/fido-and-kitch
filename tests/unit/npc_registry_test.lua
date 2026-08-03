-- tests/unit/npc_registry_test.lua
local HeadlessBootstrap = require('tests.support.headless_bootstrap')
local NPCRegistry = require('src.npc.npc_registry')
local NPCBase = require('src.npc.npc_base')
local Class = require('lib.hump.class')

-- Mock NPC type for testing
local TestNPC = Class{__includes = NPCBase}
function TestNPC:init(props)
    NPCBase.init(self, props)
    self.testType = 'test'
end

-- Reset world before each test run (Collider needs a global `world`)
HeadlessBootstrap.resetWorld()

local function test_registerType_and_spawn()
    NPCRegistry.clear()
    NPCRegistry.registerType('test_npc', TestNPC)
    
    local npc = NPCRegistry.spawn('test_npc', {x = 100, y = 200}, {maxSpeed = 150})
    assert(npc ~= nil, 'spawn should return NPC instance')
    assert(npc.x == 100 and npc.y == 200, 'should set position')
    assert(npc.config.maxSpeed == 150, 'should pass props to config')
    assert(npc.testType == 'test', 'should be TestNPC instance')
    print('test_registerType_and_spawn: PASS')
end

local function test_spawn_unknownType_returnsNil()
    NPCRegistry.clear()
    local npc = NPCRegistry.spawn('unknown_type', {x = 0, y = 0}, {})
    assert(npc == nil, 'unknown type should return nil')
    print('test_spawn_unknownType_returnsNil: PASS')
end

local function test_getAll_returnsAllSpawned()
    NPCRegistry.clear()
    NPCRegistry.registerType('test_npc', TestNPC)
    NPCRegistry.spawn('test_npc', {x = 0, y = 0}, {})
    NPCRegistry.spawn('test_npc', {x = 10, y = 10}, {})
    NPCRegistry.spawn('test_npc', {x = 20, y = 20}, {})
    
    local all = NPCRegistry.getAll()
    assert(#all == 3, 'should return all 3 NPCs')
    print('test_getAll_returnsAllSpawned: PASS')
end

local function test_getByType_filtersCorrectly()
    NPCRegistry.clear()
    NPCRegistry.registerType('test_npc', TestNPC)
    NPCRegistry.registerType('other_npc', TestNPC)
    NPCRegistry.spawn('test_npc', {x = 0, y = 0}, {})
    NPCRegistry.spawn('other_npc', {x = 10, y = 10}, {})
    NPCRegistry.spawn('test_npc', {x = 20, y = 20}, {})
    
    local testNPCs = NPCRegistry.getByType('test_npc')
    assert(#testNPCs == 2, 'should return only test_npc type')
    print('test_getByType_filtersCorrectly: PASS')
end

local function test_despawn_removesNPC()
    NPCRegistry.clear()
    NPCRegistry.registerType('test_npc', TestNPC)
    local npc = NPCRegistry.spawn('test_npc', {x = 0, y = 0}, {})
    assert(#NPCRegistry.getAll() == 1, 'should have 1 NPC')
    
    NPCRegistry.despawn(npc)
    assert(#NPCRegistry.getAll() == 0, 'should have 0 NPCs after despawn')
    print('test_despawn_removesNPC: PASS')
end

local function test_clear_removesAll()
    NPCRegistry.clear()
    NPCRegistry.registerType('test_npc', TestNPC)
    NPCRegistry.spawn('test_npc', {x = 0, y = 0}, {})
    NPCRegistry.spawn('test_npc', {x = 10, y = 10}, {})
    
    NPCRegistry.clear()
    assert(#NPCRegistry.getAll() == 0, 'clear should remove all')
    print('test_clear_removesAll: PASS')
end

local function test_onMapLoad_registersMapEntities()
    NPCRegistry.clear()
    NPCRegistry.registerType('test_npc', TestNPC)
    
    -- Mock map with NPC objects (matching STI map structure with layers)
    local mockMap = {
        layers = {
            {
                type = "objectgroup",
                objects = {
                    {type = 'test_npc', x = 50, y = 50, properties = {maxSpeed = 200}},
                    {type = 'test_npc', x = 150, y = 150, properties = {}},
                }
            }
        }
    }
    print("DEBUG: mockMap.layers = " .. #mockMap.layers)
    print("DEBUG: layer[1].type = " .. tostring(mockMap.layers[1].type))
    print("DEBUG: layer[1].objects = " .. #mockMap.layers[1].objects)
    print("DEBUG: NPCRegistry._types['test_npc'] = " .. tostring(NPCRegistry._types['test_npc'] ~= nil))
    NPCRegistry.onMapLoad(mockMap)
    
    local all = NPCRegistry.getAll()
    print("DEBUG: NPCRegistry.getAll() count = " .. #all)
    for i, npc in ipairs(all) do
        print("DEBUG: NPC " .. i .. " x=" .. npc.x .. " y=" .. npc.y .. " config.maxSpeed=" .. tostring(npc.config.maxSpeed))
    end
    assert(#all == 2, 'should spawn NPCs from map objects')
    assert(all[1].config.maxSpeed == 200, 'should apply properties from map')
    print('test_onMapLoad_registersMapEntities: PASS')
end

local function test_onMapUnload_clearsRegistry()
    NPCRegistry.clear()
    NPCRegistry.registerType('test_npc', TestNPC)
    NPCRegistry.spawn('test_npc', {x = 0, y = 0}, {})
    
    NPCRegistry.onMapUnload()
    assert(#NPCRegistry.getAll() == 0, 'onMapUnload should clear all')
    print('test_onMapUnload_clearsRegistry: PASS')
end

test_registerType_and_spawn()
test_spawn_unknownType_returnsNil()
test_getAll_returnsAllSpawned()
test_getByType_filtersCorrectly()
test_despawn_removesNPC()
test_clear_removesAll()
test_onMapLoad_registersMapEntities()
test_onMapUnload_clearsRegistry()
print('All NPCRegistry tests passed')