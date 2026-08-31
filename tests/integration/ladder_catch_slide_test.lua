-- Regression test for the side-entry fall-catch trap: a player who walks or
-- falls into a ladder volume while ALREADY HOLDING a horizontal key used to
-- be handed straight from the catch ('climbing') into 'sliding', which slid
-- them sideways out of the volume and ejected them into FallState with dead
-- keys (falls have no air control). The catch must ignore horizontal keys
-- that were held before the catch; only a fresh press on the ladder slides.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Queries = require('tests.support.queries')

local MAP = 'tests/fixtures/ladder_fall_catch_room.tmj'
local CENTRE_X = 144 -- merged ladder centre-x in the fixture

local function player1(game)
	return game.fsm.currentState.players[1]
end

test('a fall-catch while holding left hangs instead of sliding out of the ladder', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInputModule.FakeInput.new()
	local player = player1(game)

	-- Hold left BEFORE entering the volume (stale key from walking/falling),
	-- then drop into the column off-centre to its right.
	controller:press('left')
	player.collider:setPosition(CENTRE_X + 8, 240)

	for _ = 1, FrameStepper.secondsToFrames(1.5) do
		FrameStepper.step(game, 1)
	end

	assertEqual('LadderState', player.fsm.currentState.name,
		'a caught player must stay on the ladder even with a stale held direction')
	local x = Queries.playerPositionV(player).x
	assertTrue(math.abs(x - CENTRE_X) < 16,
		'the player must remain inside the ladder volume (x=' .. tostring(x) .. ')')

	controller:release('left')
end)

test('a fresh direction press while hanging still slides along the ladder', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInputModule.FakeInput.new()
	local player = player1(game)

	-- Neutral drop into the volume -> hang.
	player.collider:setPosition(CENTRE_X, 240)
	local runUntil = FakeInputModule.runUntil
	runUntil(game, function()
		return player.fsm.currentState.name == 'LadderState'
	end, 120)

	-- Fresh press: deliberate lateral slide must still work.
	controller:press('right')
	runUntil(game, function()
		return Queries.playerPositionV(player).x > CENTRE_X + 4
	end, 60)
	controller:release('right')
end)

test('releasing the slide key holds position instead of re-centring', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInputModule.FakeInput.new()
	local player = player1(game)

	-- Neutral drop into the volume -> hang.
	player.collider:setPosition(CENTRE_X, 240)
	local runUntil = FakeInputModule.runUntil
	runUntil(game, function()
		return player.fsm.currentState.name == 'LadderState'
	end, 120)

	-- Slide right off-centre, then let go.
	controller:press('right')
	runUntil(game, function()
		return Queries.playerPositionV(player).x > CENTRE_X + 10
	end, 120)
	controller:release('right')
	local releasedX = Queries.playerPositionV(player).x

	-- Spec: auto-align only while up/down is held. Off-centre is a valid
	-- resting spot; the ladder must not drag the player back to centre-x.
	for _ = 1, FrameStepper.secondsToFrames(1) do
		FrameStepper.step(game, 1)
	end

	assertEqual('LadderState', player.fsm.currentState.name,
		'player must stay on the ladder after releasing the slide key')
	assertTrue(math.abs(Queries.playerPositionV(player).x - releasedX) <= 2,
		'expected position to hold after release (released at x=' .. tostring(releasedX)
			.. ', now x=' .. tostring(Queries.playerPositionV(player).x) .. ')')
end)

test('a side press while climbing (up held) is ignored, keeping the player on the ladder', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInputModule.FakeInput.new()
	local player = player1(game)
	local runUntil = FakeInputModule.runUntil

	-- Drop into the column -> hang.
	player.collider:setPosition(CENTRE_X, 240)
	runUntil(game, function()
		return player.fsm.currentState.name == 'LadderState'
	end, 120)

	-- Climb a little, then hold right while STILL holding up. Regression for
	-- the vertical-priority rule: while up/down is held the side keys must be
	-- ignored, so an accidental dual press can't slide the player off the
	-- column (the old last-pressed-wins model slipped too easily).
	controller:press('up')
	runUntil(game, function()
		return Queries.playerPositionV(player).y < 220
	end, FrameStepper.secondsToFrames(3))
	controller:press('right')
	local xAtPress = Queries.playerPositionV(player).x

	runUntil(game, function()
		return Queries.playerPositionV(player).y < 190
	end, FrameStepper.secondsToFrames(3))

	controller:release('up')
	controller:release('right')

	local x = Queries.playerPositionV(player).x
	assertEqual('LadderState', player.fsm.currentState.name,
		'player must stay mounted while both up and a side key are held')
	assertTrue(math.abs(x - xAtPress) <= 1,
		'side press must be ignored while up is held (x at press=' .. tostring(xAtPress)
			.. ', after climbing x=' .. tostring(x) .. ')')
end)

test('pressing up from an off-centre hang recentres before climbing', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInputModule.FakeInput.new()
	local player = player1(game)

	-- Neutral drop into the volume -> hang.
	player.collider:setPosition(CENTRE_X, 240)
	local runUntil = FakeInputModule.runUntil
	runUntil(game, function()
		return player.fsm.currentState.name == 'LadderState'
		end, 120)

	-- Slide right off-centre, release (position holds).
	controller:press('right')
	runUntil(game, function()
		return Queries.playerPositionV(player).x > CENTRE_X + 10
	end, 120)
	controller:release('right')

	-- Up must first bring the player back to the ladder centre-x, then climb.
	local startY = Queries.playerPositionV(player).y
	controller:press('up')
	runUntil(game, function()
		return Queries.playerPositionV(player).y < startY - 8
	end, FrameStepper.secondsToFrames(3))
	controller:release('up')

	local x = Queries.playerPositionV(player).x
	assertEqual('LadderState', player.fsm.currentState.name, 'expected to be climbing')
	assertTrue(math.abs(x - CENTRE_X) <= 2,
		'expected the climb to happen from the ladder centre (x=' .. tostring(x) .. ')')
end)
