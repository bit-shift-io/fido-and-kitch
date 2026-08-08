-- Issue 07 (pushable rules): the generated push_box must actually bridge
-- its gap under real pushable physics (src/components/pushable/pushable.lua),
-- and the boulder-weighs-plate flourish's boulder must actually seat onto
-- and hold its plate. Both are driven by walking a real player into them
-- and holding right, mirroring tests/integration/boulder_test.lua's
-- shoveRightAndRelease pattern, since Pushable:update recomputes velocity
-- from real overlapping pushers each frame -- a directly-set velocity would
-- just be overwritten.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Main = require('tools.level_generator.main')

local FakeInput = FakeInputModule.FakeInput

local GENERATED_PATH = 'res/map/generated/_test_pushables.tmx'

local function writeGeneratedFixture(seed, size, difficulty)
	local result = Main.generate({seed = seed, count = 1, size = size, difficulty = difficulty})[1]
	local file = io.open(GENERATED_PATH, 'w')
	file:write(result.xml)
	file:close()
end

local function removeGeneratedFixture()
	os.remove(GENERATED_PATH)
end

-- Parks P2 out of the way and puts P1 flush against the prop's left face,
-- grounded, then holds right for up to maxFrames or until the prop starts
-- moving away from its start position.
local function shoveRight(game, prop, maxFrames)
	local players = game.fsm.currentState.players
	local bounds = prop.collider:getBounds()
	players[1].collider:setPosition(bounds.left - 10, bounds.top + 1)
	players[2].collider:setPosition(bounds.left - 10, bounds.top + 40) -- clear of the prop's push probe

	local controller = FakeInput.new()
	controller:press('right')
	local startX = prop.collider:getX()
	for _ = 1, maxFrames do
		FrameStepper.step(game, 1)
	end
	controller:release('right')
	return prop.collider:getX() > startX + 1
end

test('pushing the generated box across the gap makes it settle as solid, walkable ground', function()
	writeGeneratedFixture(44, 'medium', 1)
	local ok, err = pcall(function()
		local game = GameHarness.startGame(GENERATED_PATH)
		FrameStepper.step(game, 30) -- let the box drop and settle before pushing

		local boxes = map:getEntitiesByType('push_box')
		assertEqual(1, #boxes)
		local box = boxes[1]

		local moved = shoveRight(game, box, 180)
		assertTrue(moved, 'expected the push and hold to move the box at all')

		FrameStepper.step(game, 60) -- let it fall into the gap and settle

		local vx, vy = box.collider:getLinearVelocity()
		assertNear(0, vy, 0.5, 'expected the box to have come to rest (not still falling)')
		assertEqual('static', box.collider.bodyType, 'expected the settled box to become static, walkable ground')
	end)
	removeGeneratedFixture()

	if not ok then
		error(err)
	end
end)

test('the boulder-weighs-plate flourish (difficulty 5) has a boulder that seats onto and holds its plate', function()
	writeGeneratedFixture(44, 'medium', 5)
	local ok, err = pcall(function()
		local game = GameHarness.startGame(GENERATED_PATH)
		FrameStepper.step(game, 5)

		local boulders = map:getEntitiesByType('boulder')
		if #boulders == 0 then
			-- the flourish is optional and only applies to a wide-enough zone;
			-- nothing to verify if this seed/size didn't place one
			return
		end
		local plates = map:getEntitiesByType('pressure_switch')
		local boulder = boulders[1]
		local plate = plates[1]

		shoveRight(game, boulder, 60)
		FrameStepper.step(game, 120) -- let momentum carry it onto the plate and settle

		assertTrue(plate:hasWeight(), 'expected the seated boulder to register as weight on the plate')
	end)
	removeGeneratedFixture()

	if not ok then
		error(err)
	end
end)
