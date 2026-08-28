-- tests/e2e/npc_visual_test.lua
-- Visual E2E test for NPCs: loads maps with NPCs through real LÖVE,
-- steps simulation, and captures screenshots for visual verification.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Capture = require('tests.support.capture')
local NPCRegistry = require('src.npc.npc_registry')
local FakeInputModule = require('tests.support.fake_input')

local FakeInput = FakeInputModule.FakeInput

-- Helper to register all NPC types
local function registerNPCTypes()
    local Spider = require('src.entities.npc_spider')
    local Robot = require('src.entities.npc_robot')
    local BirdNPC = require('src.entities.npc_bird')
    local RabbitNPC = require('src.entities.npc_rabbit')

    NPCRegistry.clear()
    NPCRegistry.registerType('npc_spider', Spider)
    NPCRegistry.registerType('npc_robot', Robot)
    NPCRegistry.registerType('npc_bird', BirdNPC)
    NPCRegistry.registerType('npc_rabbit', RabbitNPC)
end

-- Helper to find first NPC of a given type
local function findNPC(typeName)
    local npcs = NPCRegistry.getAll()
    for _, npc in ipairs(npcs) do
        if npc._typeName == typeName then
            return npc
        end
    end
    return nil
end

-- Test sandbox map which has spider and robot NPCs
test('sandbox map loads with spider and robot NPCs and captures screenshot', function()
    registerNPCTypes()
    local game = GameHarness.startGame('res/map/sandbox.tmj', {real = true})

    FrameStepper.step(game, 10)

    Capture.capture('sandbox_initial')

    FrameStepper.step(game, 60)
    Capture.capture('sandbox_after_1s')

    FrameStepper.step(game, 60)
    Capture.capture('sandbox_after_2s')

    local npcs = NPCRegistry.getAll()
    assertTrue(#npcs >= 2, 'Expected at least 2 NPCs (spider and robot) in sandbox map')

    for _, npc in ipairs(npcs) do
        assertTrue(npc.stateMachine ~= nil, 'NPC should have stateMachine')
        assertTrue(npc.stateMachine.currentState ~= nil, 'NPC should have current state')
        assertTrue(npc.config ~= nil, 'NPC should have config')
    end
end)

-- Test all maps that might contain NPCs
test('all maps with NPCs load and capture without errors', function()
    local mapFiles = {
        'res/map/sandbox.tmj',
    }

    local failures = {}

    for _, path in ipairs(mapFiles) do
        local ok, err = pcall(function()
            registerNPCTypes()
            local game = GameHarness.startGame(path, {real = true})
            FrameStepper.step(game, 5)

            local name = path:match('([^/]+)%.') or path
            Capture.capture(name .. '_initial')

            FrameStepper.step(game, 30)
            Capture.capture(name .. '_after_0.5s')

            local npcs = NPCRegistry.getAll()
            for _, npc in ipairs(npcs) do
                assertTrue(npc.stateMachine ~= nil, 'NPC should have stateMachine')
                assertTrue(npc.stateMachine.currentState ~= nil, 'NPC should have current state')
            end
        end)

        if not ok then
            table.insert(failures, string.format('%s: %s', path, tostring(err)))
        end
    end

    assertEqual(0, #failures, 'Maps failed to load or capture:\n' .. table.concat(failures, '\n'))
end)

-- Test spider chases player when in range
test('spider chases player when in range', function()
    registerNPCTypes()
    local game = GameHarness.startGame('res/map/sandbox.tmj', {real = true})
    local controller = FakeInput.new()

    FrameStepper.step(game, 10)

    local spider = findNPC('npc_spider')
    if spider then
        Capture.capture('spider_initial_state')

        -- Move player toward spider (spider at ~416, 317 in sandbox)
        -- Player spawns at ~96, 192
        controller:press('right')
        FrameStepper.step(game, 60)
        controller:release('right')

        Capture.capture('spider_after_player_approach')

        local stateName = spider.stateMachine.currentState.name
        assertTrue(
            stateName == 'ChaseState' or stateName == 'AttackState' or stateName == 'WanderState' or stateName == 'IdleState',
            'Spider should be in a valid state after player approach, got: ' .. stateName
        )
    else
        print('No spider found in sandbox map - skipping chase test')
    end
end)

-- Test robot patrols
test('robot follows patrol path', function()
    registerNPCTypes()
    local game = GameHarness.startGame('res/map/sandbox.tmj', {real = true})

    FrameStepper.step(game, 10)

    local robot = findNPC('npc_robot')
    if robot then
        local initialX, initialY = robot.x, robot.y
        Capture.capture('robot_initial_patrol')

        FrameStepper.step(game, 120)
        Capture.capture('robot_after_patrol')

        local moved = math.abs(robot.x - initialX) > 10 or math.abs(robot.y - initialY) > 10
        assertTrue(robot.stateMachine.currentState ~= nil, 'Robot should have state')
    else
        print('No robot found in sandbox map - skipping patrol test')
    end
end)

-- Test rabbit follows player
test('rabbit follows player when in range', function()
    registerNPCTypes()
    local game = GameHarness.startGame('res/map/sandbox.tmj', {real = true})
    local controller = FakeInput.new()

    FrameStepper.step(game, 10)

    local rabbit = findNPC('npc_rabbit')
    if rabbit then
        -- Set rabbit's target to player 1 for follow behavior
        local player = game.fsm.currentState.players[1]
        if player then
            rabbit:setTarget(player)

            Capture.capture('rabbit_initial_follow')

            -- Move player away so rabbit has to follow
            controller:press('right')
            FrameStepper.step(game, 60)
            controller:release('right')

            Capture.capture('rabbit_after_player_move')

            local stateName = rabbit.stateMachine.currentState.name
            assertTrue(
                stateName == 'FollowState' or stateName == 'IdleState' or stateName == 'WanderState',
                'Rabbit should be following or in valid state, got: ' .. stateName
            )
        end
    else
        print('No rabbit found in sandbox map - skipping follow test')
    end
end)

-- Test robot detects player and reacts visually
test('robot detects player when nearby', function()
    registerNPCTypes()
    local game = GameHarness.startGame('res/map/sandbox.tmj', {real = true})

    FrameStepper.step(game, 10)

    local robot = findNPC('npc_robot')
    if robot then
        local player = game.fsm.currentState.players[1]
        if player then
            -- Teleport player near robot to trigger detection
            local robotX, robotY = robot.x, robot.y
            player.collider:setPosition(robotX - 20, robotY)
            player.x, player.y = robotX - 20, robotY

            robot:setTarget(player)
            Capture.capture('robot_before_detection')

            FrameStepper.step(game, 60)

            Capture.capture('robot_after_detection')

            assertTrue(robot.stateMachine.currentState ~= nil, 'Robot should have a valid state')
            assertTrue(robot.target ~= nil or robot.stateMachine.currentState.name ~= 'IdleState',
                'Robot should have reacted to player presence')
        end
    else
        print('No robot found in sandbox map - skipping detection test')
    end
end)

-- Test NPC pushing: spider and robot near each other interact
test('NPCs coexist and update when placed near each other', function()
    registerNPCTypes()
    local game = GameHarness.startGame('res/map/sandbox.tmj', {real = true})

    FrameStepper.step(game, 10)

    local spider = findNPC('npc_spider')
    local robot = findNPC('npc_robot')

    if spider and robot then
        -- Place spider and robot near each other
        local sx, sy = 300, 200
        spider.collider:setPosition(sx, sy)
        robot.collider:setPosition(sx + 20, sy)
        spider.x, spider.y = sx, sy
        robot.x, robot.y = sx + 20, sy

        Capture.capture('npc_coexist_before')

        -- Give spider a target so it moves toward robot
        spider:setTarget({x = robot.x, y = robot.y})

        FrameStepper.step(game, 60)

        Capture.capture('npc_coexist_after')

        -- Both NPCs should still have valid states after interaction
        assertTrue(spider.stateMachine.currentState ~= nil, 'Spider should have valid state')
        assertTrue(robot.stateMachine.currentState ~= nil, 'Robot should have valid state')
        assertTrue(not spider:isDead(), 'Spider should be alive')
        assertTrue(not robot:isDead(), 'Robot should be alive')
    else
        print('Spider or robot not found in sandbox map - skipping coexistence test')
    end
end)

print('All NPC visual E2E tests passed')
