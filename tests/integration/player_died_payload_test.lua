-- Falls P1 into the water kill zone and asserts player_died carries a table
-- payload. `>= 1` rather than a fixed count: the player falls repeatedly and
-- the spawn flash guards further deaths, but the exact count is not the
-- contract -- the payload shape is. Steps 150 frames: the kill zone hits
-- around frame 32, and resolveDeath fires only after the 1.2s death blink
-- (~72 more frames), so 90 would resolve too early.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")

local MAP = "tests/fixtures/kill_zone_room.tmj"

test("player_died carries a table payload with player and deathType", function()
	local game = GameHarness.startGame(MAP)

	local payloads = {}
	local disconnect = nil
	local function subscribe()
		local EventBus = require("src.utils.event_bus")
		disconnect = EventBus.on("player_died", function(data)
			table.insert(payloads, data)
		end)
	end
	subscribe()

	FrameStepper.step(game, 150)

	disconnect()

	assertTrue(#payloads >= 1, "expected at least one player death in 90 frames")
	local data = payloads[1]
	assertTrue(type(data) == "table", "player_died payload should be a table")
	assertTrue(data.player ~= nil, "payload should carry the player")
	assertTrue(data.deathType ~= nil, "payload should carry the deathType")
	assertEqual("water", data.deathType, "payload should carry the kill zone deathType")
end)
