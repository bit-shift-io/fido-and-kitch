-- Slice 04 (beam power-up telegraph), driven through the real Game/Map/
-- World/Player stack -- reuses tests/fixtures/laser_kill_room.tmj and the
-- GameHarness/FrameStepper/Queries pattern from
-- tests/integration/laser_kill_test.lua. That file covers the pre-existing
-- "an enabled laser kills a falling player" behaviour (still true here,
-- once the beam has finished warming up); this file covers the power
-- telegraph itself: a beam mid-warming or mid-cooling must never kill,
-- only a beam held at the fully 'on' frame may.
--
-- The fixture's laser spawns enabled with nothing wired to switch it off,
-- so it starts warming on the very first frame, and the player (spawned
-- directly in the beam's column, with no ground in this room -- see the
-- fixture) is inside the beam's path from frame 1 onward. POWER_DURATION
-- (src/entities/laser.lua) is 0.3s = 18 frames at the fixed 1/60 timestep
-- (FrameStepper.secondsToFrames), so this file drives frame counts
-- relative to that rather than a hard-coded 18 to stay correct if the
-- constant ever changes.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Queries = require("tests.support.queries")

local MAP = "tests/fixtures/laser_kill_room.tmj"

local function player1(game)
	return game.fsm.currentState.players[1]
end

-- Deferred require: GameHarness.startGame boots the class globals (Class,
-- Entity, ...) src/entities/laser.lua needs at load time, so this file
-- can't require it before the first game has started, unlike the pure
-- laser_beam_resolver require in laser_kill_test.lua's sibling.
local function warmupFrames()
	local Laser = require("src.entities.laser")
	return FrameStepper.secondsToFrames(Laser._internal.powerDuration)
end

test("a beam mid-warming does not kill a player standing in its path", function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByType(map, "laser")

	-- one frame short of the warm-up completing
	FrameStepper.step(game, warmupFrames() - 1)

	assertEqual("warming", laser.powerState)
	assertFalse(player1(game):isDead(), "a warming beam must not kill, even standing in its path")
end)

test("the same beam kills once its warm-up completes and it holds at on", function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByType(map, "laser")

	-- one frame into fully 'on' -- the acceptance criterion this slice must
	-- not regress: full power still kills exactly as slice 03 established
	FrameStepper.step(game, warmupFrames() + 1)

	assertEqual("on", laser.powerState)
	assertTrue(player1(game):isDead(), "expected the fully-on beam to kill the player")
	assertEqual("laser", player1(game).deathType)
end)

test("switching off mid-warming reverses into cooling, and cooling never kills either", function()
	local game = GameHarness.startGame(MAP)
	local laser = Queries.findEntityByType(map, "laser")

	-- halfway through the warm-up telegraph
	FrameStepper.step(game, math.floor(warmupFrames() / 2))
	assertEqual("warming", laser.powerState)

	laser:getComponent(Switchable):switch({ state = "off" })
	game:update(1 / 60)

	-- interrupted mid-warming reverses in place -- 'cooling', never an
	-- instant snap straight back to 'off'
	assertEqual("cooling", laser.powerState)
	assertFalse(player1(game):isDead(), "the interrupt itself must not kill")

	-- hold the player in the beam's path through the entire cool-down --
	-- comfortably longer than the reversed remainder can take
	for _ = 1, warmupFrames() do
		game:update(1 / 60)
		assertFalse(player1(game):isDead(), "a cooling beam must not kill, even standing in its path")
		if laser.powerState == "off" then
			break
		end
	end

	assertEqual("off", laser.powerState, "expected the interrupted power-down to finish reaching off")
	assertFalse(player1(game):isDead(), "the player must have survived the whole warm-up + cool-down cycle")
end)
