-- The renderOrder feature under real LÖVE, with real rendering -- visual
-- evidence for the two acceptance criteria the headless tiers can only
-- prove via draw-order spies:
--   * a pushable resting on a teleporter renders in front of its art,
--     not tucked behind it
--   * a layered_prop's two Sprites straddle a nearby entity
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Queries = require("tests.support.queries")
local Capture = require("tests.support.capture")

local MAP = "tests/fixtures/teleport_clear_room.tmj"

test("a push_box resting on a teleporter renders in front of it -- rendered", function()
	local game = GameHarness.startGame(MAP, { real = true })
	FrameStepper.step(game, 5)

	local teleportA = Queries.findEntityByName(map, "teleport_a")

	Capture.capture("01_before_overlap")

	-- Spawn a fresh box centred on the teleporter's own position -- the
	-- teleporter's art (64x64) is larger than the box's (32x32), so its
	-- edges stay visible around the box even with the box drawn on top,
	-- giving clear visual proof the box is in front rather than simply
	-- occluding the whole teleporter. Spawned fresh rather than
	-- repositioning an existing settled box: a resting pushable's Pushable
	-- component parks its Collider static, and Collider:update still syncs
	-- the Sprite's screen position every frame regardless of body type, so
	-- either approach works -- fresh keeps this test independent of that.
	local layer = map.map.layers["game"]
	local object = {
		x = teleportA.collider:getX() - 16,
		y = teleportA.collider:getY() - 16,
		width = 32,
		height = 32,
		properties = {},
	}
	local box = map:loadEntity("push_box", layer, object)
	FrameStepper.step(game, 5)

	Capture.capture("02_box_in_front_of_teleporter")

	assertTrue(
		box.sprite.renderOrder > teleportA.sprite.renderOrder,
		"push_box must have a higher renderOrder than the teleporter it now overlaps"
	)
end)

test("a layered_prop straddling a nearby entity shows one layer behind and one in front -- rendered", function()
	local game = GameHarness.startGame(MAP, { real = true })
	FrameStepper.step(game, 5)

	local teleportA = Queries.findEntityByName(map, "teleport_a")
	local layer = map.map.layers["game"]
	local object = {
		x = teleportA.collider:getX() - 16,
		y = teleportA.collider:getY() - 16,
		width = 32,
		height = 32,
		properties = {},
	}
	local prop = map:loadEntity("layered_prop", layer, object)
	FrameStepper.step(game, 5)

	Capture.capture("03_layered_prop_straddling_teleport")

	assertTrue(prop:hasSplitRenderOrder(), "layered_prop must split into two draw units for this to be a real test")
end)
