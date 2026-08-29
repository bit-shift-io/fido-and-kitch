-- The drawbridge's spatial acceptance criteria -- the deck turning solid
-- before the player reaches the gap (no fall), and a wrong-side approach
-- staying blocked -- were previously deferred to a manual
-- `love . drawphysics with the drawbridge fixture` run, because the headless
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
local MAP = 'tests/fixtures/drawbridge_room.tmj'

-- The fixture's lone spawn point sits on the bridge's arrival
-- (crossingDirection = 'leftToRight') side; walking right from there
-- approaches the gap correctly.
-- Comfortably past the gap (tiles 4/5, x=128..160) and onto the far-side
-- ground (tiles 5-8, x=160..288).
--
-- Editor-first geometry: the drawbridge fixture object sits at (96,160)
-- carrying EXPLICIT collider offset/size props (matching the drawbridge.tj
-- template's editor-first defaults); at load the deck lands at
-- (128,128,32,32) -- exactly over the physical gap -- so the coordinates
-- below still describe the real collision. The offsets exist so the 64x64
-- art box and the one-tile deck are authored independently; see
-- res/entities/drawbridge.tj and NOTES.md 'Sprite offsets'.
local FAR_SIDE_X = 220
local GAP_START_X = 128
local GAP_END_X = 160
local MAX_APPROACH_FRAMES = 300

-- just clear of the deck's own footprint (right edge at GAP_END_X=160, plus
-- half the player's own collider width) -- used instead of FAR_SIDE_X when a
-- test needs to observe the close transition itself: walking all the way to
-- FAR_SIDE_X leaves so much extra travel time that a full open->close cycle
-- (short by design, see drawbridge.lua) can complete before the test ever
-- starts watching for it
local CLEAR_OF_FOOTPRINT_X = GAP_END_X + 15

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

test('wrong-side approach is an impassable dead-end; the bridge never opens', function()
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

	-- The original intent -- walking off the ledge drops you into the pit --
	-- is not what the engine does: FallState zeroes horizontal velocity on
	-- entry (src/player/states/fall_state.lua), so a player leaving the far
	-- platform has no air control and bump pins them against the platform's
	-- flush wall at the lip. Wrong-side approaches are an impassable
	-- dead-end (the player can never reach the trigger zone), which is the
	-- invariant this test guards. If air control is ever added to
	-- FallState, this test will trip and the 'falls into the gap' version
	-- can be restored.
	controller:press('left')

	local stepsStuckAtLip = 0
	local prevX
	local pinned = false
	local approached = false
	for frame = 1, MAX_APPROACH_FRAMES do
		FrameStepper.step(game, 1)
		local px = Queries.playerPositionV(player).x

		if px > GAP_END_X then
			approached = true
			assertEqual('closed', Queries.drawbridgeState(bridge), 'the bridge must not open while the wrong-side approach is on solid ground')
		end

		-- pinned at the lip: a run of frames with no further leftward travel
		-- while 'left' is held means the player is stopped at the gap edge
		if px <= GAP_END_X then
			if prevX ~= nil and px == prevX then
				stepsStuckAtLip = stepsStuckAtLip + 1
				if stepsStuckAtLip >= 10 then
					pinned = true
					break
				end
			else
				stepsStuckAtLip = 0
			end
		end

		assertFalse(Queries.playerIsDead(player), 'the wrong-side approach must never die -- it cannot reach the gap')
		prevX = px
	end

	controller:release('left')
	Capture.capture('02_blocked_at_lip')

	assertTrue(approached, 'expected the player to reach the gap edge from the wrong side')
	assertTrue(pinned, 'expected the wrong-side player to be stopped at the gap edge')
	local px = Queries.playerPositionV(player).x
	assertTrue(px <= GAP_END_X, 'expected the wrong-side player never to reach the correct side')
	assertEqual('closed', Queries.drawbridgeState(bridge), 'expected the bridge to remain closed')
end)

test('the bridge closes once the last occupant leaves, and a re-trigger mid-close reverses back to open', function()
	local game = GameHarness.startGame(MAP, {real = true})
	local controller = FakeInput.new()

	FrameStepper.step(game, 30) -- let the player land and settle

	local ingame = game.fsm.currentState
	local player = ingame.players[1]
	local bridge = Queries.findEntityByType(map, 'drawbridge')

	-- cross just clear of the footprint -- not all the way to FAR_SIDE_X,
	-- which (given how short the open/close durations are, see
	-- drawbridge.lua) would leave enough travel time for a full
	-- open->closing->closed cycle to finish before this test starts
	-- watching for 'closing' below
	controller:press('right')
	local crossed = false
	for _ = 1, MAX_APPROACH_FRAMES do
		FrameStepper.step(game, 1)
		assertFalse(Queries.playerIsDead(player), 'player must never die/fall while crossing')
		if Queries.playerPositionV(player).x >= CLEAR_OF_FOOTPRINT_X then
			crossed = true
			break
		end
	end
	controller:release('right')
	assertTrue(crossed, 'expected the player to cross clear of the footprint first')

	-- occupancy should drop now that the player has cleared the footprint,
	-- and closing should begin without any further input
	local seenClosing = false
	for _ = 1, MAX_APPROACH_FRAMES do
		FrameStepper.step(game, 1)
		if Queries.drawbridgeState(bridge) == 'closing' then
			seenClosing = true
			break
		end
	end
	assertTrue(seenClosing, 'expected the bridge to start closing once the last occupant left')
	Capture.capture('05_closing')

	-- immediately walk back onto the footprint while it's still mid-raise;
	-- the short return distance (well under the animation's duration at
	-- normal walk speed) is what actually exercises the reverse-in-place
	-- interrupt rather than a full close-then-reopen
	controller:press('left')
	local reopened = false
	for _ = 1, MAX_APPROACH_FRAMES do
		FrameStepper.step(game, 1)
		assertFalse(Queries.playerIsDead(player), 'player must never fall while re-crossing a reversing bridge')
		if Queries.drawbridgeState(bridge) == 'opening' then
			reopened = true
			break
		end
	end
	controller:release('left')

	assertTrue(reopened, 'expected re-entering the bridge mid-close to reverse it back to opening')
	Capture.capture('06_reopened')

	-- the regression this scenario exists to pin: a bridge that has reopened
	-- after starting to close must still be able to close again once
	-- cleared, not get stuck open for the rest of the level
	controller:press('right')
	local clearedAgain = false
	for _ = 1, MAX_APPROACH_FRAMES do
		FrameStepper.step(game, 1)
		assertFalse(Queries.playerIsDead(player), 'player must never fall while crossing clear a second time')
		if Queries.playerPositionV(player).x >= CLEAR_OF_FOOTPRINT_X then
			clearedAgain = true
			break
		end
	end
	controller:release('right')
	assertTrue(clearedAgain, 'expected the player to cross clear of the footprint a second time')

	local closedAgain = false
	for _ = 1, MAX_APPROACH_FRAMES do
		FrameStepper.step(game, 1)
		if Queries.drawbridgeState(bridge) == 'closed' then
			closedAgain = true
			break
		end
	end
	assertTrue(closedAgain, 'expected the reopened bridge to close again once cleared a second time (it must never get stuck open)')
	Capture.capture('07_closed_again')
end)

test('turning back before ever reaching the deck still raises the bridge again, not stuck open', function()
	-- This is the actual free-play repro for the stuck-down bug (DECISIONS.md
	-- Q3): the trigger tile (arrival side, one tile before the deck) is far
	-- enough from the deck that a player can enter it, open the bridge, and
	-- retreat entirely -- never once overlapping the deck tile itself. Under
	-- the old model the deck-only occupancy check never observed the player
	-- and the animation-finish transition to 'open' is unconditional, so the
	-- bridge got permanently stuck open with nothing ever holding it.
	local game = GameHarness.startGame(MAP, {real = true})
	local controller = FakeInput.new()

	FrameStepper.step(game, 30) -- let the player land and settle

	local ingame = game.fsm.currentState
	local player = ingame.players[1]
	local bridge = Queries.findEntityByType(map, 'drawbridge')

	assertEqual('closed', Queries.drawbridgeState(bridge), 'expected the bridge to start closed')

	-- walk right just far enough to enter the trigger tile and start opening,
	-- stopping well short of the deck (GAP_START_X=128)
	controller:press('right')
	local startedOpening = false
	for _ = 1, MAX_APPROACH_FRAMES do
		FrameStepper.step(game, 1)
		local x = Queries.playerPositionV(player).x
		assertTrue(x < GAP_START_X, 'expected to catch the open transition before ever reaching the deck')
		if Queries.drawbridgeState(bridge) ~= 'closed' then
			startedOpening = true
			break
		end
	end
	controller:release('right')
	assertTrue(startedOpening, 'expected entering the trigger tile to start opening the bridge')
	assertTrue(Queries.playerPositionV(player).x < GAP_START_X, 'expected the player to still be short of the deck')

	-- retreat fully back toward spawn, clear of the trigger tile too, without
	-- ever having touched the deck
	controller:press('left')
	FrameStepper.step(game, 60)
	controller:release('left')

	-- give the bridge every chance to settle: long enough for the open
	-- animation to finish and, if the fix is in place, to close again
	local closedAgain = false
	for _ = 1, MAX_APPROACH_FRAMES do
		FrameStepper.step(game, 1)
		if Queries.drawbridgeState(bridge) == 'closed' then
			closedAgain = true
			break
		end
	end

	assertTrue(closedAgain, 'expected the bridge to raise again once genuinely unheld -- it must never get stuck open')
end)

test('a second player follows the first across while it holds the bridge open', function()
	local game = GameHarness.startGame(MAP, {real = true})
	local controller = FakeInput.new()

	FrameStepper.step(game, 30) -- let both players land and settle

	local ingame = game.fsm.currentState
	local p1, p2 = ingame.players[1], ingame.players[2]
	local bridge = Queries.findEntityByType(map, 'drawbridge')

	-- P1 opens the bridge and stops on the deck itself, holding it open;
	-- P2 (idle at the same spawn, its own control scheme -- 'd', not
	-- 'right') then follows across while P1 is still there
	controller:press('right')
	local p1OnDeck = false
	for _ = 1, MAX_APPROACH_FRAMES do
		FrameStepper.step(game, 1)
		assertFalse(Queries.playerIsDead(p1), 'P1 must never die/fall while crossing')
		local x = Queries.playerPositionV(p1).x
		if x >= GAP_START_X and x <= GAP_END_X then
			p1OnDeck = true
			break
		end
	end
	assertTrue(p1OnDeck, 'expected P1 to reach the deck itself')
	assertTrue(Queries.drawbridgeState(bridge) == 'opening' or Queries.drawbridgeState(bridge) == 'open',
		'expected the bridge to be open (or opening) with P1 standing on it')
	Capture.capture('07_p1_holding_open')

	controller:press('d')
	local p2Crossed = false
	for _ = 1, MAX_APPROACH_FRAMES do
		FrameStepper.step(game, 1)
		assertFalse(Queries.playerIsDead(p1), 'P1 must never die/fall while P2 follows')
		assertFalse(Queries.playerIsDead(p2), 'P2 must never die/fall while following P1')
		if Queries.playerPositionV(p2).x >= CLEAR_OF_FOOTPRINT_X then
			p2Crossed = true
			break
		end
	end
	controller:release('right')
	controller:release('d')

	assertTrue(p2Crossed, 'expected P2 to follow P1 across the bridge P1 opened')
	Capture.capture('08_both_crossed')
end)
