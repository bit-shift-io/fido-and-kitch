-- Cage target property tests:
-- - Bird cage with target: spawned actor receives switchTarget
-- - Rabbit cage with target: error logged, still spawns and follows
-- - Cage without target: unaffected (regression)
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Queries = require("tests.support.queries")
local LogSpy = require("tests.support.log_spy")

local MAP = "tests/fixtures/bird_target_room.tmj"

local function player1(game)
	return game.fsm.currentState.players[1]
end

local function settle(game)
	FrameStepper.step(game, 60)
end

test("bird cage with target sets switchTarget on spawned actor after use", function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local cage = Queries.findEntityByName(map, "bird_cage_with_target")
	assertTrue(cage ~= nil, "fixture check: bird cage with target should exist")

	-- Verify initial state: no actor spawned yet
	assertTrue(cage.actor == nil, "cage should not have spawned actor yet")

	-- Use the cage to spawn the bird
	cage:use(player1(game))

	-- After use, actor should be spawned and have switchTarget set
	assertTrue(cage.actor ~= nil, "bird cage should spawn actor on use")
	assertTrue(cage.actor.switchTarget ~= nil, "spawned bird should have switchTarget set")
	assertEqual("switch", cage.actor.switchTarget.type, "switchTarget should be the switch entity")
end)

test("rabbit cage with target logs error at map load and still spawns", function()
	local spy = LogSpy.install()

	local game = GameHarness.startGame(MAP)
	settle(game)

	spy.uninstall()

	-- Verify error was logged
	assertTrue(#spy.errors > 0, "error should have been logged for rabbit cage with target")
	local errorFound = false
	for _, err in ipairs(spy.errors) do
		if string.find(err, "rabbit") and string.find(err, "target") then
			errorFound = true
			break
		end
	end
	assertTrue(errorFound, "error should mention rabbit and target")

	-- Verify rabbit spawns and follows normally (no switchTarget)
	local rabbitCage = Queries.findEntityByName(map, "rabbit_cage_with_target")
	assertTrue(rabbitCage ~= nil, "fixture check: rabbit cage with target should exist")

	rabbitCage:use(player1(game))

	assertTrue(rabbitCage.actor ~= nil, "rabbit cage should still spawn actor")
	assertTrue(rabbitCage.actor.switchTarget == nil, "spawned rabbit should NOT have switchTarget set")
	assertTrue(rabbitCage.actor.setTarget ~= nil, "rabbit should still have setTarget method for following player")
end)

test("cage without target is unaffected (regression)", function()
	local game = GameHarness.startGame("tests/fixtures/cage_room.tmj")
	settle(game)

	local cage = Queries.findEntityByType(map, "cage")
	assertTrue(cage ~= nil, "fixture check: cage should exist")

	cage:use(player1(game))

	-- Verify normal spawn without switchTarget
	assertTrue(cage.actor ~= nil, "cage should spawn actor on use")
	assertTrue(cage.actor.switchTarget == nil, "spawned bird should not have switchTarget when none configured")
	assertTrue(cage.actor.setTarget ~= nil, "spawned actor should still have setTarget for following player")
end)
