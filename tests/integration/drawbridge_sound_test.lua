-- Drawbridge open/close sounds. See tests/integration/drawbridge_test.lua for
-- the spatial/eligibility coverage this file doesn't repeat.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')
local SoundSpy = require('tests.support.sound_spy')

local MAP = 'tests/fixtures/drawbridge_room.tmj'

test('the drawbridge plays an open sound when it starts lowering', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 10)

	local bridge = Queries.findEntityByType(map, 'drawbridge')
	local spy = SoundSpy.install()

	local enemy = Collider{
		shape_type = 'rectangle',
		shape_arguments = {20, 30},
		body_type = 'dynamic',
		position = {x = 80, y = 113},
	}
	enemy.entity = {type = 'enemy'}
	enemy:setGroupIndex(100)

	local opened = false
	for _ = 1, 120 do
		local _, vy = enemy:getLinearVelocity()
		enemy:setLinearVelocity(97, vy)
		FrameStepper.step(game, 1)
		if Queries.drawbridgeState(bridge) == 'opening' then
			opened = true
			break
		end
	end

	spy.uninstall()
	assertTrue(opened, 'fixture check: expected the bridge to start opening')
	assertEqual('open', spy.played[1])
end)

test('the drawbridge plays a close sound when it starts raising', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 10)

	local bridge = Queries.findEntityByType(map, 'drawbridge')
	bridge:setState('open')

	local spy = SoundSpy.install()
	bridge:checkHeld() -- nothing holds it -- expect an immediate transition to closing
	assertEqual('closing', Queries.drawbridgeState(bridge), 'fixture check: expected the bridge to start closing')

	spy.uninstall()
	assertEqual('close', spy.played[1])
end)
