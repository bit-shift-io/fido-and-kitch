-- A mirror/laser_switch's collider is solid to the laser BEAM's raycast
-- classification (laser_beam_resolver.lua reads .sensor only, never
-- World.colFilter/nonSolidEntityTypes) but must never be a physical
-- obstacle to a player -- both are small mounted fixtures, not walls, so a
-- falling player must pass straight through/onto them rather than getting
-- caught standing on top, same as src/entities/npc_rabbit.lua already
-- passes through players via the same World.ignoresEntity mechanism.
-- See tests/unit/mirror_test.lua / tests/unit/laser_switch_test.lua for the
-- pure nonSolidEntityTypes assertion on each entity's own collider; this
-- file proves it holds through the real physics stack.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Queries = require("tests.support.queries")

local MAP = "tests/fixtures/mirror_no_block_room.tmj"
local MAP_HEIGHT_PX = 320 -- 10 tiles * 32px, see the fixture's own dimensions

local function player1(game)
	return game.fsm.currentState.players[1]
end

test("a falling player passes straight through a mirror and a laser_switch instead of resting on either", function()
	local game = GameHarness.startGame(MAP)
	local mirror = Queries.findEntityByName(map, "mirror_in_fall_path")
	local laserSwitch = Queries.findEntityByName(map, "laser_switch_in_fall_path")
	assertTrue(mirror ~= nil, "expected the fixture to load mirror_in_fall_path")
	assertTrue(laserSwitch ~= nil, "expected the fixture to load laser_switch_in_fall_path")

	FrameStepper.step(game, 150) -- comfortably enough to fall the map's full height

	local player = player1(game)
	local playerBottom = player.collider:getBounds().bottom

	assertTrue(
		playerBottom > mirror.collider:getBounds().bottom + 40,
		"expected the player to have fallen well past the mirror, not rested on it"
	)
	assertTrue(
		playerBottom > laserSwitch.collider:getBounds().bottom + 40,
		"expected the player to have fallen well past the laser_switch, not rested on it"
	)
	assertTrue(
		playerBottom >= MAP_HEIGHT_PX - 5,
		"expected the player to have landed on the map's bottom boundary, having passed through both fixtures"
	)
end)
