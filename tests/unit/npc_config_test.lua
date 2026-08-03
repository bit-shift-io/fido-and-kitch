-- tests/unit/npc_config_test.lua
local NPCConfig = require('src.npc.npc_config')

local function test_getDefaults_returnsTable()
    local defaults = NPCConfig.getDefaults()
    assert(type(defaults) == 'table', 'getDefaults should return a table')
    assert(defaults.maxSpeed ~= nil, 'defaults should have maxSpeed')
    assert(defaults.detectionRadius ~= nil, 'defaults should have detectionRadius')
    assert(defaults.behavior ~= nil, 'defaults should have behavior')
    print('test_getDefaults_returnsTable: PASS')
end

local function test_validate_acceptsValidProps()
    local valid = { maxSpeed = 100, detectionRadius = 200, behavior = 'follow', patrolPoints = {{x=0,y=0},{x=100,y=0}} }
    local ok, err = NPCConfig.validate(valid)
    assert(ok == true, 'valid props should pass: ' .. tostring(err))
    print('test_validate_acceptsValidProps: PASS')
end

local function test_validate_rejectsInvalidBehavior()
    local invalid = { behavior = 'invalid_behavior' }
    local ok, err = NPCConfig.validate(invalid)
    assert(ok == false, 'invalid behavior should fail')
    assert(type(err) == 'string', 'should return error message')
    print('test_validate_rejectsInvalidBehavior: PASS')
end

local function test_validate_rejectsNegativeSpeed()
    local invalid = { maxSpeed = -10 }
    local ok, err = NPCConfig.validate(invalid)
    assert(ok == false, 'negative speed should fail')
    print('test_validate_rejectsNegativeSpeed: PASS')
end

local function test_mergeWithDefaults_fillsMissing()
    local partial = { maxSpeed = 150 }
    local merged = NPCConfig.mergeWithDefaults(partial)
    assert(merged.maxSpeed == 150, 'should preserve provided value')
    assert(merged.detectionRadius == NPCConfig.getDefaults().detectionRadius, 'should fill missing with defaults')
    assert(merged.behavior == NPCConfig.getDefaults().behavior, 'should fill missing behavior')
    print('test_mergeWithDefaults_fillsMissing: PASS')
end

local function test_behaviorTypes_includeAllRequired()
    local types = NPCConfig.getBehaviorTypes()
    assert(types.follow ~= nil, 'should have follow')
    assert(types.wander ~= nil, 'should have wander')
    assert(types.patrol ~= nil, 'should have patrol')
    assert(types.chase ~= nil, 'should have chase')
    assert(types.attack ~= nil, 'should have attack')
    assert(types.flee ~= nil, 'should have flee')
    print('test_behaviorTypes_includeAllRequired: PASS')
end

test_getDefaults_returnsTable()
test_validate_acceptsValidProps()
test_validate_rejectsInvalidBehavior()
test_validate_rejectsNegativeSpeed()
test_mergeWithDefaults_fillsMissing()
test_behaviorTypes_includeAllRequired()
print('All NPCConfig tests passed')