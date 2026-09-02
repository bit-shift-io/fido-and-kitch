-- Issue 04 (puzzle rule library): a difficulty-5 generated level's flourish
-- entities (switch/teleport/jump_pad) must load as real, working entities,
-- and the level must still be completable by using only the cages --
-- flourishes are optional by construction (DECISIONS.md Q14).
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Main = require("tools.level_generator.main")

local GENERATED_PATH = "res/map/generated/_test_rules.tmj"

local function writeGeneratedFixture(seed, size, difficulty)
	local result = Main.generate({ seed = seed, count = 1, size = size, difficulty = difficulty })[1]
	local file = io.open(GENERATED_PATH, "w")
	file:write(result.tmj)
	file:close()
end

local function removeGeneratedFixture()
	os.remove(GENERATED_PATH)
end

test(
	"a difficulty-5 generated level loads with real switch/teleport/jump_pad entities, still completable ignoring them",
	function()
		writeGeneratedFixture(55, "large", 5)
		local ok, err = pcall(function()
			local game = GameHarness.startGame(GENERATED_PATH)
			FrameStepper.step(game, 5)

			assertTrue(#map:getEntitiesByType("switch") >= 1, "expected at least one switch entity")
			assertTrue(#map:getEntitiesByType("teleport") >= 1, "expected at least one teleport entity")
			assertTrue(#map:getEntitiesByType("jump_pad") >= 1, "expected at least one jump_pad entity")

			local player1 = game.fsm.currentState.players[1]
			for _, cage in ipairs(map:getEntitiesByType("cage")) do
				cage:use(player1)
			end

			local exitDoors = map:getEntitiesByType("exit_door")
			assertTrue(
				exitDoors[1].usable.enabled,
				"expected the exit to open from cages alone, ignoring every flourish"
			)
		end)
		removeGeneratedFixture()

		if not ok then
			error(err)
		end
	end
)
