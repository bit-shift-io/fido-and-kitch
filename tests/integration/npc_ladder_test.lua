-- NPC verify-only coverage for the remodeled ladders (NOTES.md 2026-08-24,
-- decision 6): the no-gravity auto-catch lives in the player-only
-- FallState/LadderState FSM, so NPCs must fall THROUGH the ladder volume
-- uncaught and land on whatever terrain is below. No src/npc changes are
-- expected here -- if this test fails the remodel leaked into NPC code.
-- Uses the top room: its perched player hugs the slab, leaving the column
-- interior below empty, so the drop path crosses no other body.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')

local MAP = 'tests/fixtures/ladder_top_room.tmj'

-- Drop point centred in the ladder column (x=128..160), just under the
-- perched player's feet (y=192) and well above the floor at y=352. Set via
-- collider:setPosition (centre semantics) after spawn so NPC mock-object
-- anchoring doesn't matter.
local DROP_X = 144
local DROP_Y = 320

local function objectLayer(mapInstance)
	for _, layer in ipairs(mapInstance.layers) do
		if layer.type == 'objectgroup' then
			return layer
		end
	end
	return nil
end

test('an npc dropped through a ladder volume is not caught and lands on the terrain', function()
	local game = GameHarness.startGame(MAP)
	local mapInstance = map

	local mock = {
		type = 'npc_rabbit',
		name = 'npc_drop',
		x = DROP_X - 16,
		y = DROP_Y - 16,
		width = 32,
		height = 32,
		properties = {},
	}
	local rabbit = mapInstance:loadEntity('npc_rabbit', objectLayer(mapInstance), mock)
	assertTrue(rabbit ~= nil, 'fixture sanity: rabbit spawned')
	rabbit.collider:setPosition(DROP_X, DROP_Y)

	local landed = false
	for _ = 1, FrameStepper.secondsToFrames(3) do
		FrameStepper.step(game, 1)
		local b = rabbit.collider:getBounds()
		if math.abs(b.bottom - 352) <= 3 then
			landed = true
			break
		end
	end

	assertTrue(landed, 'expected the rabbit to fall through the volume onto the floor')
	local b = rabbit.collider:getBounds()
	assertTrue(b.left >= 100 and b.right <= 190,
		'expected the rabbit to stay in the column band while landing')
end)
