-- Reproduces a reported bug: climbing a ladder to the top and dismounting
-- onto the platform there made the player fly up a little above the
-- platform before falling back down to land. LadderState drives movement
-- by setting linear velocity directly on a kinematic body while climbing;
-- on exit it switches the collider back to dynamic/gravity-affected but
-- never cleared that leftover velocity, so the last climb frame's upward
-- velocity kept carrying the (now gravity-affected) body up until gravity
-- overcame it. See LadderState:exit() in src/player/player_states.lua.
--
-- Updated for the edge-key no-op model (user directive): pressing up at the
-- top of a ladder is IGNORED -- the player stays mounted instead of being
-- ejected to WalkIdleState/FallState. The only way off is sliding sideways,
-- so that is how this test dismounts before checking the anti-fly invariant.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Queries = require('tests.support.queries')

local FakeInput = FakeInputModule.FakeInput
local runUntil = FakeInputModule.runUntil

local MAP = 'tests/fixtures/ladder_platform_top_exit_room.tmj'

local function player1(game)
	return game.fsm.currentState.players[1]
end

test('climbing to the top of a ladder and dismounting onto a platform does not fly upward before landing', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()

	local player = player1(game)

	-- The fixture's spawn drops straight down the ladder column's interior,
	-- so under the no-gravity-zone model the fall is caught into LadderState
	-- before reaching the floor; climbing from that hang reaches the same
	-- platform-top spot the original ground-mount flow did.
	runUntil(game, function()
		return player.fsm.currentState.name == 'LadderState'
	end, 120)

	controller:press('up')

	-- First require actual climb progress: the mount may begin with a
	-- realign pause (x slides while y is frozen), which must not be
	-- mistaken for reaching the top.
	runUntil(game, function()
		return Queries.playerPositionV(player).y < 200
	end, FrameStepper.secondsToFrames(3))

	-- Climb until the player stops rising for good (the top of the column).
	local lastY = nil
	local stillFrames = 0
	runUntil(game, function()
		local y = Queries.playerPositionV(player).y
		if lastY ~= nil and math.abs(y - lastY) < 0.05 then
			stillFrames = stillFrames + 1
		else
			stillFrames = 0
		end
		lastY = y
		return stillFrames >= 12
	end, FrameStepper.secondsToFrames(3))

	-- Edge-key no-op: up at the top must be ignored, staying mounted.
	assertEqual('LadderState', player.fsm.currentState.name,
		'pressing up at the top of a ladder must be ignored, not eject the player')
	controller:release('up')

	-- Dismount by sliding sideways off the column; land on the platform.
	controller:press('right')
	local dismountY = nil
	local minYAfterDismount = nil

	for _ = 1, FrameStepper.secondsToFrames(2) do
		FrameStepper.step(game, 1)
		local stateName = player.fsm.currentState.name
		local y = Queries.playerPositionV(player).y

		if dismountY == nil and stateName == 'WalkIdleState' then
			dismountY = y
			minYAfterDismount = y
		elseif dismountY ~= nil and y < minYAfterDismount then
			minYAfterDismount = y
		end
	end

	controller:release('right')

	assertTrue(dismountY ~= nil, 'expected the player to dismount onto the platform at the top of the ladder')
	assertTrue(dismountY - minYAfterDismount < 1, 'expected the player to land on the platform without first flying upward past it (leftover climb velocity should not carry into the dynamic body)')
end)
