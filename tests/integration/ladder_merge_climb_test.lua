-- The per-rung ladder merge driven through the real Game/Map/World/Player
-- stack: four 32px ladder rungs (each a separate Tiled object, bottom-anchored)
-- merge into one logical ladder, and the player must be able to climb its full
-- height -- through every rung boundary -- without ever losing LadderState.
-- Without the merge these would be four independent ladder pieces and climbing
-- past a rung junction would drop the player back to FallState.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local FakeInputModule = require("tests.support.fake_input")
local Queries = require("tests.support.queries")

local FakeInput = FakeInputModule.FakeInput

local MAP = "tests/fixtures/ladder_platform_room.tmj"

local function player1(game)
	return game.fsm.currentState.players[1]
end

test("a merged per-rung ladder cooperates as one continuous climber", function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	FrameStepper.step(game, 60) -- settle onto the platform at the ladder's top

	local player = player1(game)
	local ladder = Queries.findEntityByName(map, "ladder1")
	assertEqual(4 * 32, ladder.rect.height, "fixture check: the four rungs should have merged into one 128px ladder")

	local mounted = false
	local fellOffMidClimb = false
	local dismountedLowestYet = false

	controller:press("down")

	local startY = Queries.playerPositionV(player).y
	for _ = 1, FrameStepper.secondsToFrames(2) do
		FrameStepper.step(game, 1)
		local stateName = player.fsm.currentState.name
		local y = Queries.playerPositionV(player).y

		if stateName == "LadderState" then
			mounted = true
		elseif mounted then
			if y < startY + 4 * 32 - 8 then
				-- left the ladder well before reaching its foot: a rung boundary
				-- leaked. Reaching the foot legitimately drops into WalkIdle.
				fellOffMidClimb = true
			end
		end
	end

	controller:release("down")

	assertTrue(mounted, "expected pressing down to mount the ladder")
	assertFalse(fellOffMidClimb, "expected to stay mounted through every rung junction, not fall off mid-climb")
end)
