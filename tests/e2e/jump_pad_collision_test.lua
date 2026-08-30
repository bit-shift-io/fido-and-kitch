-- The jump-pad path collision fix under real LÖVE, with real rendering.
-- Headless tiers already cover the mechanics thoroughly
-- (tests/unit/path_follow_test.lua, tests/integration/jump_pad_collision_test.lua);
-- what only this tier can answer: what it actually looks like when the
-- player stops mid-flight and drops, rather than flying through the wall or
-- pushable and getting shoved out by bump's normal slide resolution.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')
local Capture = require('tests.support.capture')

local FIXTURE = 'tests/fixtures/jump_pad_collision_room.tmj'

local function player1(game)
	return game.fsm.currentState.players[1]
end

test('a path blocked by a wall stops the player visibly short of it, then drops -- rendered', function()
	local game = GameHarness.startGame(FIXTURE, {real = true})
	FrameStepper.step(game, 5)

	local pad = Queries.findEntityByName(map, 'jump_pad_wall')
	local player = player1(game)
	player.collider:setPositionV(pad.collider:getPositionV())
	player.collider:setLinearVelocity(0, 0)

	Capture.capture('01_before_jump')

	pad:use(player)

	local blockedCaptured, landed = false, false
	for _ = 1, 300 do
		FrameStepper.step(game, 1)
		local stateName = player.fsm.currentState.name

		if not blockedCaptured and stateName == 'FallState' then
			blockedCaptured = true
			Capture.capture('02_blocked_dropping')
		end

		if stateName == 'WalkIdleState' then
			landed = true
			break
		end
	end

	assertTrue(blockedCaptured, 'expected the path to be blocked and hand off to FallState')
	Capture.capture('03_landed')
	assertTrue(landed, 'expected the player to land normally after the blocked exit')
end)

test('a path blocked by a pushable stops the player short of it without moving the box -- rendered', function()
	local game = GameHarness.startGame(FIXTURE, {real = true})
	FrameStepper.step(game, 5)

	local pad = Queries.findEntityByName(map, 'jump_pad_pushable')
	local box = Queries.findEntityByName(map, 'path_blocking_box')
	local player = player1(game)
	player.collider:setPositionV(pad.collider:getPositionV())
	player.collider:setLinearVelocity(0, 0)

	local boxStart = box.collider:getPositionV()

	Capture.capture('04_before_jump_pushable')

	pad:use(player)

	local blockedCaptured = false
	for _ = 1, 300 do
		FrameStepper.step(game, 1)
		if not blockedCaptured and player.fsm.currentState.name == 'FallState' then
			blockedCaptured = true
			Capture.capture('05_blocked_by_pushable')
			break
		end
	end

	assertTrue(blockedCaptured, 'expected the path to be blocked by the pushable and hand off to FallState')

	local boxEnd = box.collider:getPositionV()
	assertNear(boxStart.x, boxEnd.x, 0.5, 'the pushable must not move on impact')
	assertNear(boxStart.y, boxEnd.y, 0.5, 'the pushable must not move on impact')
end)
