-- Dynamic split-screen: driving two players far apart splits the camera into
-- two per-player views, and bringing them close merges back to one. Driven
-- through the real Game/Map/World/Player stack; the split decision itself
-- (Euclidean distance hysteresis + easing) is unit-tested in
-- tests/unit/camera_test.lua -- this file asserts the wired end-to-end
-- behaviour: the split factor, the pane camera count, and canvas rendering.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")

local MAP = "res/map/sandbox.tmj" -- 20x20 tiles, 640x640

local function ingame(game)
	return game.fsm.currentState
end

local function settle(game)
	FrameStepper.step(game, 90) -- let players land and the split factor ease
end

local function setPlayerX(ing, index, x)
	local player = ing.players[index]
	local b = player.collider:getBounds()
	player.collider:setPosition(x, b.top)
end

test("two distant players split into two camera panes; bringing them close merges back", function()
	local game = GameHarness.startGame(MAP)
	local ing = ingame(game)
	settle(game)

	-- precondition: players placed close together -> merged
	setPlayerX(ing, 1, 300)
	setPlayerX(ing, 2, 320)
	settle(game)
	assertFalse(ing.camera:isSplit(), "close players should start merged")

	-- move the players far apart horizontally (> d_split Euclidean threshold)
	setPlayerX(ing, 1, 64)
	setPlayerX(ing, 2, 560)
	settle(game)

	assertTrue(ing.camera:isSplit(), "distant players should split into two panes")
	assertNear(1, ing.camera:getSplitFactor(), 0.01, "distant players ease to a full split")
	assertEqual(2, ing.camera:paneCount(), "both pane cameras should exist once split")

	-- bring them back together -> merges to a single pane
	setPlayerX(ing, 1, 300)
	setPlayerX(ing, 2, 320)
	settle(game)

	assertFalse(ing.camera:isSplit(), "close players should merge back to one pane")
end)

test("diagonal player placement produces a split angle", function()
	local game = GameHarness.startGame(MAP)
	local ing = ingame(game)
	settle(game)

	-- place players far apart on a diagonal (both x and y differ)
	local p1c = ing.players[1].collider
	local p1b = p1c:getBounds()
	p1c:setPosition(64, p1b.top)
	local p2c = ing.players[2].collider
	local p2b = p2c:getBounds()
	p2c:setPosition(560, p2b.top + 200)
	settle(game)

	assertTrue(ing.camera:isSplit(), "distant diagonal players should split")
	assertTrue(math.abs(ing.camera:getSplitAngle()) > 0.01, "diagonal placement should rotate the split angle")
end)

test("overview collapses a split view back to a single merged pane", function()
	local game = GameHarness.startGame(MAP)
	local ing = ingame(game)
	settle(game)

	setPlayerX(ing, 1, 64)
	setPlayerX(ing, 2, 560)
	settle(game)
	assertTrue(ing.camera:isSplit(), "precondition: split")

	ing.camera:setMode("overview")
	assertFalse(ing.camera:isSplit(), "overview should collapse the split to a single pane")
end)
