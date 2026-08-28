-- The pushable props under real LÖVE, with real rendering. The headless tiers
-- already cover the mechanics thoroughly (tests/integration/pushable_test.lua,
-- boulder_test.lua, pressure_switch_test.lua); what only this tier can answer:
--
--   * the props' real art actually loads and draws (the integration tier's
--     love.* mock returns a fake image from love.graphics.newImage and never
--     draws anything, so a wrong path or a bad quad is invisible there)
--   * the pressure switch's own draw() runs against real love.graphics
--   * the fill-a-hole-and-cross sequence holds up under real physics at real
--     frame timing -- the class of thing the drawbridge scenarios found, and
--     the reason the flush-contact gotcha in tests/README.md exists
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Queries = require('tests.support.queries')
local Capture = require('tests.support.capture')

local FakeInput = FakeInputModule.FakeInput

local MAX_FRAMES = 900

test('a box is pushed into a hole, fills it, and the player walks across -- rendered', function()
	local game = GameHarness.startGame('tests/fixtures/pushable_room.tmj', {real = true})
	local controller = FakeInput.new()

	FrameStepper.step(game, 60) -- land and settle

	local player = game.fsm.currentState.players[1]
	local box = Queries.findEntityByName(map, 'push_box')

	Capture.capture('01_start')

	local filled, crossed = false, false
	controller:press('right')

	for _ = 1, MAX_FRAMES do
		FrameStepper.step(game, 1)
		assertFalse(Queries.playerIsDead(player), 'the player must never fall into the hole they just filled')

		if not filled and math.abs(box.collider:getX() - 304) < 0.5 and box.collider:getY() > 230 then
			filled = true
			Capture.capture('02_hole_filled')
		end

		if filled and Queries.playerPositionV(player).x > 340 then
			crossed = true
			break
		end
	end

	controller:release('right')
	Capture.capture('03_crossed')

	assertTrue(filled, 'expected the box to be shoved into the hole and fill it')
	assertTrue(crossed, 'expected the player to walk across the filled hole onto the far ground')
	assertFalse(Queries.playerIsDead(player), 'the player must be alive on the far side')
end)

test('a boulder is shoved and rolls on under its own momentum -- rendered', function()
	local game = GameHarness.startGame('tests/fixtures/boulder_room.tmj', {real = true})
	local controller = FakeInput.new()

	FrameStepper.step(game, 60)

	local boulder = Queries.findEntityByName(map, 'boulder')
	-- park P2 clear so it is not what stops the roll
	game.fsm.currentState.players[2].collider:setPosition(64, 209)

	local startX = boulder.collider:getX()
	Capture.capture('04_boulder_start')

	controller:press('right')
	local moving = false
	for _ = 1, MAX_FRAMES do
		FrameStepper.step(game, 1)
		if boulder.collider:getX() > startX + 0.5 then
			moving = true
			break
		end
	end
	controller:release('right')
	assertTrue(moving, 'expected the shove to set the boulder rolling')

	local releasedAt = boulder.collider:getX()
	FrameStepper.step(game, 30)
	Capture.capture('05_boulder_rolling')

	assertTrue(boulder.collider:getX() > releasedAt + 20,
		'expected the boulder to keep rolling after the player let go')
end)

test('a pressure plate renders its active state and a box seats onto it -- rendered', function()
	local game = GameHarness.startGame('tests/fixtures/pressure_switch_room.tmj', {real = true})

	FrameStepper.step(game, 60)

	local plate = Queries.findEntityByName(map, 'plate')
	local box = Queries.findEntityByName(map, 'push_box')
	local ladder = Queries.findEntityByName(map, 'target_ladder')
	local heightBefore = ladder:tileHeight()

	assertFalse(Queries.pressureSwitchIsActive(plate), 'expected the plate to start off')
	Capture.capture('06_plate_inactive')

	-- drop the box just off-centre on the plate and let it seat itself
	box.collider:setPosition(299, 208)
	FrameStepper.step(game, 20)

	Capture.capture('07_plate_active')

	assertNear(304, box.collider:getX(), 0.5, 'expected the box to seat on the plate tile centre')
	assertTrue(Queries.pressureSwitchIsActive(plate), 'expected the seated box to activate the plate')
	assertEqual(heightBefore + 2, ladder:tileHeight(), 'expected the plate to have driven its target')
end)
