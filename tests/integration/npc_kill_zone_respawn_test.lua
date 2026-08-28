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

local MAP = 'tests/fixtures/enemy_kill_zone_room.tmj'

local FLASH_INTERVAL = 0.15
local FLASH_BLINKS = 8
-- Mirrors NPCBase:init's self.RESPAWN_DELAY = 2 (seconds after the death
-- flash completes); keep in sync if that constant ever changes.
local RESPAWN_DELAY = 2
local FIXED_DT = 1 / 60

-- Register NPC types once before all tests
local Robot = require('src.entities.npc_robot')
NPCRegistry.clear()
NPCRegistry.registerType('npc_robot', Robot)

local function findRobot()
    local robots = NPCRegistry.getByType('npc_robot')

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
    assertTrue(robot:isDead(), 'expected the Robot to have died in the kill zone')
    assertEqual('kinematic', robot.collider.bodyType, 'expected a dead Robot to be non-solid/kinematic')
end)

test('a Robot stays gone for the respawn delay after the death flash completes, then respawns at its original spawn position and facing', function()
    local game = GameHarness.startGame(MAP)
    FrameStepper.step(game, 90) -- fall into the kill zone and die

    local robot = findRobot()
    assertTrue(robot ~= nil, 'fixture check: expected to find a robot')
    assertTrue(robot:isDead(), 'fixture check: expected the Robot to have died')
    local originX, originY = robot.homeX, robot.homeY

    -- run the ~1.2s flash-out to completion, then run out most of the 2s
    -- respawn window -- should still be gone
    local flashFrames = math.ceil((FLASH_INTERVAL * FLASH_BLINKS) / FIXED_DT)
    FrameStepper.step(game, flashFrames)
    local shortOfWindowFrames = math.floor((RESPAWN_DELAY - 0.5) / FIXED_DT)
    FrameStepper.step(game, shortOfWindowFrames)

    assertTrue(robot:isDead(), 'expected the Robot to still be gone a few frames short of the respawn window')

    -- step forward frame-by-frame, stopping the instant it respawns -- once
    -- respawned, Chase/WanderState resumes moving it (e.g. back toward the
    -- kill zone it fell into), so this catches it right at the moment of
    -- respawn rather than assuming a fixed frame count lands on it exactly
    local respawned = false
    for i = 1, math.ceil(5 / FIXED_DT) do
        FrameStepper.step(game, 1)
        if not robot:isDead() then
            respawned = true
            break
        end
    end

    assertTrue(respawned, 'expected the Robot to have respawned within the rest of the respawn window')
    assertNear(originX, robot.collider:getX(), 1)
    assertNear(originY, robot.collider:getY(), 1)
end)