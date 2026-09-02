-- Regression coverage confirming Pushable:update's existing ground-support
-- polling (src/components/pushable/pushable.lua:150-241) already handles a
-- prop resting on a destructible tile that gets destroyed out from under it
-- -- no production change expected, since the same fall/settle logic that
-- lets a prop drop off a ledge already re-evaluates support every frame.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Queries = require("tests.support.queries")

local MAP = "tests/fixtures/pushable_destructible_tile_fall_room.tmj"

-- see the fixture: the destructible tile's top edge is y=192, so a 32x32 box
-- resting on top of it settles with its centre 16px above that
local BOX_ON_TILE_Y = 176
-- the fixture's lower_floor starts at y=256, one tile below the destructible
-- tile's underside (224), so a box that falls through the gap settles here
local BOX_ON_FLOOR_Y = 240

test(
	"a push_box resting on a destructible tile falls and settles on the floor below once the tile is destroyed",
	function()
		local game = GameHarness.startGame(MAP)
		FrameStepper.step(game, 60)

		local box = Queries.findEntityByName(map, "push_box")
		local tile = Queries.findEntityByName(map, "tile_target")
		assertTrue(box ~= nil, "expected the fixture to load push_box")
		assertTrue(tile ~= nil, "expected the fixture to load tile_target")
		assertNear(
			BOX_ON_TILE_Y,
			box.collider:getY(),
			1,
			"fixture check: expected the box to be resting on the destructible tile before it is destroyed"
		)

		tile:queueDestroy()
		-- queueDestroy() is not instant (src/entity.lua) -- the map's own
		-- entity-list update pass is what actually removes the tile, mirroring
		-- laser_destructible_tile_test.lua's own step count.
		FrameStepper.step(game, 5)
		assertTrue(
			Queries.findEntityByName(map, "tile_target") == nil,
			"expected the destructible tile to have been removed from the map"
		)

		FrameStepper.step(game, 60)

		assertNear(
			BOX_ON_FLOOR_Y,
			box.collider:getY(),
			1,
			"expected the box to have fallen through the gap and landed on the floor below"
		)
		assertEqual("static", box.collider.bodyType, "expected the box to be back to a static body once it has landed")
	end
)
