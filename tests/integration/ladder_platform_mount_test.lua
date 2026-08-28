-- Reproduces a reported bug: standing on a platform flush above a ladder
-- and pressing down to mount it jittered instead of descending -- the
-- collider was touching, not overlapping, the ladder's top edge, so the
-- per-frame "still on a ladder?" check saw no overlap and immediately
-- bounced back to FallState -> WalkIdleState, which re-triggered the mount
-- next frame. See PlayerMovement.resolveLadderOverlap for the fix.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Queries = require('tests.support.queries')

local FakeInput = FakeInputModule.FakeInput

local MAP = 'tests/fixtures/ladder_platform_room.tmj'

local function player1(game)
	return game.fsm.currentState.players[1]
end

test('pressing down on a platform flush above an off-centre ladder mounts and descends without jittering', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	FrameStepper.step(game, 60) -- settle onto the platform

	local player = player1(game)
	assertEqual('WalkIdleState', player.fsm.currentState.name, 'fixture check: expected the player to have settled on the platform, not already on the ladder')

	local startY = Queries.playerPositionV(player).y

	controller:press('down')

	local sawLadderState = false
	local bouncedOffAfterMounting = false
	for _ = 1, FrameStepper.secondsToFrames(0.6) do
		FrameStepper.step(game, 1)
		local stateName = player.fsm.currentState.name
		if stateName == 'LadderState' then
			sawLadderState = true
		elseif sawLadderState then
			bouncedOffAfterMounting = true
		end
	end

	controller:release('down')

	assertTrue(sawLadderState, 'expected pressing down to mount the ladder')
	assertFalse(bouncedOffAfterMounting, 'expected the player to stay mounted on the ladder, not bounce back off while still holding down')

	local endY = Queries.playerPositionV(player).y
	assertTrue(endY > startY, 'expected the player to have descended the ladder')
end)
