-- Seam-mount intent tests: standing on one ladder's top slab while a 1px
-- sliver of an adjacent UP-leading column also overlaps the body. Pressing
-- down must descend the DOWN-leading ladder underfoot (intent-carrying
-- mount), never drag onto the up-leading column just because it is the only
-- directly-overlapped volume. Also pins the arrival rule: touching down on
-- real ground at the base dismounts.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Queries = require('tests.support.queries')

local SEAM_MAP = 'tests/fixtures/ladder_seam_room.tmj'
local CATCH_MAP = 'tests/fixtures/ladder_fall_catch_room.tmj'

local function player1(game)
	return game.fsm.currentState.players[1]
end

test('pressing down on a seam perch descends the down-leading ladder', function()
	local game = GameHarness.startGame(SEAM_MAP)
	local controller = FakeInputModule.FakeInput.new()
	local player = player1(game)

	-- Perch on column B's top slab (feet at y=384) with a 1px sliver of
	-- column A's volume overlapping the body's left edge.
	-- Centre (36,369): feet 384 rest on B's top slab [384..392], while the
	-- body [26..46] and its ±4px-inset ladder probe overlap column A
	-- ([0..32]) — the direct-overlap that used to lock alignment onto the
	-- wrong (up-leading) ladder.
	player.collider:setPosition(36, 369)

	-- Intent: descend B (centre-x 48). The old code saw only A overlapped,
	-- dragged to A's centre (16) and ejected.
	controller:press('down')
	local runUntil = FakeInputModule.runUntil
	runUntil(game, function()
		local pos = Queries.playerPositionV(player)
		return pos.y > 400
	end, FrameStepper.secondsToFrames(2))
	controller:release('down')

	assertEqual('LadderState', player.fsm.currentState.name,
		'expected to be descending inside the down-leading ladder')
	local pos = Queries.playerPositionV(player)
	assertTrue(pos.x >= 33 and pos.x <= 63,
		'expected to end up centred in column B (x=' .. tostring(pos.x) .. ')')
end)

test('reaching the bottom of a ladder dismounts onto the platform', function()
	local game = GameHarness.startGame(CATCH_MAP)
	local controller = FakeInputModule.FakeInput.new()
	local player = player1(game)
	local SoundSpy = require('tests.support.sound_spy')

	-- Hang near the bottom of the catch-room column (volume ends at the
	-- floor top y=352).
	player.collider:setPosition(144, 330)
	local runUntil = FakeInputModule.runUntil
	runUntil(game, function()
		return player.fsm.currentState.name == 'LadderState'
	end, 120)

	-- Descend all the way: touching down on the platform is the arrival
	-- point and must eject the player into normal walking -- with no
	-- residual drop, no FallState frame, and no landing thud.
	local spy = SoundSpy.install()
	local sawFall = false
	controller:press('down')
	runUntil(game, function()
		if player.fsm.currentState.name == 'FallState' then
			sawFall = true
		end
		return player.fsm.currentState.name == 'WalkIdleState'
	end, FrameStepper.secondsToFrames(2))
	controller:release('down')
	spy.uninstall()

	assertEqual('WalkIdleState', player.fsm.currentState.name,
		'standing on the platform at the base must end the mount')
	assertFalse(sawFall, 'arrival at the base must not pass through a fall')
	for _, name in ipairs(spy.played) do
		assertFalse(name == 'land', 'arrival must not play the landing sound')
	end
	local bottom = player.collider:getBounds().bottom
	assertTrue(math.abs(bottom - 352) <= 1,
		'expected to be standing exactly on the floor (bottom=' .. tostring(bottom) .. ')')
end)

test('releasing keys while hanging beside a platform crossing stays mounted', function()
	-- sandbox column A has a solid platform crossing the column below its
	-- top: a hanging climber passes through it (kinematic), so 'solid just
	-- below the feet' there is NOT an arrival. Only a descending player
	-- (down held) may be ejected by ground contact.
	local game = GameHarness.startGame('res/map/sandbox.tmj')
	local controller = FakeInputModule.FakeInput.new()
	local player = player1(game)
	local runUntil = FakeInputModule.runUntil

	player.collider:setPosition(144, 340)
	runUntil(game, function()
		return player.fsm.currentState.name == 'LadderState'
	end, 120)

	-- Climb to just below the slab band [192..200], then let go of
	-- everything -- the reported pop-off moment.
	controller:press('up')
	runUntil(game, function()
		return player.collider:getBounds().bottom <= 210
	end, FrameStepper.secondsToFrames(2))
	controller:release('up')

	for _ = 1, FrameStepper.secondsToFrames(1) do
		FrameStepper.step(game, 1)
	end

	assertEqual('LadderState', player.fsm.currentState.name,
		'releasing keys mid-column must not dismount the climber')
	local bottom = player.collider:getBounds().bottom
	assertTrue(bottom > 195,
		'expected to stay hanging below the top, not perch on the slab (bottom=' .. tostring(bottom) .. ')')
end)
