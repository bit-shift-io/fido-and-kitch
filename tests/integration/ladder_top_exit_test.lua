-- Reproduces a reported bug: climbing a ladder to the top and dismounting
-- onto the platform there made the player fly up a little above the
-- platform before falling back down to land. LadderState drives movement
-- by setting linear velocity directly on a kinematic body while climbing;
-- on exit it switches the collider back to dynamic/gravity-affected but
-- never cleared that leftover velocity, so the last climb frame's upward
-- velocity kept carrying the (now gravity-affected) body up until gravity
-- overcame it. See LadderState:exit() in src/player/player_states.lua.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Queries = require('tests.support.queries')

local FakeInput = FakeInputModule.FakeInput

local MAP = 'tests/fixtures/ladder_platform_top_exit_room.lua'

local function player1(game)
	return game.fsm.currentState.players[1]
end

test('climbing to the top of a ladder and dismounting onto a platform does not fly upward before landing', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	FrameStepper.step(game, 60) -- settle onto the floor at the base of the ladder

	local player = player1(game)
	assertEqual('WalkIdleState', player.fsm.currentState.name, 'fixture check: expected the player to have settled on the floor at the base of the ladder')

	controller:press('up')

	local sawLadderState = false
	local dismountY = nil
	local minYAfterDismount = nil

	for _ = 1, FrameStepper.secondsToFrames(2) do
		FrameStepper.step(game, 1)
		local stateName = player.fsm.currentState.name
		local y = Queries.playerPositionV(player).y

		if stateName == 'LadderState' then
			sawLadderState = true
		end

		if sawLadderState and stateName == 'WalkIdleState' and dismountY == nil then
			dismountY = y
			minYAfterDismount = y
		elseif dismountY ~= nil and y < minYAfterDismount then
			minYAfterDismount = y
		end
	end

	controller:release('up')

	assertTrue(sawLadderState, 'expected pressing up to mount and climb the ladder')
	assertTrue(dismountY ~= nil, 'expected the player to dismount onto the platform at the top of the ladder')
	assertTrue(dismountY - minYAfterDismount < 1, 'expected the player to land on the platform without first flying upward past it (leftover climb velocity should not carry into the dynamic body)')
end)
