-- tests/unit/npc_cleanup_test.lua
require('tests.support.headless_bootstrap')

local function test_oldNPCModules_notRequired()
    -- These should fail to load (modules deleted)
    local ok1, _ = pcall(require, 'src.npc.npc')
    local ok2, _ = pcall(require, 'src.npc.npc_states')
    local ok3, _ = pcall(require, 'src.npc.npc_brain')
    local ok4, _ = pcall(require, 'src.components.npc_follow')
    
    assert(ok1 == false, 'old npc.lua should not be loadable')
    assert(ok2 == false, 'old npc_states.lua should not be loadable')
    assert(ok3 == false, 'old npc_brain.lua should not be loadable')
    assert(ok4 == false, 'old npc_follow.lua should not be loadable')
    print('test_oldNPCModules_notRequired: PASS')
end

local function test_newArchitectureLoads()
    local NPCBase = require('src.npc.npc_base')
    local NPCConfig = require('src.npc.npc_config')
    local NPCRegistry = require('src.npc.npc_registry')
    local Spider = require('src.entities.npc_spider')
    local Robot = require('src.entities.robot')
    local BirdNPC = require('src.entities.npc_bird')
    local RabbitNPC = require('src.entities.npc_rabbit')
    
    assert(NPCBase ~= nil, 'NPCBase should load')
    assert(NPCConfig ~= nil, 'NPCConfig should load')
    assert(NPCRegistry ~= nil, 'NPCRegistry should load')
    assert(Spider ~= nil, 'Spider should load')
    assert(Robot ~= nil, 'Robot should load')
    assert(BirdNPC ~= nil, 'BirdNPC should load')
    assert(RabbitNPC ~= nil, 'RabbitNPC should load')
    print('test_newArchitectureLoads: PASS')
end

test_oldNPCModules_notRequired()
test_newArchitectureLoads()
print('All cleanup tests passed')