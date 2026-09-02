-- Switchable teleport on/off, driven through the real Game/Map/World stack.
-- The fixture links switch1 to teleport_a; using the switch must gate the
-- teleporter's Usable.enabled the same way Usable:canUse reads it. Switch:use
-- is the public entry point a player reaches by walking up and pressing use
-- (covered generically elsewhere) -- this file calls it directly so the
-- switchable assertions aren't coupled to that walk-and-press choreography.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Queries = require("tests.support.queries")

local MAP = "tests/fixtures/switchable_teleport_room.tmj"

local function player1(game)
	return game.fsm.currentState.players[1]
end

test("a switchable teleporter starts enabled", function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60) -- settle

	local teleport = Queries.findEntityByName(map, "teleport_a")
	assertTrue(teleport.usable.enabled, "expected the teleporter to start enabled (switchable defaults on)")
end)

test("using the switch disables the linked teleporter", function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60) -- settle

	local switch = Queries.findEntityByName(map, "switch1")
	local teleport = Queries.findEntityByName(map, "teleport_a")

	-- the lever starts off; the first pull turns it on, the second turns it
	-- off -- and only an off switch gates the switchable off
	switch:use(player1(game))
	assertEqual("on", switch.state)
	switch:use(player1(game))
	assertEqual("off", switch.state)
	assertFalse(teleport.usable.enabled, "expected the teleporter to be disabled once the switch is off")
end)

test("using the switch again re-enables the linked teleporter", function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60) -- settle

	local switch = Queries.findEntityByName(map, "switch1")
	local teleport = Queries.findEntityByName(map, "teleport_a")

	-- toggle the lever to off first
	switch:use(player1(game))
	switch:use(player1(game))
	assertFalse(teleport.usable.enabled, "fixture check: expected the teleporter to be off before this test")

	switch:use(player1(game))
	assertEqual("on", switch.state)
	assertTrue(teleport.usable.enabled, "expected the teleporter to be enabled again once the switch is back on")
end)
