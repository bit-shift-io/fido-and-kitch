-- Flanked-column slide rule: while a climber's feet are beside flanking
-- walls (below their tops), side presses must be ignored -- the walls block
-- the way, and sliding into them used to pop the player up onto the wall
-- top. Only once the feet are above the wall tops does a fresh side press
-- carry them across (the intended top exit).
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Queries = require('tests.support.queries')

local MAP = 'tests/fixtures/ladder_flank_room.lua'
local MAP2 = 'tests/fixtures/ladder_side_entry.lua'
local CENTRE_X = 144

local function player1(game)
	return game.fsm.currentState.players[1]
end

local function runUntil(game, predicate, frames)
	local ok = FakeInputModule.runUntil(game, predicate, frames)
	assertTrue(ok ~= false, 'choreography timed out waiting for expected state')
end

test('side presses are blocked while the climber is beside flanking walls', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInputModule.FakeInput.new()
	local player = player1(game)

	-- Hang beside the wall band: centre (144,230) puts the feet at ~245,
	-- well below the wall tops at y=240.
	player.collider:setPosition(CENTRE_X, 230)
	runUntil(game, function()
		return player.fsm.currentState.name == 'LadderState'
	end, 120)

	controller:press('right')
	for _ = 1, FrameStepper.secondsToFrames(0.75) do
		FrameStepper.step(game, 1)
	end

	assertEqual('LadderState', player.fsm.currentState.name,
		'a walled-in slide must not eject or teleport the player')
	local x = Queries.playerPositionV(player).x
	assertTrue(math.abs(x - CENTRE_X) <= 2,
		'expected the wall to hold the player in place (x=' .. tostring(x) .. ')')

	controller:release('right')
end)

test('above the wall tops a side press crosses over and lands', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInputModule.FakeInput.new()
	local player = player1(game)

	-- Drop onto the slab perch: feet settle at the volume top (~192), well
	-- above the wall tops at 240.
	player.collider:setPosition(CENTRE_X, 172)
	runUntil(game, function()
		return player.fsm.currentState.name == 'WalkIdleState'
			and math.abs(player.collider:getBounds().bottom - 192) <= 4
	end, 120)

	controller:press('right')
	runUntil(game, function()
		return player.fsm.currentState.name == 'WalkIdleState'
			and Queries.playerPositionV(player).x > 160
			and math.abs(player.collider:getBounds().bottom - 240) <= 6
	end, FrameStepper.secondsToFrames(3))
	controller:release('right')

	local pos = Queries.playerPositionV(player)
	assertTrue(pos.x > 160, 'expected to cross clear of the slab (x=' .. tostring(pos.x) .. ')')
	local bottom = player.collider:getBounds().bottom
	assertTrue(math.abs(bottom - 240) <= 6,
		'expected to land standing on the right wall top (feet=' .. tostring(bottom) .. ')')
end)

test('a sub-top side press finishes the climb to the top then crosses over', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInputModule.FakeInput.new()
	local player = player1(game)

	-- Hang at feet ~205: ABOVE the wall tops (240) so the walls cannot block
	-- the slide probe, but BELOW the volume top (192... y-down: still under
	-- the slab plane). A side press here used to slide the body out of the
	-- column and eject to FallState, landing on the wall top -- a "hop to
	-- the top" without ever climbing there. Now the held key first carries
	-- the climber up to the top hover, then continues across.
	player.collider:setPosition(CENTRE_X, 190)
	runUntil(game, function()
		return player.fsm.currentState.name == 'LadderState'
	end, 120)

	controller:press('right')
	runUntil(game, function()
		return player.fsm.currentState.name == 'WalkIdleState'
			and Queries.playerPositionV(player).x > 160
			and math.abs(player.collider:getBounds().bottom - 240) <= 6
	end, FrameStepper.secondsToFrames(3))
	controller:release('right')

	local bottom = player.collider:getBounds().bottom
	assertTrue(bottom < 300,
		'expected the climber to land on the right wall top (feet=' .. tostring(bottom) .. ')')
end)

test('a deep side press slides off the side and falls', function()
	local game = GameHarness.startGame(MAP2)
	local controller = FakeInputModule.FakeInput.new()
	local player = player1(game)

	-- Hang DEEP in the column: centre (144,300) puts the feet at ~315, more
	-- than half a tile below the column top (288). No platform is likely to
	-- be adjacent up there, so a side press here is a normal dismount: slide
	-- off the side and fall -- never rise toward the top.
	player.collider:setPosition(CENTRE_X, 300)
	runUntil(game, function()
		return player.fsm.currentState.name == 'LadderState'
	end, 120)

	controller:press('right')
	local startFeet = player.collider:getBounds().bottom
	local minFeet = math.huge
	runUntil(game, function()
		minFeet = math.min(minFeet, player.collider:getBounds().bottom)
		return player.fsm.currentState.name == 'WalkIdleState'
			and Queries.playerPositionV(player).x > 164
	end, FrameStepper.secondsToFrames(3))
	controller:release('right')

	assertTrue(minFeet >= startFeet - 2,
		'a deep side press must slide off the side, not climb (minFeet='
		.. tostring(minFeet) .. ', startFeet=' .. tostring(startFeet) .. ')')
	local bottom = player.collider:getBounds().bottom
	assertTrue(math.abs(bottom - 416) <= 6,
		'expected the dismount to fall through to the floor (feet=' .. tostring(bottom) .. ')')
end)
