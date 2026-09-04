-- Headless tests for the auto-zoom camera: pure framing math, frame-rate
-- independent smoothing, overview/game-over modes, and transient extra
-- targets (dying-player respawn framing). No LÖVE dependency.
local Camera = require("src.camera")

local TILE = 32
local MAP_W = TILE * 40
local MAP_H = TILE * 30
local SCREEN_W = 800
local SCREEN_H = 600

local function playerRect(x, y, w, h)
	return { x = x, y = y, w = w or 20, h = h or 30 }
end

local function opts(overrides)
	local o = { marginTiles = 2, minViewTiles = 5, tileW = TILE, tileH = TILE }
	for k, v in pairs(overrides or {}) do
		o[k] = v
	end
	return o
end

-- ===== Issue 01: framing math =====

test("a single target is framed at the minimum 5x5 tile view, centred on it", function()
	local target = playerRect(500, 500, 20, 30)
	local view = Camera.computeFraming({ target }, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())

	local minViewW = 5 * TILE
	local minViewH = 5 * TILE
	assertTrue(
		view.w <= minViewW + 0.001 or view.h <= minViewH + 0.001,
		"expected the tighter screen-fit axis to sit at (or above) the 5x5 tile minimum"
	)
	assertNear(target.x + target.w / 2, view.cx, 1, "view should be centred on the single target")
	assertNear(target.y + target.h / 2, view.cy, 1, "view should be centred on the single target")
end)

test("two distant targets both fit on screen with margin, further apart than the min view", function()
	local a = playerRect(400, 400)
	local b = playerRect(900, 700)
	local view = Camera.computeFraming({ a, b }, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())

	assertTrue(view.x <= a.x and view.x <= b.x, "view left edge should be at or before both targets")
	assertTrue(view.y <= a.y and view.y <= b.y, "view top edge should be at or before both targets")
	assertTrue(
		view.x + view.w >= a.x + a.w and view.x + view.w >= b.x + b.w,
		"view right edge should be at or after both targets"
	)
	assertTrue(
		view.y + view.h >= a.y + a.h and view.y + view.h >= b.y + b.h,
		"view bottom edge should be at or after both targets"
	)
end)

test("targets near the top-left corner clamp the view to map bounds", function()
	local a = playerRect(10, 10)
	local b = playerRect(60, 40)
	local view = Camera.computeFraming({ a, b }, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())

	assertTrue(view.x >= -0.001, "view should not show negative-x space beyond the map edge")
	assertTrue(view.y >= -0.001, "view should not show negative-y space beyond the map edge")
end)

test("targets near the bottom-right corner clamp the view to map bounds", function()
	local a = playerRect(MAP_W - 40, MAP_H - 40)
	local b = playerRect(MAP_W - 90, MAP_H - 70)
	local view = Camera.computeFraming({ a, b }, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())

	assertTrue(view.x + view.w <= MAP_W + 0.001, "view should not extend past the right map edge")
	assertTrue(view.y + view.h <= MAP_H + 0.001, "view should not extend past the bottom map edge")
end)

test("targets spread wider than the map fall back to the full-map view, centred on the map", function()
	local a = playerRect(-1000, MAP_H / 2)
	local b = playerRect(MAP_W + 1000, MAP_H / 2)
	local view = Camera.computeFraming({ a, b }, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())

	assertNear(MAP_W / 2, view.cx, 1, "x should centre on the map when targets exceed map width")
end)

test("a wide box picks the horizontal fit scale (the tighter axis)", function()
	local a = playerRect(0, 500)
	local b = playerRect(700, 520)
	local view = Camera.computeFraming({ a, b }, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())

	local expectedScale = SCREEN_W / view.w
	assertNear(expectedScale, view.scale, 0.01, "scale should be derived from the tighter-fitting axis")
end)

test("the full-map view exactly covers the map, letterboxed to the screen aspect", function()
	local view = Camera.fullMapView(MAP_W, MAP_H, SCREEN_W, SCREEN_H)

	assertNear(MAP_W / 2, view.cx, 0.5)
	assertNear(MAP_H / 2, view.cy, 0.5)
	assertNear(math.min(SCREEN_W / MAP_W, SCREEN_H / MAP_H), view.scale, 0.0001)
end)

-- ===== Issue 02: smoothing & level start =====

test("a new camera starts at the full-map view", function()
	local camera = Camera.new({ screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE })
	local full = Camera.fullMapView(MAP_W, MAP_H, SCREEN_W, SCREEN_H)

	assertNear(full.cx, camera.cx, 0.001)
	assertNear(full.cy, camera.cy, 0.001)
	assertNear(full.scale, camera.scale, 0.0001)
end)

test("the camera converges toward the follow target within half a second of updates", function()
	local camera =
		Camera.new(opts({ screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE }))
	local target = { playerRect(600, 500) }
	local expected = Camera.computeFraming(target, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())

	local dt = 1 / 60
	local elapsed = 0
	while elapsed < 0.5 do
		camera:update(dt, target)
		elapsed = elapsed + dt
	end

	assertNear(expected.cx, camera.cx, 1, "centre x should have converged")
	assertNear(expected.cy, camera.cy, 1, "centre y should have converged")
	assertNear(expected.scale, camera.scale, 0.01, "zoom should have converged")
end)

test("smoothing is frame-rate independent: coarse and fine steps land at ~the same view", function()
	local target = { playerRect(600, 500) }

	local coarse = Camera.new({ screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE })
	local fine = Camera.new({ screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE })

	local simulated = 0
	while simulated < 0.25 do
		coarse:update(1 / 30, target)
		simulated = simulated + 1 / 30
	end

	simulated = 0
	while simulated < 0.25 do
		fine:update(1 / 120, target)
		simulated = simulated + 1 / 120
	end

	assertNear(fine.cx, coarse.cx, 2, "x should reach ~the same place regardless of step size")
	assertNear(fine.cy, coarse.cy, 2, "y should reach ~the same place regardless of step size")
	assertNear(fine.scale, coarse.scale, 0.02, "zoom should reach ~the same place regardless of step size")
end)

test("smoothing never overshoots the target", function()
	local camera = Camera.new({ screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE })
	local target = { playerRect(600, 500) }
	local expected = Camera.computeFraming(target, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())

	local startCx = camera.cx
	local dt = 1 / 60
	for _ = 1, 120 do
		camera:update(dt, target)
		local movedTowardTarget = (expected.cx - startCx) >= 0
		if movedTowardTarget then
			assertTrue(camera.cx <= expected.cx + 0.01, "camera should not overshoot the target centre x")
		else
			assertTrue(camera.cx >= expected.cx - 0.01, "camera should not overshoot the target centre x")
		end
	end
end)

-- ===== Issue 03: overview toggle =====

test("overview mode targets the full-map view regardless of player positions", function()
	local camera = Camera.new({ screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE })
	camera:setMode("overview")

	local target = camera:computeTargetView({ playerRect(600, 500) })
	local full = Camera.fullMapView(MAP_W, MAP_H, SCREEN_W, SCREEN_H)

	assertNear(full.cx, target.cx, 0.001)
	assertNear(full.scale, target.scale, 0.0001)
end)

test("toggling overview twice returns to the follow target", function()
	local camera = Camera.new({ screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE })
	assertEqual("follow", camera:getMode())

	camera:toggleOverview()
	assertEqual("overview", camera:getMode())

	camera:toggleOverview()
	assertEqual("follow", camera:getMode())
end)

test("the transition between follow and overview is carried by the same smoothing", function()
	local camera = Camera.new({ screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE })
	local target = { playerRect(600, 500) }
	-- settle on the follow target first
	for _ = 1, 60 do
		camera:update(1 / 60, target)
	end
	local followScale = camera.scale

	camera:toggleOverview()
	camera:update(1 / 60, target)

	local full = Camera.fullMapView(MAP_W, MAP_H, SCREEN_W, SCREEN_H)
	local movingTowardFull = full.scale > followScale
	if movingTowardFull then
		assertTrue(
			camera.scale > followScale and camera.scale < full.scale,
			"mid-transition zoom should sit strictly between the follow and overview scales"
		)
	else
		assertTrue(
			camera.scale < followScale and camera.scale > full.scale,
			"mid-transition zoom should sit strictly between the follow and overview scales"
		)
	end
end)

-- ===== Issue 04: extra targets & game over =====

test("adding an extra target expands the view to include it", function()
	local camera = Camera.new({ screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE })
	local players = { playerRect(600, 500) }

	local withoutExtra = camera:computeTargetView(players)
	camera:addExtraTarget("respawn:player2", playerRect(1400, 1100))
	local withExtra = camera:computeTargetView(players)

	assertTrue(withExtra.w >= withoutExtra.w - 0.001, "view should be at least as wide once the extra target is added")
	assertTrue(withExtra.h >= withoutExtra.h - 0.001, "view should be at least as tall once the extra target is added")
end)

test("removing an extra target shrinks the view back to the live players", function()
	local camera = Camera.new({ screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE })
	local players = { playerRect(600, 500) }

	local baseline = camera:computeTargetView(players)
	camera:addExtraTarget("respawn:player2", playerRect(1400, 1100))
	camera:removeExtraTarget("respawn:player2")
	local afterRemoval = camera:computeTargetView(players)

	assertNear(baseline.cx, afterRemoval.cx, 0.001)
	assertNear(baseline.cy, afterRemoval.cy, 0.001)
	assertNear(baseline.scale, afterRemoval.scale, 0.0001)
end)

test("game-over mode yields the full-map view regardless of player positions", function()
	local camera = Camera.new({ screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE })
	camera:setMode("gameover")

	local target = camera:computeTargetView({ playerRect(50, 50) })
	local full = Camera.fullMapView(MAP_W, MAP_H, SCREEN_W, SCREEN_H)

	assertNear(full.cx, target.cx, 0.001)
	assertNear(full.cy, target.cy, 0.001)
	assertNear(full.scale, target.scale, 0.0001)
end)

test("toggling overview has no effect while game-over owns the view", function()
	local camera = Camera.new({ screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE })
	camera:setMode("gameover")
	camera:toggleOverview()

	assertEqual("gameover", camera:getMode())
end)

-- ===== draw params =====

test("getDrawParams centres the camera position on screen at the current zoom", function()
	local camera = Camera.new({ screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE })
	local vr = camera:getDrawParams()

	assertNear(camera.cx, (SCREEN_W / 2 - vr.tx) / vr.sx, 0.01)
	assertNear(camera.cy, (SCREEN_H / 2 - vr.ty) / vr.sy, 0.01)
	assertEqual(vr.sx, vr.sy)
end)

-- ===== Issue 05: world padding =====

-- ===== Euclidean split decision =====

local function settleSplit(cm, targets, steps)
	steps = steps or 60
	for _ = 1, steps do
		cm:updateSplit(1 / 60, targets)
	end
end

test("updateSplit eases to 1 when players are far apart (Euclidean > d_split)", function()
	local cm = Camera.CameraManager.new({
		screenW = SCREEN_W, screenH = SCREEN_H,
		mapW = MAP_W, mapH = MAP_H, tileW = TILE, padding = 0,
		d_merged = 100, d_split = 200,
	})
	-- Centre-to-centre distance = 600px > d_split=200
	settleSplit(cm, { playerRect(200, 300), playerRect(800, 300) })
	assertNear(1, cm:getSplitFactor(), 0.01, "far players should fully split")
	assertTrue(cm:isSplit(), "far players should be split")
end)

test("updateSplit eases to 0 when players are close (Euclidean < d_merged)", function()
	local cm = Camera.CameraManager.new({
		screenW = SCREEN_W, screenH = SCREEN_H,
		mapW = MAP_W, mapH = MAP_H, tileW = TILE, padding = 0,
		d_merged = 100, d_split = 200,
	})
	settleSplit(cm, { playerRect(200, 300), playerRect(800, 300) })
	assertTrue(cm:isSplit(), "precondition: split")

	settleSplit(cm, { playerRect(300, 300), playerRect(310, 300) }) -- dist ~10
	assertNear(0, cm:getSplitFactor(), 0.01, "close players should fully merge")
	assertFalse(cm:isSplit(), "close players should not be split")
end)

test("hysteresis holds split state when distance is between d_merged and d_split", function()
	local cm = Camera.CameraManager.new({
		screenW = SCREEN_W, screenH = SCREEN_H,
		mapW = MAP_W, mapH = MAP_H, tileW = TILE, padding = 0,
		d_merged = 100, d_split = 300,
	})
	-- Far: centre distance ~600 > d_split=300 → split
	settleSplit(cm, { playerRect(200, 300), playerRect(800, 300) })
	assertTrue(cm:isSplit(), "precondition: split")

	-- Mid-range: centre distance 150 (between 100 and 300) → stays split
	settleSplit(cm, { playerRect(300, 300), playerRect(450, 300) }, 10)
	assertTrue(cm:isSplit(), "hysteresis holds split in mid-range after split")
	assertNear(1, cm:getSplitFactor(), 0.001, "factor stays pinned at split target")
end)

test("hysteresis holds merged state when distance is between d_merged and d_split", function()
	local cm = Camera.CameraManager.new({
		screenW = SCREEN_W, screenH = SCREEN_H,
		mapW = MAP_W, mapH = MAP_H, tileW = TILE, padding = 0,
		d_merged = 100, d_split = 300,
	})
	assertFalse(cm:isSplit(), "precondition: merged at start")

	-- Mid-range: centre distance 150 → stays merged
	settleSplit(cm, { playerRect(300, 300), playerRect(450, 300) }, 10)
	assertFalse(cm:isSplit(), "hysteresis holds merged in mid-range")
	assertNear(0, cm:getSplitFactor(), 0.001)
end)

test("split factor eases smoothly toward its target", function()
	local cm = Camera.CameraManager.new({
		screenW = SCREEN_W, screenH = SCREEN_H,
		mapW = MAP_W, mapH = MAP_H, tileW = TILE, padding = 0,
		d_merged = 100, d_split = 200,
	})
	local far = { playerRect(200, 300), playerRect(800, 300) }
	cm:updateSplit(1 / 60, far)
	local afterOne = cm:getSplitFactor()
	cm:updateSplit(1 / 60, far)
	local afterTwo = cm:getSplitFactor()

	assertTrue(afterOne > 0 and afterOne < 1, "one frame should be part-way, not instantly 0 or 1")
	assertTrue(afterTwo > afterOne, "the factor should ease upward toward its target")
end)

test("isSplit is false in overview even when the split factor is high", function()
	local cm = Camera.CameraManager.new({
		screenW = SCREEN_W, screenH = SCREEN_H,
		mapW = MAP_W, mapH = MAP_H, tileW = TILE, padding = 0,
		d_merged = 100, d_split = 200,
	})
	settleSplit(cm, { playerRect(200, 300), playerRect(800, 300) })
	assertTrue(cm:isSplit(), "precondition: split in follow")

	cm:setMode("overview")
	assertFalse(cm:isSplit(), "overview collapses split to a single pane")
end)

test("diagonal split produces a non-zero angle", function()
	local cm = Camera.CameraManager.new({
		screenW = SCREEN_W, screenH = SCREEN_H,
		mapW = MAP_W, mapH = MAP_H, tileW = TILE, padding = 0,
		d_merged = 10, d_split = 200,
	})
	local diagonal = { playerRect(200, 200), playerRect(500, 500) }
	-- Run enough frames for the rotation clamp to accumulate ~45 deg
	for _ = 1, 30 do
		cm:updateSplit(1 / 60, diagonal)
	end

	local angle = cm:getSplitAngle()
	assertTrue(math.abs(angle) > 0.1, "diagonal placement should produce a non-zero split angle")
end)

test("splitAngle accessor returns the current angle", function()
	local cm = Camera.CameraManager.new({
		screenW = SCREEN_W, screenH = SCREEN_H,
		mapW = MAP_W, mapH = MAP_H, tileW = TILE, padding = 0,
		d_merged = 10, d_split = 200,
	})
	local angle = cm:getSplitAngle()
	assertEqual(0, angle, "angle starts at 0")
end)

test("per-pane cameras use minViewTiles=4 (tighter zoom)", function()
	local cm = Camera.CameraManager.new({
		screenW = SCREEN_W, screenH = SCREEN_H,
		mapW = MAP_W, mapH = MAP_H, tileW = TILE, padding = 0,
		d_merged = 100, d_split = 200,
	})
	local pane = cm:ensurePane(1)
	assertEqual(4, pane.minViewTiles, "pane camera should use minViewTiles=4")
end)

-- ===== CameraManager: per-pane cameras & overview collapse =====

local function manager()
	return Camera.CameraManager.new({
		screenW = SCREEN_W,
		screenH = SCREEN_H,
		mapW = MAP_W,
		mapH = MAP_H,
		tileW = TILE,
		padding = 0,
	})
end

test("every pane is primed to the merged view at split onset", function()
	local cm = manager()
	cm:setPaneScreenSize(1, 400, SCREEN_H)
	cm:setPaneScreenSize(2, 400, SCREEN_H)
	local players = { playerRect(600, 500), playerRect(900, 500) }

	-- Park the merged camera somewhere other than the initial full-map view so
	-- a primed pane is distinguishable from an unprmed (initial) pane.
	cm.merged.cx = 400
	cm.merged.cy = 300
	cm.merged.scale = 0.8

	local dt = 1 / 60
	-- On the very first update both panes should be seeded to the merged view
	-- (no stale initial full-map state on any pane).
	cm:updatePane(dt, 1, players)
	cm:updatePane(dt, 2, players)

	local p1 = cm:getPaneDrawParams(1)
	local p2 = cm:getPaneDrawParams(2)
	-- A pane that did NOT prime would still sit at the initial full-map scale;
	-- a primed pane carries (and eases from) the merged scale instead. Compute
	-- the initial full-map scale for comparison.
	local initial = Camera.fullMapView(MAP_W, MAP_H, 400, SCREEN_H).scale
	assertTrue(p1.sx > initial, "pane 1 primes to the merged scale (not the initial full-map scale)")
	assertTrue(p2.sx > initial, "pane 2 primes to the merged scale (not just pane 1)")
	assertNear(p1.sx, p2.sx, 0.001, "both panes ease from the same merged scale")
end)

test("getSplitDivergence is 0 with no panes and grows as panes ease apart", function()
	local cm = manager()
	cm:setPaneScreenSize(1, 400, SCREEN_H)
	cm:setPaneScreenSize(2, 400, SCREEN_H)
	local players = { playerRect(600, 500), playerRect(1500, 500) }

	-- No panes yet: divergence is 0.
	assertEqual(0, cm:getSplitDivergence(), "no panes means no divergence")

	local dt = 1 / 60
	cm:updatePane(dt, 1, players)
	cm:updatePane(dt, 2, players)
	local first = cm:getSplitDivergence()

	-- Let the panes ease apart over a second; divergence grows toward the
	-- player gap.
	local last = first
	local maxDiv = first
	for i = 1, 60 do
		cm:updatePane(dt, 1, players)
		cm:updatePane(dt, 2, players)
		maxDiv = math.max(maxDiv, cm:getSplitDivergence())
		last = cm:getSplitDivergence()
	end
	assertTrue(first >= 0, "divergence starts non-negative")
	assertTrue(last > first, "divergence grows as the panes settle apart")
	assertTrue(maxDiv > 100, "settled panes should diverge substantially from the shared framing")
end)

test("CameraManager pane cameras frame only their own player's targets", function()
	local cm = manager()
	cm:setPaneScreenSize(1, 400, SCREEN_H)	cm:setPaneScreenSize(2, 400, SCREEN_H)
	local players = { playerRect(600, 500), playerRect(900, 500) }

	-- settle each pane on its own player over half a second
	local dt = 1 / 60
	for i = 1, 30 do
		cm:updatePane(dt, 1, players)
		cm:updatePane(dt, 2, players)
	end

	local p1 = cm:getPaneDrawParams(1)
	local p2 = cm:getPaneDrawParams(2)
	local cx1 = (400 / 2 - p1.tx) / p1.sx
	local cx2 = (400 / 2 - p2.tx) / p2.sx
	assertNear(610, cx1, 8, "pane 1 centres on player 1's x")
	assertNear(910, cx2, 8, "pane 2 centres on player 2's x")
end)

test("pane zoom blends from the merged zoom so the split onset matches the shared view", function()
	local cm = manager()
	cm:setPaneScreenSize(1, 400, SCREEN_H)
	cm:setPaneScreenSize(2, 400, SCREEN_H)
	local players = { playerRect(600, 500), playerRect(900, 500) }

	-- Settle the panes on their own players so pane.scale = its close-up zoom.
	local dt = 1 / 60
	for i = 1, 60 do
		cm:updatePane(dt, 1, players)
		cm:updatePane(dt, 2, players)
	end

	local mergedScale = cm.merged.scale
	local p1Close = cm:getPaneDrawParams(1).sx
	assertTrue(p1Close > mergedScale + 0.001, "a settled close pane zooms in further than the merged view")

	-- At zoomBlend=0 (split onset) the pane renders at the MERGED zoom -- the
	-- same zoom the shared view just showed -- so there's no zoom jump.
	local p1Onset = cm:getPaneDrawParams(1, 200, 0, 0)
	assertNear(mergedScale, p1Onset.sx, 0.001, "zoomBlend=0 renders pane at the merged zoom")

	-- At zoomBlend=1 it renders at its own close-up zoom.
	local p1Full = cm:getPaneDrawParams(1, 200, 0, 1)
	assertNear(p1Close, p1Full.sx, 0.001, "zoomBlend=1 renders pane at its own close-up zoom")

	-- Halfway, scale sits between the two.
	local p1Half = cm:getPaneDrawParams(1, 200, 0, 0.5)
	assertNear((mergedScale + p1Close) / 2, p1Half.sx, 0.001, "zoomBlend=0.5 is the midpoint zoom")
end)

test("overview collapse: setting overview makes every pane + merged target the full map", function()
	local cm = manager()
	cm:setPaneScreenSize(1, 400, SCREEN_H)
	cm:setMode("overview")

	assertTrue(cm:isOverview(), "overview mode is reported by the manager")
	local merged = cm.merged:computeTargetView({ playerRect(600, 500) })
	assertNear(MAP_W / 2, merged.cx, 1, "merged camera targets map centre in overview")

	local pane = cm:ensurePane(1)
	local paneView = pane:computeTargetView({ playerRect(600, 500) })
	assertNear(MAP_W / 2, paneView.cx, 1, "pane camera also targets the full map in overview")
end)

test("game-over collapses to a single full-map view and blocks overview toggle", function()
	local cm = manager()
	cm:setMode("gameover")

	assertTrue(cm:isOverview(), "game-over counts as an overview collapse")
	cm:toggleOverview()
	assertEqual("gameover", cm:getMode(), "overview toggle should not exit game-over")
end)

test("per-pane respawn extra target frames only that pane, not the others", function()
	local cm = manager()
	cm:setPaneScreenSize(1, 400, SCREEN_H)
	cm:setPaneScreenSize(2, 400, SCREEN_H)
	local players = { playerRect(600, 500) }

	local p1wide = cm:ensurePane(1):computeTargetView(players)
	cm:addPaneExtraTarget(1, "respawn", playerRect(1400, 1100))
	local p1extra = cm:ensurePane(1):computeTargetView(players)
	assertTrue(p1extra.w >= p1wide.w - 0.001, "pane 1's view widens to include its respawn extra target")

	local p2 = cm:ensurePane(2):computeTargetView(players)
	assertNear(p1wide.cx, p2.cx, 0.001, "pane 2 is unaffected by pane 1's extra target")
	assertNear(p1wide.w, p2.w, 0.001, "pane 2's width is unchanged by pane 1's extra target")
end)

test("updateMerged eases the merged camera toward all player targets", function()
	local cm = manager()
	local expected = Camera.computeFraming({ playerRect(600, 500) }, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())

	local dt = 1 / 60
	local elapsed = 0
	while elapsed < 0.5 do
		cm:updateMerged(dt, { playerRect(600, 500) })
		elapsed = elapsed + dt
	end

	assertNear(expected.cx, cm.merged.cx, 1)
	assertNear(expected.cy, cm.merged.cy, 1)
end)

-- ===== split/merge FSM (hysteresis + easing) =====

test("split factor eases to 1 when Euclidean distance exceeds d_split", function()
	local cm = Camera.CameraManager.new({
		screenW = SCREEN_W, screenH = SCREEN_H,
		mapW = MAP_W, mapH = MAP_H, tileW = TILE, padding = 0,
		d_merged = 100, d_split = 200,
	})
	local far = { playerRect(200, 300), playerRect(800, 300) } -- dist ~600 > 200
	settleSplit(cm, far)
	assertNear(1, cm:getSplitFactor(), 0.01, "distant players should fully split")
	assertTrue(cm:isSplit(), "distant players should be split")
end)

test("split factor eases back to 0 when Euclidean distance drops below d_merged", function()
	local cm = Camera.CameraManager.new({
		screenW = SCREEN_W, screenH = SCREEN_H,
		mapW = MAP_W, mapH = MAP_H, tileW = TILE, padding = 0,
		d_merged = 100, d_split = 200,
	})
	settleSplit(cm, { playerRect(200, 300), playerRect(800, 300) })
	assertTrue(cm:isSplit(), "precondition: split")

	settleSplit(cm, { playerRect(300, 300), playerRect(310, 300) }) -- dist ~10
	assertNear(0, cm:getSplitFactor(), 0.01, "close players should fully merge")
	assertFalse(cm:isSplit(), "close players should not be split")
end)

test("hysteresis holds split state when distance is between d_merged and d_split", function()
	local cm = Camera.CameraManager.new({
		screenW = SCREEN_W, screenH = SCREEN_H,
		mapW = MAP_W, mapH = MAP_H, tileW = TILE, padding = 0,
		d_merged = 100, d_split = 400,
	})
	-- Far: centre distance ~600 > d_split=400 → split
	settleSplit(cm, { playerRect(200, 300), playerRect(800, 300) })
	assertTrue(cm:isSplit(), "precondition: split")

	-- Mid-range: centre distance 150 (between 100 and 400) → stays split
	local mid = { playerRect(300, 300), playerRect(450, 300) }
	settleSplit(cm, mid, 10)
	assertTrue(cm:isSplit(), "hysteresis holds split in mid-range")
	assertNear(1, cm:getSplitFactor(), 0.001, "factor stays pinned at split target")
end)

test("hysteresis: once merged, an in-between distance stays merged", function()
	local cm = Camera.CameraManager.new({
		screenW = SCREEN_W, screenH = SCREEN_H,
		mapW = MAP_W, mapH = MAP_H, tileW = TILE, padding = 0,
		d_merged = 100, d_split = 400,
	})
	assertFalse(cm:isSplit(), "precondition: merged at start")

	local mid = { playerRect(300, 300), playerRect(450, 300) }
	settleSplit(cm, mid, 10)
	assertFalse(cm:isSplit(), "hysteresis holds merged in mid-range")
	assertNear(0, cm:getSplitFactor(), 0.001)
end)

test("padding defaults to 0 so existing framing is unchanged", function()
	local view = Camera.computeFraming({ playerRect(600, 500) }, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())
	local padded =
		Camera.computeFraming({ playerRect(600, 500) }, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts({ padding = 0 }))

	assertNear(view.x, padded.x, 0.001)
	assertNear(view.y, padded.y, 0.001)
	assertNear(view.scale, padded.scale, 0.0001)
end)

test("the padded full-map view keeps at least pad of void around every map edge", function()
	local PAD = 16
	local view = Camera.fullMapView(MAP_W, MAP_H, SCREEN_W, SCREEN_H, PAD)

	assertTrue(view.x <= -PAD + 0.001, "left edge should be at least pad of void beyond the map")
	assertTrue(view.y <= -PAD + 0.001, "top edge should be at least pad of void beyond the map")
	assertTrue(view.x + view.w >= MAP_W + PAD - 0.001, "right edge should be at least pad of void beyond the map")
	assertTrue(view.y + view.h >= MAP_H + PAD - 0.001, "bottom edge should be at least pad of void beyond the map")
	assertNear(-PAD, view.y, 0.001, "the tighter-fitting axis should sit at exactly pad of void")
end)

test("a camera created with padding starts at the padded full-map view", function()
	local PAD = 16
	local camera =
		Camera.new({ screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE, padding = PAD })
	local full = Camera.fullMapView(MAP_W, MAP_H, SCREEN_W, SCREEN_H, PAD)

	assertNear(full.cx, camera.cx, 0.001)
	assertNear(full.cy, camera.cy, 0.001)
	assertNear(full.scale, camera.scale, 0.0001)
end)

test("follow framing keeps pad of void when targets span the whole map", function()
	local PAD = 16
	local a = playerRect(0, 0)
	local b = playerRect(MAP_W - 20, MAP_H - 30)
	local view = Camera.computeFraming({ a, b }, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts({ padding = PAD }))

	assertTrue(view.x <= -PAD + 0.001, "left edge should be at least pad of void beyond the map")
	assertTrue(view.y <= -PAD + 0.001, "top edge should be at least pad of void beyond the map")
	assertTrue(view.x + view.w >= MAP_W + PAD - 0.001, "right edge should be at least pad of void beyond the map")
	assertTrue(view.y + view.h >= MAP_H + PAD - 0.001, "bottom edge should be at least pad of void beyond the map")
end)

test("padding does not force a zoom-out for targets well inside the map", function()
	local PAD = 16
	local view =
		Camera.computeFraming({ playerRect(600, 500) }, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts({ padding = PAD }))

	assertTrue(view.x >= -0.001, "small targets should still clamp inside the map, not to the padded bounds")
	assertTrue(view.y >= -0.001)
	assertTrue(view.x + view.w <= MAP_W + 0.001)
	assertTrue(view.y + view.h <= MAP_H + 0.001)
end)

test("overview mode with padding targets the padded full-map view", function()
	local PAD = 16
	local camera =
		Camera.new({ screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE, padding = PAD })
	camera:setMode("overview")

	local target = camera:computeTargetView({ playerRect(600, 500) })
	local full = Camera.fullMapView(MAP_W, MAP_H, SCREEN_W, SCREEN_H, PAD)

	assertNear(full.cx, target.cx, 0.001)
	assertNear(full.cy, target.cy, 0.001)
	assertNear(full.scale, target.scale, 0.0001)
end)

-- ===== clampToMap = false (per-pane player-centred framing) =====

test("clampToMap=false centres the view on the player near a left edge", function()
	-- Player standing 50px from the left map edge.  With clampToMap=true
	-- the view is clamped so the player drifts right of centre; with
	-- clampToMap=false the view centres on the player regardless.
	local player = playerRect(50, 500)
	local clamped = Camera.computeFraming({ player }, MAP_W, MAP_H, SCREEN_W, SCREEN_H, {
		marginTiles = 2, minViewTiles = 4, tileW = TILE, tileH = TILE, clampToMap = true,
	})
	local unclamped = Camera.computeFraming({ player }, MAP_W, MAP_H, SCREEN_W, SCREEN_H, {
		marginTiles = 2, minViewTiles = 4, tileW = TILE, tileH = TILE, clampToMap = false,
	})

	-- The unclamped view should be centred on the player's centre, while the
	-- clamped view is pushed toward the left map edge.
	assertNear(player.x + 10, unclamped.cx, 0.001, "unclamped cx should track the player's centre")
	assertTrue(clamped.cx > unclamped.cx + 0.1, "clamped cx should be pushed right (clamped inside map)")
end)

test("clampToMap=false centres the view on the player near a bottom edge", function()
	local player = playerRect(600, MAP_H - 50)
	local unclamped = Camera.computeFraming({ player }, MAP_W, MAP_H, SCREEN_W, SCREEN_H, {
		marginTiles = 2, minViewTiles = 4, tileW = TILE, tileH = TILE, clampToMap = false,
	})
	-- The unclamped view should track the player's centre.
	assertNear(player.y + 15, unclamped.cy, 0.001, "unclamped cy should track the player's centre")
end)

test("clampToMap=false does not drift when the view spans the whole map", function()
	-- Two players spread across the entire map should produce the same
	-- centre as the padded full-map view.
	local unclamped = Camera.computeFraming(
		{ playerRect(0, 0), playerRect(MAP_W, MAP_H) },
		MAP_W, MAP_H, SCREEN_W, SCREEN_H,
		{ marginTiles = 2, minViewTiles = 4, tileW = TILE, tileH = TILE, padding = 16, clampToMap = false }
	)
	local full = Camera.fullMapView(MAP_W, MAP_H, SCREEN_W, SCREEN_H, 16)
	assertNear(full.cx, unclamped.cx, 0.001, "should snap to map-centre when wider than the map")
	assertNear(full.cy, unclamped.cy, 0.001, "should snap to map-centre when taller than the map")
end)
