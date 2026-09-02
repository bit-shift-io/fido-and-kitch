-- A bird NPC ignores terrain collision entirely -- it is a permanent sensor
-- against the physics world, gravity handled manually (see npc_bird.lua).
-- Previously the bird toggled solid/sensor based on ladder overlap (solid
-- everywhere except directly over a ladder), which could freeze a directed
-- flight (FlyToTargetState/FlyToDoorState) mid-arc if its swoop curve
-- clipped ordinary terrain. Birds now behave like the pre-flight-feature
-- NPC glossary definition: they fly freely and ignore all collision.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')

local MAP = 'tests/fixtures/cage_room.tmj'

local function player1(game)
	return game.fsm.currentState.players[1]
end

test('a bird ignores terrain collision -- its collider stays a sensor even away from any ladder, and it is not pushed out of solid terrain it overlaps', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60)

	local cage = Queries.findEntityByType(map, 'cage')
	assertTrue(cage ~= nil, 'fixture check: cage should exist')

	cage:use(player1(game))
	local bird = cage.actor
	assertTrue(bird ~= nil, 'cage should spawn a bird')

	FrameStepper.step(game, 5)
	assertTrue(bird.collider.sensor, 'bird collider should be a sensor away from any ladder')

	-- The fixture's `floor` collision rect spans y=160..192. Drop the bird
	-- squarely inside it -- a solid dynamic collider would get pushed back
	-- out on the very next physics step.
	bird.collider:setPosition(160, 176)
	bird.collider:setLinearVelocity(0, 0)

	FrameStepper.step(game, 3)

	assertTrue(bird.collider.sensor, 'bird collider should remain a sensor while overlapping solid terrain')
	local y = bird.collider:getY()
	assertTrue(math.abs(y - 176) < 2,
		'bird should stay where placed inside solid terrain, not get pushed out; got y=' .. tostring(y))
end)
