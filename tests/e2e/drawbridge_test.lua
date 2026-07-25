-- The drawbridge's spatial acceptance criteria -- the deck turning solid
-- before the player reaches the gap (no fall), and a wrong-side approach
-- staying blocked -- were previously deferred to a manual
-- `love . drawphysics map=drawbridge_fixture.lua` run, because the headless
-- harness can neither show nor capture the crossing. These two headed
-- scenarios make that check automated and reviewable (see HANDOFF.md and
-- .scratch/drawbridge/issues/03-open-on-correct-side.md).
--
-- Assertions go entirely through the shared query helpers -- gameplay
-- state, not the drawbridge component's internals, which the existing
-- tests/unit/drawbridge_test.lua already covers directly.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Queries = require('tests.support.queries')
local Capture = require('tests.support.capture')

local FakeInput = FakeInputModule.FakeInput
local MAP = 'res/map/drawbridge_fixture.lua'

-- The fixture's lone spawn point sits on the bridge's correct (facing =
-- 'left') side; walking right from there approaches the gap correctly.
-- Comfortably past the gap (tiles 4/5, x=128..160) and onto the far-side
-- ground (tiles 5-8, x=160..288).
local FAR_SIDE_X = 220
local GAP_START_X = 128
local GAP_END_X = 160
local MAX_APPROACH_FRAMES = 300

test('correct-side approach opens the deck before the gap and the player crosses without falling', function()
	local game = GameHarness.startGame(MAP, {real = true})
	local controller = FakeInput.new()

	FrameStepper.step(game, 30) -- let the player land and settle

	local ingame = game.fsm.currentState
	local player = ingame.players[1]
	local bridge = Queries.findEntityByType(map, 'drawbridge')

	assertEqual('closed', Queries.drawbridgeState(bridge), 'expected the bridge to start closed')

	Capture.capture('01_approach')

	local seenOpening = false
	local seenOpen = false
	local reachedFarSide = false

	controller:press('right')

	for _ = 1, MAX_APPROACH_FRAMES do
		FrameStepper.step(game, 1)

		-- the sharp criterion: never dead/fallen at ANY point during the
		-- crossing, checked every frame at normal walk speed -- a scenario
		-- that only checked the final position could pass while the
		-- player fell into the pit and respawned back onto solid ground
		assertFalse(Queries.playerIsDead(player), 'player must never die/fall while crossing')

		local state = Queries.drawbridgeState(bridge)
		local x = Queries.playerPositionV(player).x

		if not seenOpening and (state == 'opening' or state == 'open') then
			seenOpening = true
			Capture.capture('02_opening')
			-- the deck must already be solid before the player reaches the
			-- gap, not merely by the time they've crossed it
			assertTrue(x < GAP_START_X, 'expected the deck to start opening before the player reaches the gap')
		end

		if not seenOpen and state == 'open' then
			seenOpen = true
			Capture.capture('03_open')
		end

		if not reachedFarSide and x >= FAR_SIDE_X then
			reachedFarSide = true
			break
		end
	end

	controller:release('right')
	Capture.capture('04_crossed')

	assertTrue(seenOpening, 'expected the bridge to have started opening during the approach')
	assertTrue(seenOpen, 'expected the bridge to have reached fully open during the crossing')
	assertTrue(reachedFarSide, 'expected the player to reach the far side of the gap')
	assertFalse(Queries.playerIsDead(player), 'player must not be dead after crossing')

	local finalX = Queries.playerPositionV(player).x
	assertTrue(finalX >= FAR_SIDE_X, 'expected the player to have fully crossed onto the far side')
end)

test('wrong-side approach leaves the player blocked and the bridge closed', function()
	local game = GameHarness.startGame(MAP, {real = true})
	local controller = FakeInput.new()

	FrameStepper.step(game, 30) -- let the player land and settle

	local ingame = game.fsm.currentState
	local player = ingame.players[1]
	local bridge = Queries.findEntityByType(map, 'drawbridge')

	-- teleport onto the far (wrong) side, the same floor height as the
	-- spawn side, then let it settle before approaching from there
	player.collider:setX(240)
	FrameStepper.step(game, 10)

	assertEqual('closed', Queries.drawbridgeState(bridge), 'expected the bridge to start closed')
	Capture.capture('01_wrong_side_approach')

	controller:press('left')

	for _ = 1, MAX_APPROACH_FRAMES do
		FrameStepper.step(game, 1)

		assertFalse(Queries.playerIsDead(player), 'player must never die/fall while blocked at the bridge')
		assertEqual('closed', Queries.drawbridgeState(bridge), 'the bridge must never open from the wrong side')
	end

	controller:release('left')
	Capture.capture('02_outcome_blocked')

	assertEqual('closed', Queries.drawbridgeState(bridge), 'expected the bridge to remain closed')
	assertFalse(Queries.playerIsDead(player), 'player must not have died')

	local finalX = Queries.playerPositionV(player).x
	assertTrue(finalX > GAP_END_X, 'expected the player to have stayed on the far side, blocked by the barrier')
end)
