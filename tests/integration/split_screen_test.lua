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

	-- move the players far apart horizontally (beyond the capped follow view)
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
	-- isSplit() alone isn't enough: InGameState:draw() actually gates on
	-- isCompositingActive(), which must also release once the players are
	-- merged and standing next to each other (not perfectly overlapping) or
	-- the composited two-pane view never releases back to the single shared
	-- camera in real play.
	assertFalse(
		ing.camera:isCompositingActive(),
		"the compositing path should release once close players have merged, not stay active forever"
	)
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

test("InGameState:draw() keeps taking the composited path through the whole merge-back, never dropping early just because isSplit() has already flipped false", function()
	-- conf.voronoi gates which path draw() takes at all; it's a process-wide
	-- global shared with every other integration test
	-- file in this run, so restore it afterward regardless of outcome.
	local prevVoronoi = conf.voronoi
	conf.voronoi = true

	local ok, err = pcall(function()
		local game = GameHarness.startGame(MAP)
		local ing = ingame(game)
		settle(game)

		-- Spy on which draw path InGameState:draw() actually takes each frame --
		-- this is what catches a regression to gating splitActive on the raw
		-- isSplit() boolean instead of the eased isCompositingActive() gate; a
		-- test that only re-derives the same eased quantity and checks it against
		-- itself would never fail even if draw() stopped consulting it.
		local pathTaken = nil
		local realVoronoi = ing.drawVoronoiSplit
		local realMerged = ing.drawMergedView
		ing.drawVoronoiSplit = function(self, ...)
			pathTaken = "voronoi"
			return realVoronoi(self, ...)
		end
		ing.drawMergedView = function(self, ...)
			pathTaken = "merged"
			return realMerged(self, ...)
		end

		setPlayerX(ing, 1, 64)
		setPlayerX(ing, 2, 560)
		settle(game)
		game:draw()
		assertEqual("voronoi", pathTaken, "precondition: split apart should draw the composited path")

		-- Bring the players together. isSplit() is a raw threshold: it flips to
		-- false the instant the required framing scale clears the merge-off
		-- margin, well before the panes themselves (which keep easing toward
		-- each player's own close-up view every frame, regardless of split
		-- state) have actually converged back together.
		setPlayerX(ing, 1, 300)
		setPlayerX(ing, 2, 320)

		local sawIsSplitFalseWhileStillDiverged = false
		for i = 1, 120 do
			FrameStepper.step(game, 1)
			game:draw()
			if not ing.camera:isSplit() and ing.camera:getSplitZoomBlend() > 0.01 then
				sawIsSplitFalseWhileStillDiverged = true
				assertEqual(
					"voronoi",
					pathTaken,
					"draw() dropped to the merged path at frame "
						.. i
						.. " while the panes are still apart, even though isSplit() has already flipped false"
				)
			end
		end

		assertTrue(
			sawIsSplitFalseWhileStillDiverged,
			"precondition: isSplit() should flip false before the panes have fully converged, or this test isn't exercising the gap it's meant to"
		)
	end)

	conf.voronoi = prevVoronoi
	if not ok then
		error(err, 0)
	end
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
