-- Debug test for switch-drawbridge linkage
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')

local MAP = 'tests/fixtures/drawbridge_switch_room.tmj'

test('debug switch-drawbridge linkage', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 10)

	local bridge = Queries.findEntityByType(map, 'drawbridge')
	local switch = Queries.findEntityByType(map, 'switch')

	print("Bridge:", bridge)
	print("Switch:", switch)
	print("Bridge state:", bridge.state)
	print("Switch state:", switch.state)
	print("Switch target:", switch.target)
	if switch.target then
		print("Switch target.entity:", switch.target.entity)
		if switch.target.entity then
			print("Switch target.entity.type:", switch.target.entity.type)
			local switchable = switch.target.entity.getComponent and switch.target.entity:getComponent('switchable')
			print("Switchable component:", switchable)
		end
	end

	-- Try using the switch
	print("\n--- Using switch (turn on) ---")
	switch:use(nil)
	print("Switch state after use:", switch.state)
	print("Bridge state after switch use:", bridge.state)

	FrameStepper.step(game, 1)
	print("Bridge state after 1 frame:", bridge.state)

	FrameStepper.step(game, 10)
	print("Bridge state after 10 frames:", bridge.state)
end)