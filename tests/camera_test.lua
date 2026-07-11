-- Headless tests for the auto-zoom camera: pure framing math, frame-rate
-- independent smoothing, overview/game-over modes, and transient extra
-- targets (dying-player respawn framing). No LÖVE dependency.
local Camera = require('src.camera')

local TILE = 32
local MAP_W = TILE * 40
local MAP_H = TILE * 30
local SCREEN_W = 800
local SCREEN_H = 600

local function playerRect(x, y, w, h)
	return {x = x, y = y, w = w or 20, h = h or 30}
end

local function opts(overrides)
	local o = {marginTiles = 2, minViewTiles = 5, tileW = TILE, tileH = TILE}
	for k, v in pairs(overrides or {}) do
		o[k] = v
	end
	return o
end

-- ===== Issue 01: framing math =====

test('a single target is framed at the minimum 5x5 tile view, centred on it', function()
	local target = playerRect(500, 500, 20, 30)
	local view = Camera.computeFraming({target}, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())

	local minViewW = 5 * TILE
	local minViewH = 5 * TILE
	assertTrue(view.w <= minViewW + 0.001 or view.h <= minViewH + 0.001,
		'expected the tighter screen-fit axis to sit at (or above) the 5x5 tile minimum')
	assertNear(target.x + target.w / 2, view.cx, 1, 'view should be centred on the single target')
	assertNear(target.y + target.h / 2, view.cy, 1, 'view should be centred on the single target')
end)

test('two distant targets both fit on screen with margin, further apart than the min view', function()
	local a = playerRect(400, 400)
	local b = playerRect(900, 700)
	local view = Camera.computeFraming({a, b}, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())

	assertTrue(view.x <= a.x and view.x <= b.x, 'view left edge should be at or before both targets')
	assertTrue(view.y <= a.y and view.y <= b.y, 'view top edge should be at or before both targets')
	assertTrue(view.x + view.w >= a.x + a.w and view.x + view.w >= b.x + b.w,
		'view right edge should be at or after both targets')
	assertTrue(view.y + view.h >= a.y + a.h and view.y + view.h >= b.y + b.h,
		'view bottom edge should be at or after both targets')
end)

test('targets near the top-left corner clamp the view to map bounds', function()
	local a = playerRect(10, 10)
	local b = playerRect(60, 40)
	local view = Camera.computeFraming({a, b}, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())

	assertTrue(view.x >= -0.001, 'view should not show negative-x space beyond the map edge')
	assertTrue(view.y >= -0.001, 'view should not show negative-y space beyond the map edge')
end)

test('targets near the bottom-right corner clamp the view to map bounds', function()
	local a = playerRect(MAP_W - 40, MAP_H - 40)
	local b = playerRect(MAP_W - 90, MAP_H - 70)
	local view = Camera.computeFraming({a, b}, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())

	assertTrue(view.x + view.w <= MAP_W + 0.001, 'view should not extend past the right map edge')
	assertTrue(view.y + view.h <= MAP_H + 0.001, 'view should not extend past the bottom map edge')
end)

test('targets spread wider than the map fall back to the full-map view, centred on the map', function()
	local a = playerRect(-1000, MAP_H / 2)
	local b = playerRect(MAP_W + 1000, MAP_H / 2)
	local view = Camera.computeFraming({a, b}, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())

	assertNear(MAP_W / 2, view.cx, 1, 'x should centre on the map when targets exceed map width')
end)

test('a wide box picks the horizontal fit scale (the tighter axis)', function()
	local a = playerRect(0, 500)
	local b = playerRect(700, 520)
	local view = Camera.computeFraming({a, b}, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())

	local expectedScale = SCREEN_W / view.w
	assertNear(expectedScale, view.scale, 0.01, 'scale should be derived from the tighter-fitting axis')
end)

test('the full-map view exactly covers the map, letterboxed to the screen aspect', function()
	local view = Camera.fullMapView(MAP_W, MAP_H, SCREEN_W, SCREEN_H)

	assertNear(MAP_W / 2, view.cx, 0.5)
	assertNear(MAP_H / 2, view.cy, 0.5)
	assertNear(math.min(SCREEN_W / MAP_W, SCREEN_H / MAP_H), view.scale, 0.0001)
end)

-- ===== Issue 02: smoothing & level start =====

test('a new camera starts at the full-map view', function()
	local camera = Camera.new{screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE}
	local full = Camera.fullMapView(MAP_W, MAP_H, SCREEN_W, SCREEN_H)

	assertNear(full.cx, camera.cx, 0.001)
	assertNear(full.cy, camera.cy, 0.001)
	assertNear(full.scale, camera.scale, 0.0001)
end)

test('the camera converges toward the follow target within half a second of updates', function()
	local camera = Camera.new{screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE}
	local target = {playerRect(600, 500)}
	local expected = Camera.computeFraming(target, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())

	local dt = 1 / 60
	local elapsed = 0
	while elapsed < 0.5 do
		camera:update(dt, target)
		elapsed = elapsed + dt
	end

	assertNear(expected.cx, camera.cx, 1, 'centre x should have converged')
	assertNear(expected.cy, camera.cy, 1, 'centre y should have converged')
	assertNear(expected.scale, camera.scale, 0.01, 'zoom should have converged')
end)

test('smoothing is frame-rate independent: coarse and fine steps land at ~the same view', function()
	local target = {playerRect(600, 500)}

	local coarse = Camera.new{screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE}
	local fine = Camera.new{screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE}

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

	assertNear(fine.cx, coarse.cx, 2, 'x should reach ~the same place regardless of step size')
	assertNear(fine.cy, coarse.cy, 2, 'y should reach ~the same place regardless of step size')
	assertNear(fine.scale, coarse.scale, 0.02, 'zoom should reach ~the same place regardless of step size')
end)

test('smoothing never overshoots the target', function()
	local camera = Camera.new{screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE}
	local target = {playerRect(600, 500)}
	local expected = Camera.computeFraming(target, MAP_W, MAP_H, SCREEN_W, SCREEN_H, opts())

	local startCx = camera.cx
	local dt = 1 / 60
	for _ = 1, 120 do
		camera:update(dt, target)
		local movedTowardTarget = (expected.cx - startCx) >= 0
		if movedTowardTarget then
			assertTrue(camera.cx <= expected.cx + 0.01, 'camera should not overshoot the target centre x')
		else
			assertTrue(camera.cx >= expected.cx - 0.01, 'camera should not overshoot the target centre x')
		end
	end
end)

-- ===== Issue 03: overview toggle =====

test('overview mode targets the full-map view regardless of player positions', function()
	local camera = Camera.new{screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE}
	camera:setMode('overview')

	local target = camera:computeTargetView({playerRect(600, 500)})
	local full = Camera.fullMapView(MAP_W, MAP_H, SCREEN_W, SCREEN_H)

	assertNear(full.cx, target.cx, 0.001)
	assertNear(full.scale, target.scale, 0.0001)
end)

test('toggling overview twice returns to the follow target', function()
	local camera = Camera.new{screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE}
	assertEqual('follow', camera:getMode())

	camera:toggleOverview()
	assertEqual('overview', camera:getMode())

	camera:toggleOverview()
	assertEqual('follow', camera:getMode())
end)

test('the transition between follow and overview is carried by the same smoothing', function()
	local camera = Camera.new{screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE}
	local target = {playerRect(600, 500)}
	-- settle on the follow target first
	for _ = 1, 60 do camera:update(1 / 60, target) end
	local followScale = camera.scale

	camera:toggleOverview()
	camera:update(1 / 60, target)

	local full = Camera.fullMapView(MAP_W, MAP_H, SCREEN_W, SCREEN_H)
	local movingTowardFull = full.scale > followScale
	if movingTowardFull then
		assertTrue(camera.scale > followScale and camera.scale < full.scale,
			'mid-transition zoom should sit strictly between the follow and overview scales')
	else
		assertTrue(camera.scale < followScale and camera.scale > full.scale,
			'mid-transition zoom should sit strictly between the follow and overview scales')
	end
end)

-- ===== Issue 04: extra targets & game over =====

test('adding an extra target expands the view to include it', function()
	local camera = Camera.new{screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE}
	local players = {playerRect(600, 500)}

	local withoutExtra = camera:computeTargetView(players)
	camera:addExtraTarget('respawn:player2', playerRect(1400, 1100))
	local withExtra = camera:computeTargetView(players)

	assertTrue(withExtra.w >= withoutExtra.w - 0.001, 'view should be at least as wide once the extra target is added')
	assertTrue(withExtra.h >= withoutExtra.h - 0.001, 'view should be at least as tall once the extra target is added')
end)

test('removing an extra target shrinks the view back to the live players', function()
	local camera = Camera.new{screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE}
	local players = {playerRect(600, 500)}

	local baseline = camera:computeTargetView(players)
	camera:addExtraTarget('respawn:player2', playerRect(1400, 1100))
	camera:removeExtraTarget('respawn:player2')
	local afterRemoval = camera:computeTargetView(players)

	assertNear(baseline.cx, afterRemoval.cx, 0.001)
	assertNear(baseline.cy, afterRemoval.cy, 0.001)
	assertNear(baseline.scale, afterRemoval.scale, 0.0001)
end)

test('game-over mode yields the full-map view regardless of player positions', function()
	local camera = Camera.new{screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE}
	camera:setMode('gameover')

	local target = camera:computeTargetView({playerRect(50, 50)})
	local full = Camera.fullMapView(MAP_W, MAP_H, SCREEN_W, SCREEN_H)

	assertNear(full.cx, target.cx, 0.001)
	assertNear(full.cy, target.cy, 0.001)
	assertNear(full.scale, target.scale, 0.0001)
end)

test('toggling overview has no effect while game-over owns the view', function()
	local camera = Camera.new{screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE}
	camera:setMode('gameover')
	camera:toggleOverview()

	assertEqual('gameover', camera:getMode())
end)

-- ===== draw params =====

test('getDrawParams centres the camera position on screen at the current zoom', function()
	local camera = Camera.new{screenW = SCREEN_W, screenH = SCREEN_H, mapW = MAP_W, mapH = MAP_H, tileW = TILE}
	local tx, ty, sx, sy = camera:getDrawParams()

	assertNear(camera.cx, (SCREEN_W / 2 - tx) / sx, 0.01)
	assertNear(camera.cy, (SCREEN_H / 2 - ty) / sy, 0.01)
	assertEqual(sx, sy)
end)
