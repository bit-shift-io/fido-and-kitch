-- Laser emitter core, driven through the real Game/Map/World/Player stack.
-- See tests/unit/laser_beam_resolver_test.lua for the pure hit-classification
-- coverage this file doesn't repeat; this file covers what only real
-- physics/entity wiring can answer -- does a floor-mounted laser's beam
-- actually reach and kill a falling player.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Queries = require("tests.support.queries")

local MAP = "tests/fixtures/laser_kill_room.tmj"

local function player1(game)
	return game.fsm.currentState.players[1]
end

test("a floor-mounted laser fires up and kills a player who falls through its beam", function()
	local game = GameHarness.startGame(MAP)

	local laser = Queries.findEntityByType(map, "laser")
	assertTrue(laser ~= nil, "expected the map to load a laser entity")
	assertEqual("up", laser.direction)

	-- Slice 04 added a power-up telegraph: the beam only kills once it has
	-- warmed up and holds at 'on' (src/entities/laser.lua's POWER_DURATION,
	-- 0.3s = 18 frames), not the instant it's enabled. 40 frames is
	-- comfortably past that (the player is in the beam's path from spawn,
	-- with no ground in this room) but well short of DeadState's own
	-- auto-respawn (~90 frames after death) -- the original 90-frame budget
	-- was tuned for an instant kill and would now observe the player already
	-- respawned by the time it asserts.
	FrameStepper.step(game, 40) -- fall from spawn down through the beam

	assertTrue(player1(game):isDead(), "expected the player to have died to the laser beam")
	assertEqual("laser", player1(game).deathType)
end)

test("a laser with no target stays on for the whole level -- disabling it saves the player", function()
	local game = GameHarness.startGame(MAP)

	local laser = Queries.findEntityByType(map, "laser")
	-- No target is wired to this laser in the fixture, so nothing would ever
	-- flip it off through gameplay -- this directly forces the same
	-- Switchable input a target switch would drive, to prove the beam
	-- actually stops doing anything (no kill) once switchEnabled is false.
	laser:getComponent(Switchable):switch({ state = "off" })

	FrameStepper.step(game, 90)

	assertFalse(player1(game):isDead(), "expected a disabled laser to not kill the player")
end)
