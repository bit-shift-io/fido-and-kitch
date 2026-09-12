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

-- ===== Crossover split trigger =====
--
-- The trigger fires at the crossover: where the players' on-screen separation
-- (worldSeparation * the merged camera's eased zoom) reaches the on-screen
-- separation of the two split-region centroids -- the pixels the split view
-- would put those same players at. See updateSplit.
--
-- Deriving the numbers used below, for manager() (800x600, tileW=32, default
-- margin/minView of 6 tiles, player rects 20x30, MAX_VIEW_TILES=20):
--   crossover, players side by side (vertical line) = screenW/2 = 400
--   crossover, players stacked (horizontal line)    = screenH/2 = 300
--   required framing: bw = sepX + 20 + 2*6*32 = sepX + 404, bh = sepY + 414
--   merged scale = max(min(800/bw, 600/bh), capFloor), capFloor =
--                  max(800/640, 600/640) = 1.25
-- Side by side, any separation past sepX=236 has the merged camera pinned at
-- the cap's 1.25, so on-screen separation is simply sepX*1.25 and:
--   split-on  (> crossover)        -> sepX > 320
--   merge-off (< crossover * 0.98) -> sepX < 313.6
-- giving a deliberately narrow dead band of 313.6 < sepX <= 320.
--
-- These tests drive cm:update (not cm:updateSplit alone) because the trigger
-- reads the merged camera's *eased* scale -- what is actually on screen this
-- frame -- so the merged camera has to be running for the decision to mean
-- anything. Step counts are generous enough for that ease to settle from the
-- full-map view every level opens at.

local function settleSplit(cm, targets, steps)
	steps = steps or 150
	for _ = 1, steps do
		cm:update(1 / 60, targets)
	end
end

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

test("two players close together stay merged through many frames", function()
	local cm = manager()
	-- sepX=10 -> on-screen separation ~14px, nowhere near the 400 crossover.
	settleSplit(cm, { playerRect(300, 300), playerRect(310, 300) })
	assertFalse(cm:isSplit(), "close players should never trigger a split")
end)

test("separating players past the crossover triggers a split", function()
	local cm = manager()
	assertFalse(cm:isSplit(), "precondition: merged at start")

	-- sepX=700 -> on-screen separation 875 > the 400 crossover.
	settleSplit(cm, { playerRect(200, 300), playerRect(900, 300) })
	assertTrue(cm:isSplit(), "players drawn further apart than their split positions should split")
	assertNear(1, cm:getSplitFactor(), 0.01, "split factor should ease fully to 1")
end)

test("bringing players back to just inside the crossover holds the split (dead band)", function()
	local cm = manager()
	settleSplit(cm, { playerRect(200, 300), playerRect(900, 300) })
	assertTrue(cm:isSplit(), "precondition: split")

	-- sepX=316 -> on-screen separation 395, inside the 392..400 dead band.
	settleSplit(cm, { playerRect(300, 300), playerRect(616, 300) }, 30)
	assertTrue(cm:isSplit(), "dead band should hold the split just inside the crossover")

	-- sepX=250 -> on-screen separation 312.5, below the 392 merge-off.
	settleSplit(cm, { playerRect(300, 300), playerRect(550, 300) }, 30)
	assertFalse(cm:isSplit(), "well inside the crossover should release the split")
end)

test("separation held exactly at the crossover produces no state change", function()
	local cm = manager()
	assertFalse(cm:isSplit(), "precondition: merged at start")

	-- sepX=320 -> on-screen separation exactly 400: equal to (not greater
	-- than) the crossover, so it never triggers.
	local boundary = { playerRect(300, 300), playerRect(620, 300) }
	settleSplit(cm, boundary) -- let the merged zoom settle onto the cap first

	local changes = 0
	local last = cm:isSplit()
	for _ = 1, 100 do
		cm:update(1 / 60, boundary)
		local now = cm:isSplit()
		if now ~= last then
			changes = changes + 1
			last = now
		end
	end
	assertEqual(0, changes, "holding exactly at the crossover should never flip splitState")
end)

test("oscillating a player across the crossover produces at most one state change", function()
	local cm = manager()
	local below = { playerRect(300, 300), playerRect(616, 300) } -- sepX=316, on-screen 395 (dead band)
	local above = { playerRect(300, 300), playerRect(630, 300) } -- sepX=330, on-screen 412.5 (splits)
	settleSplit(cm, below) -- settle the merged zoom before oscillating

	local changes = 0
	local last = cm:isSplit()
	for i = 1, 100 do
		local targets = (i % 2 == 0) and below or above
		cm:update(1 / 60, targets)
		local now = cm:isSplit()
		if now ~= last then
			changes = changes + 1
			last = now
		end
	end
	assertTrue(changes <= 1, "oscillating across the crossover should flip splitState at most once")
end)

test("a purely vertical separation triggers the split (trigger is not horizontal-only)", function()
	local cm = manager()
	-- Stacked players put the line horizontal, so the crossover is screenH/2
	-- = 300; sepY=300 at the capped 1.25 zoom is 375 on screen, past it.
	settleSplit(cm, { playerRect(400, 200), playerRect(400, 500) })
	assertTrue(cm:isSplit(), "vertical-only separation should trigger a split")
end)

test("the split trigger does not depend on screen resolution or aspect ratio", function()
	-- Regression test: an earlier version of the trigger compared
	-- screen-resolution-derived scales (min(screenW/bw, screenH/bh) against
	-- max(screenW,screenH)/(capTiles*tile)), which are governed by different
	-- screen dimensions and so silently depend on the window's aspect ratio.
	-- At the 800x600 (~4:3) resolution every other test in this file uses,
	-- that bug didn't show; at the game's real 1280x720 (16:9) window it
	-- meant the split trigger fired for *any* player arrangement, including
	-- players standing right next to each other, and never released.
	for _, res in ipairs({ { 800, 600 }, { 1280, 720 }, { 1920, 1080 }, { 640, 480 } }) do
		local cm = Camera.CameraManager.new({
			screenW = res[1],
			screenH = res[2],
			mapW = MAP_W,
			mapH = MAP_H,
			tileW = TILE,
			padding = 0,
		})

		settleSplit(cm, { playerRect(300, 300), playerRect(320, 300) }, 30)
		assertFalse(cm:isSplit(), string.format("close players should stay merged at %dx%d", res[1], res[2]))

		settleSplit(cm, { playerRect(64, 300), playerRect(1200, 300) }, 30)
		assertTrue(cm:isSplit(), string.format("far players should split at %dx%d", res[1], res[2]))
	end
end)

-- ===== The split opens and closes without moving anything =====
--
-- These drive the manager the way the game does -- players walking, one frame
-- at a time, through cm:update -- and watch what a player's rendered position
-- does across the transition, taking whichever draw path InGameState would
-- take that frame. That is the property the crossover trigger exists for, and
-- it is not visible to any test that only asserts on isSplit().

-- A player's on-screen x this frame, via the path that would actually draw it.
local function renderedX(cm, index, worldRect)
	local params = cm:isCompositingActive() and cm:getPaneDrawParams(index, 0, 0, cm:getSplitZoomBlend())
		or cm:getMergedDrawParams()
	return (worldRect.x + worldRect.w / 2) * params.sx + params.tx
end

local function realResolutionManager()
	local cm = Camera.CameraManager.new({
		screenW = 1280, -- the game's real window (conf.lua), not this file's 800x600
		screenH = 720,
		mapW = TILE * 125,
		mapH = TILE * 60,
		tileW = TILE,
		padding = 0,
	})
	cm:setPaneScreenSize(1, 1280, 720)
	cm:setPaneScreenSize(2, 1280, 720)
	return cm
end

test("walking apart and back together never steps a player across the screen", function()
	local cm = realResolutionManager()
	local ax, bx = 2000, 2000
	local function targets()
		return { playerRect(ax, 600), playerRect(bx, 600) }
	end

	-- Settle the level-start ease (the camera opens on the full-map view).
	for _ = 1, 150 do
		cm:update(1 / 60, targets())
	end

	local prev1, prev2 = renderedX(cm, 1, targets()[1]), renderedX(cm, 2, targets()[2])
	local worst, worstFrame, sawSplit, sawMerge = 0, 0, false, false
	local wasSplit = cm:isSplit()

	-- 2 world px per frame each, apart for 350 frames then back together.
	for i = 1, 900 do
		local dir = (i <= 350) and 1 or -1
		ax, bx = ax - 2 * dir, bx + 2 * dir
		if bx < ax then
			bx = ax
		end
		cm:update(1 / 60, targets())

		local s1, s2 = renderedX(cm, 1, targets()[1]), renderedX(cm, 2, targets()[2])
		local step = math.max(math.abs(s1 - prev1), math.abs(s2 - prev2))
		if step > worst then
			worst, worstFrame = step, i
		end
		if cm:isSplit() and not wasSplit then
			sawSplit = true
		end
		if not cm:isSplit() and wasSplit then
			sawMerge = true
		end
		wasSplit, prev1, prev2 = cm:isSplit(), s1, s2
	end

	assertTrue(sawSplit, "precondition: walking apart should have split the screen")
	assertTrue(sawMerge, "precondition: walking back together should have merged it")
	-- The players themselves move 2 world px/frame, which at the capped 2.0
	-- zoom is 4px on screen; the rest is the cameras' own easing. A split that
	-- opened anywhere but the crossover shows up here as a step of ~a quarter
	-- of the screen (320px) on the onset frame.
	assertTrue(
		worst < 40,
		string.format("no frame should step a player more than an eased amount (worst %.1fpx at frame %d)", worst, worstFrame)
	)
end)

test("the split opens with each player already where the split view draws them", function()
	local cm = realResolutionManager()
	local ax, bx = 2000, 2000
	local function targets()
		return { playerRect(ax, 600), playerRect(bx, 600) }
	end
	for _ = 1, 150 do
		cm:update(1 / 60, targets())
	end

	local onset1, onset2
	for _ = 1, 600 do
		ax, bx = ax - 2, bx + 2
		cm:update(1 / 60, targets())
		if cm:isSplit() then
			-- On the onset frame, compare where each pane draws its player
			-- against where the merged camera draws the same player. Equal
			-- means the divider appears over a still image.
			local merged = cm:getMergedDrawParams()
			local t = targets()
			local function mergedX(rect)
				return (rect.x + rect.w / 2) * merged.sx + merged.tx
			end
			onset1 = renderedX(cm, 1, t[1]) - mergedX(t[1])
			onset2 = renderedX(cm, 2, t[2]) - mergedX(t[2])
			break
		end
	end

	assertTrue(onset1 ~= nil, "precondition: the players should have walked far enough apart to split")
	assertNear(0, onset1, 12, "player 1 should not move when the split appears")
	assertNear(0, onset2, 12, "player 2 should not move when the split appears")
end)

test("players swapping sides re-split without rotating the divider a half turn", function()
	local cm = realResolutionManager()
	-- Player 1 left, player 2 right, far enough apart to be split.
	local ax, bx = 1200, 2800
	local function targets()
		return { playerRect(ax, 600), playerRect(bx, 600) }
	end
	for _ = 1, 300 do
		cm:update(1 / 60, targets())
	end
	assertTrue(cm:isSplit(), "precondition: split with player 1 on the left")
	local startAngle = cm:getSplitAngle()

	-- Now they walk through each other and keep going, swapping sides.
	local worstRotation, wasSplit, sawMerge, sawResplit = 0, true, false, false
	local prevAngle = startAngle
	for _ = 1, 500 do
		ax, bx = ax + 2, bx - 2
		cm:update(1 / 60, targets())
		-- Only rotation while the divider is actually on screen can be seen.
		if cm:isCompositingActive() then
			worstRotation = math.max(worstRotation, math.abs(cm:getSplitAngle() - prevAngle))
		end
		if not cm:isSplit() and wasSplit then
			sawMerge = true
		end
		if cm:isSplit() and not wasSplit then
			sawResplit = true
		end
		wasSplit, prevAngle = cm:isSplit(), cm:getSplitAngle()
	end

	assertTrue(sawMerge, "precondition: passing each other should merge the screen")
	assertTrue(sawResplit, "precondition: continuing past each other should split it again")
	-- The line ends up a half turn from where it started -- same line, sides
	-- swapped, which is correct now that the players have swapped. What must
	-- not happen is the divider visibly sweeping there.
	assertNear(math.pi, math.abs(cm:getSplitAngle() - startAngle), 0.05, "the line should end up reversed")
	assertTrue(
		worstRotation < 0.05,
		string.format("the divider should not visibly rotate while swapping sides (worst %.1f deg/frame)", worstRotation * 180 / math.pi)
	)
end)

test("split factor eases smoothly toward its target", function()
	local cm = manager()
	local far = { playerRect(200, 300), playerRect(900, 300) }
	cm:updateSplit(1 / 60, far)
	local afterOne = cm:getSplitFactor()
	cm:updateSplit(1 / 60, far)
	local afterTwo = cm:getSplitFactor()

	assertTrue(afterOne > 0 and afterOne < 1, "one frame should be part-way, not instantly 0 or 1")
	assertTrue(afterTwo > afterOne, "the factor should ease upward toward its target")
end)

test("isSplit is false in overview even when the split factor is high", function()
	local cm = manager()
	settleSplit(cm, { playerRect(200, 300), playerRect(900, 300) })
	assertTrue(cm:isSplit(), "precondition: split in follow")

	cm:setMode("overview")
	assertFalse(cm:isSplit(), "overview collapses split to a single pane")
end)

test("diagonal split produces a non-zero angle", function()
	local cm = manager()
	local diagonal = { playerRect(200, 200), playerRect(500, 500) }
	-- Run enough frames for the rotation clamp to accumulate ~45 deg
	for _ = 1, 30 do
		cm:updateSplit(1 / 60, diagonal)
	end

	local angle = cm:getSplitAngle()
	assertTrue(math.abs(angle) > 0.1, "diagonal placement should produce a non-zero split angle")
end)

test("splitAngle accessor returns the current angle", function()
	local cm = manager()
	local angle = cm:getSplitAngle()
	assertEqual(0, angle, "angle starts at 0")
end)

test("per-pane cameras use minViewTiles=4 (tighter zoom)", function()
	local cm = manager()
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

test("getSplitDivergence is 0 on the shared view and grows as the panes pull away from it", function()
	local cm = manager()

	-- No panes at all: nothing has diverged from anything.
	assertEqual(0, cm:getSplitDivergence(), "no panes means no divergence")

	cm:setPaneScreenSize(1, SCREEN_W, SCREEN_H)
	cm:setPaneScreenSize(2, SCREEN_W, SCREEN_H)

	-- Merged: the panes are held exactly on the shared view, so the quantity
	-- divergence actually measures -- how far each pane's rendering is from
	-- the merged camera's -- is zero, not merely small.
	settleSplit(cm, { playerRect(600, 500), playerRect(620, 500) })
	assertFalse(cm:isSplit(), "precondition: close players are merged")
	assertNear(0, cm:getSplitDivergence(), 0.001, "panes showing the shared view have not diverged from it")

	-- Split: each pane pulls away toward its own player's close-up framing.
	settleSplit(cm, { playerRect(200, 500), playerRect(1000, 500) })
	assertTrue(cm:isSplit(), "precondition: far players are split")
	assertTrue(cm:getSplitDivergence() > 100, "settled split panes diverge substantially from the shared view")
end)

test("CameraManager pane cameras frame only their own player's targets", function()
	local cm = manager()
	cm:setPaneScreenSize(1, SCREEN_W, SCREEN_H)
	cm:setPaneScreenSize(2, SCREEN_W, SCREEN_H)
	-- Panes only frame their own player while actually split (see updatePane);
	-- merged, they are held on the shared view. sepX=400 is past the crossover.
	local players = { playerRect(600, 500), playerRect(1000, 500) }
	settleSplit(cm, players)
	assertTrue(cm:isSplit(), "precondition: split")

	local p1 = cm:getPaneDrawParams(1)
	local p2 = cm:getPaneDrawParams(2)
	-- The pane no longer anchors at its own screen midpoint -- it anchors at
	-- the centroid of its split region, so recover the world x through that
	-- anchor rather than a hardcoded paneScreenW/2.
	local cx1 = (cm:getPaneAnchor(1).x - p1.tx) / p1.sx
	local cx2 = (cm:getPaneAnchor(2).x - p2.tx) / p2.sx
	assertNear(610, cx1, 8, "pane 1 centres on player 1's x")
	assertNear(1010, cx2, 8, "pane 2 centres on player 2's x")
end)

test("pane zoom blends from the merged zoom so the split onset matches the shared view", function()
	local cm = manager()
	cm:setPaneScreenSize(1, SCREEN_W, SCREEN_H)
	cm:setPaneScreenSize(2, SCREEN_W, SCREEN_H)
	-- Zooming in past the merged view only happens while actually split.
	local players = { playerRect(600, 500), playerRect(1000, 500) }
	settleSplit(cm, players)
	assertTrue(cm:isSplit(), "precondition: split")

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

-- ===== Follow zoom cap =====

test("computeFraming caps the view width at MAX_VIEW_TILES when targets are far apart", function()
	local a = playerRect(50, 500)
	local b = playerRect(MAP_W - 100, 520)
	local view =
		Camera.computeFraming({ a, b }, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts({ maxViewTiles = Camera.MAX_VIEW_TILES }))

	local maxW = Camera.MAX_VIEW_TILES * TILE
	local maxH = Camera.MAX_VIEW_TILES * TILE
	assertTrue(view.w <= maxW + 0.001, "view width should not exceed the cap")
	assertTrue(view.h <= maxH + 0.001, "view height should not exceed the cap")
end)

test("computeFraming without maxViewTiles is unaffected by the cap (existing behaviour unchanged)", function()
	local a = playerRect(50, 500)
	local b = playerRect(MAP_W - 100, 520)
	local view = Camera.computeFraming({ a, b }, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())

	local maxW = Camera.MAX_VIEW_TILES * TILE
	assertTrue(view.w > maxW, "without the cap option, a wide spread should still exceed the cap width")
end)

test("Camera.fullMapView is unaffected by the follow zoom cap on a map wider than the cap", function()
	local view = Camera.fullMapView(MAP_W, MAP_H, SCREEN_W, SCREEN_H)
	local maxW = Camera.MAX_VIEW_TILES * TILE
	assertTrue(view.w > maxW, "fullMapView should show more than the cap width on a map wider than the cap")
end)

test("follow mode caps the view at MAX_VIEW_TILES tiles wide however far apart the players are", function()
	local camera = Camera.new({ screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE })
	local far = { playerRect(50, 500), playerRect(MAP_W - 100, 520) }
	local target = camera:computeTargetView(far)

	local maxW = Camera.MAX_VIEW_TILES * TILE
	assertTrue(target.w <= maxW + 0.001, "follow view should never exceed the cap width")
end)

test("overview and game-over modes ignore the follow zoom cap on a map wider than the cap", function()
	local camera = Camera.new({ screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE })
	local full = Camera.fullMapView(MAP_W, MAP_H, SCREEN_W, SCREEN_H)

	camera:setMode("overview")
	local overviewTarget = camera:computeTargetView({})
	assertNear(full.scale, overviewTarget.scale, 0.0001, "overview should reach the full-map scale, not the capped scale")

	camera:setMode("gameover")
	local gameoverTarget = camera:computeTargetView({})
	assertNear(
		full.scale,
		gameoverTarget.scale,
		0.0001,
		"game-over should reach the full-map scale, not the capped scale"
	)
end)

test("a map narrower than the cap still frames flush with the existing padding behaviour", function()
	local smallMapW = 10 * TILE -- narrower than the 20-tile cap
	local smallMapH = 10 * TILE
	local view = Camera.computeFraming(
		{ playerRect(0, 0), playerRect(smallMapW, smallMapH) },
		smallMapW,
		smallMapH,
		SCREEN_W,
		SCREEN_H,
		opts({ maxViewTiles = Camera.MAX_VIEW_TILES })
	)
	local full = Camera.fullMapView(smallMapW, smallMapH, SCREEN_W, SCREEN_H)

	assertNear(full.cx, view.cx, 1, "narrower-than-cap map should still centre exactly as the full-map view does")
	assertNear(full.cy, view.cy, 1, "narrower-than-cap map should still centre exactly as the full-map view does")
	assertNear(full.scale, view.scale, 0.0001, "narrower-than-cap map should reach the same scale as the full-map view")
end)

-- ===== Centred rotating dividing line =====

test("the split line's normal is unit length at several separation angles", function()
	local anglesToTest = { 0, math.pi / 6, math.pi / 4, math.pi / 2, math.pi, -math.pi / 3 }
	for _, angle in ipairs(anglesToTest) do
		local line = Camera.CameraManager.computeSplitLine(SCREEN_W, SCREEN_H, angle, 0)
		local len = math.sqrt(line.nx * line.nx + line.ny * line.ny)
		assertNear(1, len, 0.0001, "line normal should be unit length at angle " .. angle)
	end
end)

test("the line point sits at screen centre while the offset scalar is zero", function()
	local line = Camera.CameraManager.computeSplitLine(SCREEN_W, SCREEN_H, math.pi / 5, 0)
	assertNear(SCREEN_W / 2, line.x, 0.0001, "line point x should be screen centre at zero offset")
	assertNear(SCREEN_H / 2, line.y, 0.0001, "line point y should be screen centre at zero offset")
end)

test("CameraManager:getSplitLine reports a centred line with the current split angle", function()
	local cm = manager()
	settleSplit(cm, { playerRect(200, 200), playerRect(500, 500) })

	local line = cm:getSplitLine()
	assertNear(SCREEN_W / 2, line.x, 0.0001, "line stays centred on screen")
	assertNear(SCREEN_H / 2, line.y, 0.0001, "line stays centred on screen")
	local len = math.sqrt(line.nx * line.nx + line.ny * line.ny)
	assertNear(1, len, 0.0001, "reported normal should be unit length")
end)

test("rotating players a full turn produces a continuously rotating normal with no sign flip", function()
	local cm = manager()
	local radius = 300
	local cxWorld, cyWorld = 1000, 1000
	local steps = 72 -- 5 deg per step
	local prevAngle = nil
	for i = 0, steps do
		local theta = (i / steps) * 2 * math.pi
		local p1 = playerRect(cxWorld - radius * math.cos(theta), cyWorld - radius * math.sin(theta))
		local p2 = playerRect(cxWorld + radius * math.cos(theta), cyWorld + radius * math.sin(theta))
		-- run several frames per step so the eased angle has time to track
		for _ = 1, 10 do
			cm:updateSplit(1 / 60, { p1, p2 })
		end
		local angle = cm:getSplitAngle()
		if prevAngle then
			local diff = angle - prevAngle
			assertTrue(math.abs(diff) < math.pi / 2, "the split angle should not jump by more than a small step per 5deg of rotation")
		end
		prevAngle = angle
	end
end)

test("players rotating at constant angular speed produce a uniform per-frame rotation, not a staircase", function()
	-- Regression test: the raw separation angle used to only update the
	-- easing target when it had moved more than a 5deg threshold since the
	-- last *target* update ("ignore tiny deltas to avoid jitter"). Ordinary
	-- continuous movement changes the raw angle by a small fraction of a
	-- degree per frame, so the target held still for many frames and then
	-- jumped once the accumulated change finally cleared the threshold -- a
	-- visible staircase, even though the underlying motion was perfectly
	-- smooth. Gating on separation distance instead (see
	-- ANGLE_DEGENERATE_SEPARATION) fixes this: the target updates every
	-- frame, and only genuinely near-zero separation holds it.
	--
	-- Both players circle a shared centre at constant angular speed (as in
	-- "rotating players a full turn" above), which is the one motion whose
	-- true separation angle changes at a genuinely constant rate -- so any
	-- unevenness in the *output* is the trigger's own doing, not a artifact
	-- of the geometry.
	-- A bigger map than manager()'s: circling at radius=900 needs room for
	-- both players to stay on it at every angle.
	local cm = Camera.CameraManager.new({
		screenW = SCREEN_W,
		screenH = SCREEN_H,
		mapW = TILE * 200,
		mapH = TILE * 200,
		tileW = TILE,
		padding = 0,
	})
	-- Circling at a fixed radius keeps the two players' world separation
	-- exactly constant (|p2-p1| = 2*radius regardless of angle), so a radius
	-- comfortably past the split threshold keeps splitState true for the
	-- entire warmup and measurement -- no merged/split transition to cross,
	-- which is its own (legitimate, one-frame) transient: the angle switches
	-- from snapped to eased right at that boundary, and measuring across it
	-- would flag that handoff rather than the staircase this test targets.
	local radius, cxWorld, cyWorld = 900, 3200, 3200
	local stepAngle = (math.pi / 2) / 180 -- the constant per-frame rotation rate
	local warmupFrames = 120 -- run the *same* constant rate first, so the
	-- eased angle is already tracking it at a steady lag before measuring --
	-- otherwise the transient from a cold start (target suddenly switching
	-- from static to ramping) shows up as spuriously uneven early steps.
	local measureFrames = 180

	local function playersAt(theta)
		return {
			playerRect(cxWorld - radius * math.cos(theta), cyWorld - radius * math.sin(theta)),
			playerRect(cxWorld + radius * math.cos(theta), cyWorld + radius * math.sin(theta)),
		}
	end

	for i = -warmupFrames + 1, 0 do
		cm:update(1 / 60, playersAt(i * stepAngle))
	end
	assertTrue(cm:isSplit(), "precondition: this radius should be well past the split threshold")

	local prevAngle, minStep, maxStep = cm:getSplitAngle(), math.huge, 0
	for i = 1, measureFrames do
		cm:update(1 / 60, playersAt(i * stepAngle))
		assertTrue(cm:isSplit(), "precondition: should stay split for the whole measurement window")
		local angle = cm:getSplitAngle()
		local step = math.abs(angle - prevAngle)
		minStep = math.min(minStep, step)
		maxStep = math.max(maxStep, step)
		prevAngle = angle
	end

	-- A staircase alternates near-zero steps (while the target holds) with
	-- occasional large ones (when it jumps); smooth, continuous motion at a
	-- constant angular rate keeps every step close to the same size.
	assertTrue(minStep > 0, "every frame of continuous rotation should move the line at least a little")
	assertTrue(
		maxStep < minStep * 3,
		string.format(
			"per-frame rotation should stay uniform under constant angular motion, not alternate between holds and jumps (min %.4f deg, max %.4f deg)",
			math.deg(minStep),
			math.deg(maxStep)
		)
	)
end)

test("aligned players (separation under the jitter threshold) hold the previous angle rather than snapping", function()
	local cm = manager()
	-- Establish a clear diagonal angle first.
	settleSplit(cm, { playerRect(200, 200), playerRect(500, 500) }, 60)
	local heldAngle = cm:getSplitAngle()

	-- Now make the players nearly aligned along a totally different axis, but
	-- within the jitter threshold of no movement (identical position ->
	-- degenerate separation angle). The held angle should not snap.
	cm:updateSplit(1 / 60, { playerRect(300, 300), playerRect(300, 300) })
	assertNear(heldAngle, cm:getSplitAngle(), 0.05, "near-zero separation should not snap the angle")
end)

test("a non-zero offset scalar moves the line point along the normal by exactly that amount", function()
	local angle = math.pi / 3
	local offset = 25
	local base = Camera.CameraManager.computeSplitLine(SCREEN_W, SCREEN_H, angle, 0)
	local offsetLine = Camera.CameraManager.computeSplitLine(SCREEN_W, SCREEN_H, angle, offset)

	local dx = offsetLine.x - base.x
	local dy = offsetLine.y - base.y
	local movedDistance = math.sqrt(dx * dx + dy * dy)
	assertNear(offset, movedDistance, 0.0001, "the point should move by exactly the offset amount")
	assertNear(offsetLine.nx, base.nx, 0.0001, "the normal itself is unaffected by the offset")
	assertNear(offsetLine.ny, base.ny, 0.0001, "the normal itself is unaffected by the offset")
end)

-- ===== Split region centroid (pane anchor geometry) =====

local function halfplaneValue(point, line, side)
	return side * ((point.x - line.x) * line.nx + (point.y - line.y) * line.ny)
end

test("vertical split line: region centroids are the hand-computed left/right half-centres", function()
	local line = { x = SCREEN_W / 2, y = SCREEN_H / 2, nx = 1, ny = 0 }
	local left = Camera.CameraManager.computeRegionCentroid(SCREEN_W, SCREEN_H, line, -1)
	local right = Camera.CameraManager.computeRegionCentroid(SCREEN_W, SCREEN_H, line, 1)

	assertNear(200, left.x, 0.01, "left half [0,400]x[0,600] centres at x=200")
	assertNear(300, left.y, 0.01)
	assertNear(600, right.x, 0.01, "right half [400,800]x[0,600] centres at x=600")
	assertNear(300, right.y, 0.01)
end)

test("horizontal split line: region centroids are the hand-computed top/bottom half-centres", function()
	local line = { x = SCREEN_W / 2, y = SCREEN_H / 2, nx = 0, ny = 1 }
	local top = Camera.CameraManager.computeRegionCentroid(SCREEN_W, SCREEN_H, line, -1)
	local bottom = Camera.CameraManager.computeRegionCentroid(SCREEN_W, SCREEN_H, line, 1)

	assertNear(400, top.x, 0.01)
	assertNear(150, top.y, 0.01, "top half [0,800]x[0,300] centres at y=150")
	assertNear(400, bottom.x, 0.01)
	assertNear(450, bottom.y, 0.01, "bottom half [0,800]x[300,600] centres at y=450")
end)

test("45-degree split line: region centroids match the hand-computed trapezoid centroids", function()
	local nx, ny = math.cos(math.pi / 4), math.sin(math.pi / 4)
	local line = { x = SCREEN_W / 2, y = SCREEN_H / 2, nx = nx, ny = ny }
	local a = Camera.CameraManager.computeRegionCentroid(SCREEN_W, SCREEN_H, line, -1)
	local b = Camera.CameraManager.computeRegionCentroid(SCREEN_W, SCREEN_H, line, 1)

	-- Hand-computed via the shoelace-weighted centroid of the quadrilateral
	-- {(0,0),(700,0),(100,600),(0,600)} the 45deg line through (400,300) cuts
	-- from the 800x600 rect (line is x+y=700).
	assertNear(237.5, a.x, 0.01)
	assertNear(225, a.y, 0.01)
	assertNear(562.5, b.x, 0.01)
	assertNear(375, b.y, 0.01)
end)

test("the two region centroids are reflections of each other through screen centre", function()
	local anglesToTest = { 0, math.pi / 6, math.pi / 4, math.pi / 3, math.pi / 2, 2 * math.pi / 3, math.pi }
	for _, angle in ipairs(anglesToTest) do
		local line = { x = SCREEN_W / 2, y = SCREEN_H / 2, nx = math.cos(angle), ny = math.sin(angle) }
		local a = Camera.CameraManager.computeRegionCentroid(SCREEN_W, SCREEN_H, line, -1)
		local b = Camera.CameraManager.computeRegionCentroid(SCREEN_W, SCREEN_H, line, 1)

		assertNear(SCREEN_W, a.x + b.x, 0.01, "centroids should reflect through screen centre x at angle " .. angle)
		assertNear(SCREEN_H, a.y + b.y, 0.01, "centroids should reflect through screen centre y at angle " .. angle)
	end
end)

test("sweeping the split angle through 360deg keeps each centroid strictly on its own side", function()
	local steps = 72 -- 5deg per step
	for i = 0, steps do
		local angle = (i / steps) * 2 * math.pi
		local line = { x = SCREEN_W / 2, y = SCREEN_H / 2, nx = math.cos(angle), ny = math.sin(angle) }
		local a = Camera.CameraManager.computeRegionCentroid(SCREEN_W, SCREEN_H, line, -1)
		local b = Camera.CameraManager.computeRegionCentroid(SCREEN_W, SCREEN_H, line, 1)

		assertTrue(
			halfplaneValue(a, line, -1) > 1e-6,
			"side -1 centroid should sit strictly inside its own half at angle " .. angle
		)
		assertTrue(
			halfplaneValue(b, line, 1) > 1e-6,
			"side 1 centroid should sit strictly inside its own half at angle " .. angle
		)
	end
end)

test("a zero-length line normal returns the screen centre rather than a NaN", function()
	local line = { x = SCREEN_W / 2, y = SCREEN_H / 2, nx = 0, ny = 0 }
	local c = Camera.CameraManager.computeRegionCentroid(SCREEN_W, SCREEN_H, line, -1)

	assertEqual(SCREEN_W / 2, c.x)
	assertEqual(SCREEN_H / 2, c.y)
	assertTrue(c.x == c.x and c.y == c.y, "centroid fields should never be NaN")
end)

test("a zero-area screen rect returns a safe value rather than a NaN", function()
	local line = { x = 0, y = 0, nx = 1, ny = 0 }
	local c = Camera.CameraManager.computeRegionCentroid(0, 0, line, -1)

	assertTrue(c.x == c.x and c.y == c.y, "centroid fields should never be NaN")
	assertTrue(c.x ~= math.huge and c.x ~= -math.huge, "centroid x should never be infinite")
	assertTrue(c.y ~= math.huge and c.y ~= -math.huge, "centroid y should never be infinite")
end)

test("getPaneDrawParams projects each player's world position onto its own side of the line", function()
	local cm = manager()
	cm:setPaneScreenSize(1, SCREEN_W, SCREEN_H)
	cm:setPaneScreenSize(2, SCREEN_W, SCREEN_H)

	local radius = 300
	local cxWorld, cyWorld = 1000, 1000
	local steps = 36 -- 10deg per step
	for i = 0, steps do
		local theta = (i / steps) * 2 * math.pi
		local p1 = playerRect(cxWorld - radius * math.cos(theta), cyWorld - radius * math.sin(theta))
		local p2 = playerRect(cxWorld + radius * math.cos(theta), cyWorld + radius * math.sin(theta))
		local targets = { p1, p2 }

		-- Let the split angle and pane anchors ease toward this step's geometry.
		-- Driven through cm:update: the containment guarantee is about where
		-- the *split* view draws each player, so the manager has to actually
		-- be split (merged, both panes are held on the shared view and there
		-- are no separate halves for a player to be contained in).
		for _ = 1, 20 do
			cm:update(1 / 60, targets)
		end
		assertTrue(cm:isSplit(), "precondition: split at step " .. i)

		local line = cm:getSplitLine()
		local params1 = cm:getPaneDrawParams(1)
		local params2 = cm:getPaneDrawParams(2)
		local player1Pixel = { x = (p1.x + p1.w / 2) * params1.sx + params1.tx, y = (p1.y + p1.h / 2) * params1.sy + params1.ty }
		local player2Pixel = { x = (p2.x + p2.w / 2) * params2.sx + params2.tx, y = (p2.y + p2.h / 2) * params2.sy + params2.ty }

		assertTrue(
			halfplaneValue(player1Pixel, line, -1) > -1e-6,
			"player 1's projected pixel should stay on pane 1's side of the line at step " .. i
		)
		assertTrue(
			halfplaneValue(player2Pixel, line, 1) > -1e-6,
			"player 2's projected pixel should stay on pane 2's side of the line at step " .. i
		)
	end
end)

-- ===== No zoom change at the split (pane zoom inheritance) =====

test("a pane's rendered scale equals the merged scale exactly on the split's onset frame", function()
	local cm = manager()
	cm:setPaneScreenSize(1, SCREEN_W, SCREEN_H)
	cm:setPaneScreenSize(2, SCREEN_W, SCREEN_H)

	-- Ease the players apart gradually, frame by frame, right up to the split
	-- trigger -- this is what makes the onset frame realistic: the merged
	-- camera has only just started easing toward the wider framing, rather
	-- than jumping there from a wildly different state in a single frame.
	-- Capture the exact frame isSplit() first turns true.
	local startX, endX = 10, 400 -- endX=400 crosses the 320 crossover separation
	local steps = 120
	local wasSplit = false
	local onsetScale1, onsetScale2
	for i = 1, steps do
		local sepX = startX + (endX - startX) * (i / steps)
		cm:update(1 / 60, { playerRect(300, 300), playerRect(300 + sepX, 300) })
		local nowSplit = cm:isSplit()
		if nowSplit and not wasSplit then
			local blend = cm:getSplitZoomBlend()
			onsetScale1 = cm:getPaneDrawParams(1, 0, 0, blend).sx
			onsetScale2 = cm:getPaneDrawParams(2, 0, 0, blend).sx
			break
		end
		wasSplit = nowSplit
	end

	assertTrue(onsetScale1 ~= nil, "the split should have triggered within the approach")
	assertNear(cm.merged.scale, onsetScale1, 0.001, "pane 1's rendered scale should equal the merged scale at onset")
	assertNear(cm.merged.scale, onsetScale2, 0.001, "pane 2's rendered scale should equal the merged scale at onset")
end)

test("a pane reused across a second split in the same level reseeds from the merged view at onset, not a stale prior scale", function()
	local cm = manager()
	cm:setPaneScreenSize(1, SCREEN_W, SCREEN_H)
	cm:setPaneScreenSize(2, SCREEN_W, SCREEN_H)

	local far = { playerRect(200, 300), playerRect(900, 300) }
	local together = { playerRect(300, 300), playerRect(310, 300) }

	-- First split: settle fully so pane 1 diverges to its own close-up
	-- position/scale, well away from the merged view.
	for _ = 1, 90 do
		cm:update(1 / 60, far)
	end
	assertTrue(cm:isSplit(), "precondition: first split is active")
	assertTrue(cm:ensurePane(1).scale > cm.merged.scale + 0.01, "precondition: pane 1 has zoomed in past the merged scale")

	-- Merge for exactly one frame -- splitState flips off immediately (a
	-- threshold, not eased) but without a fix the panes' cx/cy/scale would
	-- barely move, carrying almost all of the prior split's divergence into
	-- the very next split.
	cm:update(1 / 60, together)
	assertFalse(cm:isSplit(), "precondition: merged for one frame")

	-- Re-split immediately: this frame is the second split's onset.
	cm:update(1 / 60, far)
	assertTrue(cm:isSplit(), "precondition: split again on this frame")

	local blend = cm:getSplitZoomBlend()
	local onsetScale = cm:getPaneDrawParams(1, 0, 0, blend).sx
	assertNear(
		cm.merged.scale,
		onsetScale,
		0.001,
		"pane's rendered scale should equal the merged scale on the second onset frame, not a stale scale from the first split"
	)
end)

test("held-still panes ease their scale toward their own target rather than staying pinned to the merged scale", function()
	local cm = manager()
	cm:setPaneScreenSize(1, SCREEN_W, SCREEN_H)
	cm:setPaneScreenSize(2, SCREEN_W, SCREEN_H)

	-- Trigger a split, then hold the players perfectly still.
	local far = { playerRect(200, 300), playerRect(900, 300) }
	cm:update(1 / 60, far)
	assertTrue(cm:isSplit(), "precondition: split triggers immediately")

	local blendAtOnset = cm:getSplitZoomBlend()
	local scaleAtOnset = cm:getPaneDrawParams(1, 0, 0, blendAtOnset).sx

	for _ = 1, 90 do
		cm:update(1 / 60, far)
	end

	local blendLater = cm:getSplitZoomBlend()
	local scaleLater = cm:getPaneDrawParams(1, 0, 0, blendLater).sx

	assertTrue(
		math.abs(scaleLater - scaleAtOnset) > 0.01,
		"holding still after a split should still ease the pane toward its own zoom, not stay pinned at the onset scale"
	)
end)

test("getSplitDivergence is Euclidean: a purely vertical separation grows divergence just like a horizontal one", function()
	local cm = manager()
	cm:setPaneScreenSize(1, SCREEN_W, SCREEN_H)
	cm:setPaneScreenSize(2, SCREEN_W, SCREEN_H)

	-- Same x (no horizontal component at all); only y separates the players.
	local vertical = { playerRect(400, 100), playerRect(400, 900) }
	for _ = 1, 90 do
		cm:update(1 / 60, vertical)
	end

	assertTrue(
		cm:getSplitDivergence() > 50,
		"a purely vertical separation should still register substantial divergence, not stay near zero"
	)
end)

test("re-merging the panes converges their rendered scale back to the merged scale with no frame exceeding the easing step", function()
	local cm = manager()
	cm:setPaneScreenSize(1, SCREEN_W, SCREEN_H)
	cm:setPaneScreenSize(2, SCREEN_W, SCREEN_H)

	local far = { playerRect(200, 300), playerRect(900, 300) }
	local close = { playerRect(300, 300), playerRect(310, 300) }

	-- Settle fully split first.
	for _ = 1, 90 do
		cm:update(1 / 60, far)
	end
	assertTrue(cm:isSplit(), "precondition: split settled")

	-- Now bring the players back together and track the pane's rendered
	-- scale frame by frame while it re-merges.
	local prevScale = cm:getPaneDrawParams(1, 0, 0, cm:getSplitZoomBlend()).sx
	local maxDelta = 0
	for _ = 1, 180 do
		cm:update(1 / 60, close)
		local scale = cm:getPaneDrawParams(1, 0, 0, cm:getSplitZoomBlend()).sx
		maxDelta = math.max(maxDelta, math.abs(scale - prevScale))
		prevScale = scale
	end

	assertFalse(cm:isSplit(), "precondition: fully merged again")
	assertNear(cm.merged.scale, prevScale, 0.01, "the pane's rendered scale should converge back to the merged scale")
	assertTrue(maxDelta < 0.25, "no single frame should change the pane's rendered scale by more than the exponential ease allows")
end)

test("a pane created mid-split (a joining/respawning player) seeds from the merged scale, not the full-map seed", function()
	local cm = manager()
	cm:setPaneScreenSize(1, 400, SCREEN_H)
	cm:setPaneScreenSize(2, 400, SCREEN_H)
	local players = { playerRect(600, 500), playerRect(900, 500) }

	-- Park the merged camera away from the initial full-map view so a
	-- merged-seeded pane is distinguishable from a full-map-seeded one.
	cm.merged.cx = 400
	cm.merged.cy = 300
	cm.merged.scale = 0.8

	-- Pane 2 is created mid-split, as if the second player just joined.
	local dt = 1 / 60
	cm:updatePane(dt, 2, players)

	local initial = Camera.fullMapView(MAP_W, MAP_H, 400, SCREEN_H).scale
	local p2 = cm:getPaneDrawParams(2)
	assertNear(cm.merged.scale, p2.sx, 0.001, "a pane created mid-split should seed from the merged scale")
	assertTrue(math.abs(p2.sx - initial) > 0.1, "a mid-split pane should not seed from the full-map scale")
end)

-- ===== Continuous split/merge transition (eased compositing gate) =====

test("SPLIT_DIVERGENCE_FLOOR and SPLIT_FULL_DIVERGENCE are exposed once on CameraManager", function()
	assertEqual(4, Camera.CameraManager.SPLIT_DIVERGENCE_FLOOR)
	assertEqual(256, Camera.CameraManager.SPLIT_FULL_DIVERGENCE)
end)

test("isCompositingActive is false before any split and true once the split factor starts easing up", function()
	local cm = manager()
	assertFalse(cm:isCompositingActive(), "merged at start: nothing to composite")

	local far = { playerRect(200, 300), playerRect(900, 300) }
	cm:updateSplit(1 / 60, far)
	assertTrue(cm:isCompositingActive(), "split factor easing upward should already keep the path active")
end)

test("flipping splitState alone (with eased quantities unchanged) does not change isCompositingActive", function()
	local cm = manager()
	-- Merged, nothing eased yet: not compositing.
	assertFalse(cm.splitState, "precondition: merged")
	assertFalse(cm:isCompositingActive())

	-- Flip the raw hysteresis flag by hand, as if a single frame's threshold
	-- crossing changed it, without any eased quantity (splitFactor, pane
	-- divergence) having moved yet.
	cm.splitState = true
	assertFalse(
		cm:isCompositingActive(),
		"splitState flipping alone must not change the draw path -- only eased quantities may"
	)

	-- Conversely: splitFactor already eased up, but splitState itself is
	-- (hypothetically) back to false -- compositing must still stay active.
	cm.splitState = false
	cm.splitFactor = 0.5
	assertTrue(
		cm:isCompositingActive(),
		"a high splitFactor keeps the path active even if splitState alone reads false"
	)
end)

test("isCompositingActive stays true for every frame while the split factor or pane divergence is still above zero, through a full merge-back", function()
	local cm = manager()
	cm:setPaneScreenSize(1, SCREEN_W, SCREEN_H)
	cm:setPaneScreenSize(2, SCREEN_W, SCREEN_H)

	local far = { playerRect(200, 300), playerRect(900, 300) }
	-- Identical positions (not just "close"): guarantees pane divergence
	-- actually reaches 0, so this test can observe a genuine release rather
	-- than the panes settling apart at a small but permanent residual gap.
	local close = { playerRect(300, 300), playerRect(300, 300) }

	for _ = 1, 90 do
		cm:update(1 / 60, far)
	end
	assertTrue(cm:isSplit(), "precondition: fully split")
	assertTrue(cm:isCompositingActive(), "precondition: compositing active while split")

	local sawStillDiverged = false
	local releasedAt = nil
	for i = 1, 240 do
		cm:update(1 / 60, close)
		local stillDiverged = cm:getSplitFactor() > 0.01 or cm:getSplitZoomBlend() > 0.01
		if stillDiverged then
			sawStillDiverged = true
			assertTrue(
				cm:isCompositingActive(),
				"compositing must stay active at frame " .. i .. " while eased quantities have not converged"
			)
		elseif not releasedAt then
			releasedAt = i
		end
	end

	assertTrue(sawStillDiverged, "precondition: merge-back should take more than one frame to fully converge")
	assertTrue(releasedAt ~= nil, "compositing should eventually release once fully converged")
	assertFalse(cm:isCompositingActive(), "fully converged: compositing path should have released")
end)

test("isCompositingActive eventually releases when players merge back close together but not perfectly overlapping", function()
	local cm = manager()
	cm:setPaneScreenSize(1, SCREEN_W, SCREEN_H)
	cm:setPaneScreenSize(2, SCREEN_W, SCREEN_H)

	local far = { playerRect(200, 300), playerRect(900, 300) }
	-- Realistic "standing next to each other" separation: adjacent, not
	-- overlapping (20px player width apart), unlike the identical-position
	-- fixture above. Two real players can never be closer than this, so the
	-- compositing path must still be able to release at this separation or it
	-- never releases in actual play.
	local close = { playerRect(300, 300), playerRect(320, 300) }

	for _ = 1, 90 do
		cm:update(1 / 60, far)
	end
	assertTrue(cm:isSplit(), "precondition: fully split")

	for _ = 1, 300 do
		cm:update(1 / 60, close)
	end

	assertFalse(cm:isSplit(), "precondition: players standing next to each other should be merged")
	assertFalse(
		cm:isCompositingActive(),
		"compositing should release once players are merged and standing next to each other, "
			.. "not stay stuck active forever because pane divergence never reaches the floor"
	)
end)

test("entering overview or game-over mid-split releases the compositing path immediately, even with a high split factor", function()
	local cm = manager()
	local far = { playerRect(200, 300), playerRect(900, 300) }
	for _ = 1, 30 do
		cm:update(1 / 60, far)
	end
	assertTrue(cm:isCompositingActive(), "precondition: compositing active mid-split")
	assertTrue(cm:getSplitFactor() > 0.5, "precondition: split factor has not fully eased yet")

	cm:setMode("overview")
	assertFalse(cm:isCompositingActive(), "overview should release the compositing path immediately")

	cm:setMode("follow")
	for _ = 1, 30 do
		cm:update(1 / 60, far)
	end
	assertTrue(cm:isCompositingActive(), "precondition: compositing active again after returning to follow")

	cm:setMode("gameover")
	assertFalse(cm:isCompositingActive(), "game-over should release the compositing path immediately")
end)

test("the divergence-driven blend that drives line thickness never jumps by more than an easing-sized step across a full split-to-merge cycle", function()
	local cm = manager()
	local far = { playerRect(200, 300), playerRect(900, 300) }
	local close = { playerRect(300, 300), playerRect(300, 300) }

	local maxDelta = 0
	local prevBlend = cm:getSplitZoomBlend()
	for _ = 1, 120 do
		cm:update(1 / 60, far)
		local blend = cm:getSplitZoomBlend()
		maxDelta = math.max(maxDelta, math.abs(blend - prevBlend))
		prevBlend = blend
	end
	for _ = 1, 180 do
		cm:update(1 / 60, close)
		local blend = cm:getSplitZoomBlend()
		maxDelta = math.max(maxDelta, math.abs(blend - prevBlend))
		prevBlend = blend
	end

	assertTrue(
		maxDelta < 0.2,
		"line-thickness-driving blend should never jump more than an easing-sized step in one frame (max delta "
			.. maxDelta
			.. ")"
	)
end)

test("rapid oscillation across the split trigger for 200 frames never jumps the line-thickness blend from zero to full or back", function()
	local cm = manager()
	local below = { playerRect(300, 300), playerRect(520, 300) } -- dead band (scale 1.28)
	local above = { playerRect(300, 300), playerRect(550, 300) } -- triggers split (scale 1.22)

	local prevBlend = cm:getSplitZoomBlend()
	for i = 1, 200 do
		local targets = (i % 2 == 0) and below or above
		cm:update(1 / 60, targets)
		local blend = cm:getSplitZoomBlend()
		assertTrue(
			math.abs(blend - prevBlend) < 0.2,
			"line-thickness blend jumped sharply at frame " .. i .. " (from " .. prevBlend .. " to " .. blend .. ")"
		)
		prevBlend = blend
	end
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
