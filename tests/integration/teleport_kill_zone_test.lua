-- Regression: a player travelling through TeleportTravelState must not be
-- killed by a kill zone the travel curve happens to pass over/through. The
-- collider is already a sensor during travel (teleport_travel_state.lua), but
-- the kill-zone check is a separate manual overlap query
-- (PlayerSensors.queryKillZone), not a physics collision, so being a sensor
-- alone doesn't protect the player.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local TeleportTrail = require("src.fx.teleport_trail")

local MAP = "tests/fixtures/kill_zone_room.tmj"

local function player1(game)
	return game.fsm.currentState.players[1]
end

test("a player travelling through a kill zone mid-teleport is not killed", function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 1) -- let the world finish initialising

	local player = player1(game)

	-- water1 kill zone spans x[0,320], y[160,224]; both endpoints (and the
	-- curve between them) sit well inside it.
	local start = { x = 100, y = 190 }
	local dest = { x = 200, y = 190 }
	local curve = TeleportTrail.generateCurve(start, dest)
	local duration = TeleportTrail.calculateTravelDuration(curve.dist)

	player.collider:setPosition(start.x, start.y)
	player.fsm:setState("TeleportTravelState", {
		curve = curve,
		duration = duration,
		destX = dest.x,
		destY = dest.y,
	})

	FrameStepper.step(game, FrameStepper.secondsToFrames(duration) - 2)

	assertFalse(player:isDead(), "expected the player not to die while mid-teleport through a kill zone")
end)
