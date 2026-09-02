-- Phase 3 end-to-end check: every dial cranked at once (max size, max
-- difficulty, coop required) must still load cleanly and be completable via
-- cages alone, proving the mechanics from every issue compose without
-- conflict rather than just working in isolation.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Main = require("tools.level_generator.main")

local GENERATED_PATH = "res/map/generated/_test_end_to_end.tmj"

local function writeGeneratedFixture(seed)
	local result = Main.generate({ seed = seed, count = 1, size = "large", difficulty = 5, coop = "required" })[1]
	local file = io.open(GENERATED_PATH, "w")
	file:write(result.tmj)
	file:close()
	return result
end

local function removeGeneratedFixture()
	os.remove(GENERATED_PATH)
end

test(
	"every mechanic together (large, difficulty 5, coop required) still loads and is completable via cages alone",
	function()
		writeGeneratedFixture(2024)
		local ok, err = pcall(function()
			local game = GameHarness.startGame(GENERATED_PATH)
			FrameStepper.step(game, 90)

			for _, player in ipairs(game.fsm.currentState.players) do
				assertFalse(player:isDead(), "a player died just from spawning/settling")
			end

			local player1 = game.fsm.currentState.players[1]
			for _, cage in ipairs(map:getEntitiesByType("cage")) do
				cage:use(player1)
			end

			local exitDoors = map:getEntitiesByType("exit_door")
			assertEqual(1, #exitDoors)
			assertTrue(
				exitDoors[1].usable.enabled,
				"expected the exit to open once every cage is used, with every other mechanic present"
			)
		end)
		removeGeneratedFixture()

		if not ok then
			error(err)
		end
	end
)
