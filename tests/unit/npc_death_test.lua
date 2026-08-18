-- NPC death/respawn state transitions: headless, real Sprite/Collider/World
-- stack via tests/support/headless_bootstrap (see tests/unit/drawbridge_test.lua
-- for the established pattern). Robot stands in for the shared NPC behaviour
-- issue 01 builds; Spider-specific wrap release is covered separately.
local HeadlessBootstrap = require('tests.support.headless_bootstrap')
local Robot = require('src.entities.npc_robot')

local BLINK_INTERVAL = 0.15
local BLINKS = 8
local RESPAWN_DELAY = 2

local function makeRobot(x, y)
	HeadlessBootstrap.resetWorld()
	return Robot({x = x, y = y, width = 24, height = 24, properties = {}})
end

-- Sprite:blink toggles at most once per Sprite:update call, so completing
-- the death blink means stepping it blink-by-blink via the robot's update
-- (which ticks all components including the sprite).
local function runOutDeathBlink(robot)
	for _ = 1, BLINKS do
		robot:update(BLINK_INTERVAL)
	end
end

test('a freshly constructed Robot is alive, visible, and at full alpha', function()
	local robot = makeRobot(100, 100)

	assertFalse(robot:isDead())
	assertTrue(robot.visible)
	assertEqual(1, robot.alpha)
end)

test('dying locks the collider (non-solid/kinematic) and transitions to DeadState', function()
	local robot = makeRobot(100, 100)

	robot:die('water')

	assertTrue(robot:isDead())
	assertEqual('kinematic', robot.collider.bodyType)
end)

test('dying twice is idempotent -- the second deathType does not overwrite the first', function()
	local robot = makeRobot(100, 100)

	robot:die('water')
	robot:die('lava')

	assertEqual('water', robot.deathType)
end)

test('a Robot does not respawn before the 2s window has elapsed, even after the flash completes', function()
	local robot = makeRobot(100, 100)
	robot:die('water')

	runOutDeathBlink(robot) -- flash-out completes
	robot:update(RESPAWN_DELAY - 1) -- short of the 30s window

	assertTrue(robot:isDead(), 'expected the Robot to still be gone just short of the respawn window')
end)

test('a Robot respawns at its original position 2s after the flash-out completes', function()
	local robot = makeRobot(100, 100)
	local originX, originY = robot.collider:getX(), robot.collider:getY()
	robot.collider:setPosition(999, 999) -- simulate having wandered before dying
	robot:die('water')

	runOutDeathBlink(robot)
	robot:update(RESPAWN_DELAY + 0.1)

	assertFalse(robot:isDead(), 'expected the Robot to have respawned')
	assertEqual(originX, robot.collider:getX())
	assertEqual(originY, robot.collider:getY())
end)

test('a respawned Robot resumes wander at its home position', function()
	local robot = makeRobot(100, 100)
	robot:die('water')

	runOutDeathBlink(robot)
	robot:update(RESPAWN_DELAY + 0.1)

	assertFalse(robot:isDead())
	assertEqual(100, robot.x)
	assertEqual(100, robot.y)
end)
