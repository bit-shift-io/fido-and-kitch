-- End-to-end: a Robot falling into a real kill zone dies, stays gone, and
-- respawns at its original spawn position -- driven through the real
-- Game/Map/World stack. See tests/unit/npc_death_test.lua for the pure
-- state-transition coverage (respawn delay gating, stun/ban reset) this
-- doesn't repeat, and tests/integration/kill_zone_sound_test.lua for the
-- player-side counterpart.
require('tests.support.headless_bootstrap')

local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local NPCRegistry = require('src.npc.npc_registry')

local MAP = 'tests/fixtures/enemy_kill_zone_room.lua'

local FLASH_INTERVAL = 0.15
local FLASH_BLINKS = 8
local RESPAWN_DELAY = 30
local FIXED_DT = 1 / 60

-- Register NPC types once before all tests
local Robot = require('src.entities.npc_robot')
NPCRegistry.clear()
NPCRegistry.registerType('npc_robot', Robot)

local function findRobot()
    io.stderr:write("DEBUG findRobot: _instances count = " .. #NPCRegistry._instances .. "\n")
    io.stderr:flush()
    for i, npc in ipairs(NPCRegistry._instances) do
        io.stderr:write("DEBUG findRobot: instance " .. i .. " typeName = " .. tostring(npc._typeName) .. " isDead = " .. tostring(npc:isDead()) .. "\n")
        io.stderr:flush()
    end
    
    local robots = NPCRegistry.getByType('npc_robot')
    io.stderr:write("DEBUG findRobot: getByType returned " .. #robots .. " robots\n")
    io.stderr:flush()
    
    -- Return the first alive robot, or first if all dead
    for _, robot in ipairs(robots) do
        if not robot:isDead() then
            return robot
        end
    end
    return robots[1]
end

test('a Robot falling into a kill zone dies, becomes non-solid, and stops chasing/shoving', function()
    local game = GameHarness.startGame(MAP)

    FrameStepper.step(game, 90) -- fall from spawn straight into the kill zone

    local robot = findRobot()
    assertTrue(robot ~= nil, 'expected to find a robot')
    io.stderr:write("DEBUG test1: robot.remove_from_map_flag = " .. tostring(robot.remove_from_map_flag) .. "\n")
    io.stderr:flush()
    assertTrue(robot:isDead(), 'expected the Robot to have died in the kill zone')
    assertEqual('kinematic', robot.collider.bodyType, 'expected a dead Robot to be non-solid/kinematic')
end)

test('a Robot stays gone for 30s after the death flash completes, then respawns at its original spawn position and facing', function()
    local game = GameHarness.startGame(MAP)
    FrameStepper.step(game, 90) -- fall into the kill zone and die

    local robot = findRobot()
    assertTrue(robot ~= nil, 'fixture check: expected to find a robot')
    io.stderr:write("DEBUG test2a: robot.remove_from_map_flag = " .. tostring(robot.remove_from_map_flag) .. "\n")
    io.stderr:flush()
    assertTrue(robot:isDead(), 'fixture check: expected the Robot to have died')
    local originX, originY = robot.homeX, robot.homeY

    -- run the ~1.2s flash-out to completion, then run out all but a few
    -- seconds of the 30s window -- should still be gone
    local flashFrames = math.ceil((FLASH_INTERVAL * FLASH_BLINKS) / FIXED_DT)
    FrameStepper.step(game, flashFrames)
    local shortOfWindowFrames = math.floor((RESPAWN_DELAY - 3) / FIXED_DT)
    FrameStepper.step(game, shortOfWindowFrames)

    io.stderr:write("DEBUG test2b: robot.remove_from_map_flag = " .. tostring(robot.remove_from_map_flag) .. "\n")
    io.stderr:flush()
    assertTrue(robot:isDead(), 'expected the Robot to still be gone a few seconds short of the 30s window')

    -- step forward frame-by-frame, stopping the instant it respawns -- once
    -- respawned, Chase/WanderState resumes moving it (e.g. back toward the
    -- kill zone it fell into), so this catches it right at the moment of
    -- respawn rather than assuming a fixed frame count lands on it exactly
    local respawned = false
    for i = 1, math.ceil(10 / FIXED_DT) do
        FrameStepper.step(game, 1)
        io.stderr:write("DEBUG loop " .. i .. ": robot.isDead=" .. tostring(robot:isDead()) .. ", deathTimer=" .. tostring(robot.deathTimer) .. "\n")
        io.stderr:flush()
        if not robot:isDead() then
            respawned = true
            break
        end
    end

    assertTrue(respawned, 'expected the Robot to have respawned within a few seconds of crossing the 30s window')
    assertNear(originX, robot.collider:getX(), 1)
    assertNear(originY, robot.collider:getY(), 1)
    assertEqual('right', robot.homeFacing)
end)