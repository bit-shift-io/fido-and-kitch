-- Pure math for zoom-coupled background-layer parallax. Pulled out of
-- src/map.lua so it can be unit tested without lib.sti/love.graphics -- see
-- src/map_parallax.lua for the derivation.
--
-- Background layers are zoom-coupled: each layer anchors to world-center and
-- slides proportionally to the recovered camera center (the proportional
-- slide), clamped so its drawn rect always contains the projected world rect
-- (cover-guarantees-coverage). Authored offsetx/offsety are discarded.
local parallax = require("src.map.map_parallax")

local SCREEN_W = 800
local SCREEN_H = 600

-- Camera:getDrawParams() produces tx,ty of exactly this shape (screenW/2 -
-- cx*scale), so this recreates what Map:draw2 receives for a given world
-- camera centre and zoom.
local function drawParamsFor(cx, cy, scale)
	local tx = SCREEN_W / 2 - cx * scale
	local ty = SCREEN_H / 2 - cy * scale
	return tx, ty, scale, scale
end

test("camera centre round-trips through computeCameraCenter regardless of zoom", function()
	local cx, cy = 1234, 567

	for _, scale in ipairs({ 0.5, 1, 2, 3.7 }) do
		local tx, ty, sx, sy = drawParamsFor(cx, cy, scale)
		local gotCx, gotCy = parallax.computeCameraCenter(tx, ty, sx, sy, SCREEN_W, SCREEN_H)
		assertNear(cx, gotCx, 0.001, "camera centre x should round-trip at scale " .. scale)
		assertNear(cy, gotCy, 0.001, "camera centre y should round-trip at scale " .. scale)
	end
end)

test("pane-local camera centre round-trips with the pane's own size (split-screen scoping)", function()
	-- A split-screen pane uses pane-LOCAL draw params (screen size = pane w/h,
	-- tx/ty relative to the pane origin); computeCameraCenter must recover the
	-- same world centre from those pane-local values so per-pane parallax slides
	-- against the correct reference.
	local paneW, paneH = 400, 600
	local cx, cy = 1234, 567

	for _, scale in ipairs({ 0.5, 1, 2 }) do
		local tx = paneW / 2 - cx * scale
		local ty = paneH / 2 - cy * scale
		local gotCx, gotCy = parallax.computeCameraCenter(tx, ty, scale, scale, paneW, paneH)
		assertNear(cx, gotCx, 0.001, "pane-local centre x should round-trip at scale " .. scale)
		assertNear(cy, gotCy, 0.001, "pane-local centre y should round-trip at scale " .. scale)
	end
end)

test("proportional slide: p=1 hits -allowance*mapSize/2 at map-left and +allowance*mapSize/2 at map-right", function()
	local mapW, mapH = 2048, 1536
	local allowance = 0.2

	local leftX = parallax.computeSlide(allowance, 1, 0, mapW)
	local rightX = parallax.computeSlide(allowance, 1, mapW, mapW)
	assertNear(-allowance * mapW * 0.5, leftX, 0.001, "p=1 at map-left should slide by -allowance*mapW/2")
	assertNear(allowance * mapW * 0.5, rightX, 0.001, "p=1 at map-right should slide by +allowance*mapW/2")

	local leftY = parallax.computeSlide(allowance, 1, 0, mapH)
	local rightY = parallax.computeSlide(allowance, 1, mapH, mapH)
	assertNear(-allowance * mapH * 0.5, leftY, 0.001, "p=1 at map-top should slide by -allowance*mapH/2")
	assertNear(allowance * mapH * 0.5, rightY, 0.001, "p=1 at map-bottom should slide by +allowance*mapH/2")
end)

test("proportional slide: p=0 is pinned to world-center", function()
	local mapW, mapH = 2048, 1536
	local allowance = 0.2

	local px, py = parallax.computeSlide(allowance, 0, 512, mapW), parallax.computeSlide(allowance, 0, 768, mapH)
	assertNear(0, px, 0.001, "p=0 should never slide on x")
	assertNear(0, py, 0.001, "p=0 should never slide on y")
end)

test("proportional slide: per-axis independence", function()
	local mapW, mapH = 2048, 1536
	local allowance = 0.2
	local centerX, centerY = 2048, 0

	local slideX, slideY =
		parallax.computeSlide(allowance, 1, centerX, mapW), parallax.computeSlide(allowance, 0.25, centerY, mapH)
	assertNear(allowance * mapW * 0.5, slideX, 0.001, "x axis slides with its own parallaxx")
	assertNear(-allowance * 0.25 * mapH * 0.5, slideY, 0.001, "y axis slides with its own parallaxy")
end)

test("computePlayersCenter returns nil with no targets", function()
	local cx, cy = parallax.computePlayersCenter()
	assertTrue(cx == nil and cy == nil, "no targets should yield nil center")
	assertTrue(parallax.computePlayersCenter({}) == nil, "empty target list should yield nil")
end)

test("computePlayersCenter midpoints the union of player rects", function()
	local cx, cy = parallax.computePlayersCenter({ { x = 100, y = 200, w = 40, h = 60 } })
	assertNear(120, cx, 0.001, "single rect center x")
	assertNear(230, cy, 0.001, "single rect center y")

	local cx2, cy2 = parallax.computePlayersCenter({
		{ x = 100, y = 200, w = 40, h = 60 },
		{ x = 1500, y = 800, w = 40, h = 60 },
	})
	assertNear(820, cx2, 0.001, "union midpoint x should average the outer extents")
	assertNear(530, cy2, 0.001, "union midpoint y should average the outer extents")
end)

test("computePlayersCenter keeps slide nonzero at the zoomed-out extremes", function()
	local mapW, mapH = 2048, 1536
	local allowance = 0.2

	-- Both players on the far-left of the map: union midpoint at map-left,
	-- so the slide reaches its full -allowance*mapSize/2 extreme even though
	-- the zoomed-out camera center would be pinned to map-center. Zero-extent
	-- rects hit the exact map edge (a real body lands a body-width in).
	local leftX, _ = parallax.computePlayersCenter({ { x = 0, y = 0, w = 0, h = 0 } })
	local slideLeft = parallax.computeSlide(allowance, 1, leftX, mapW)
	assertNear(-allowance * mapW * 0.5, slideLeft, 0.001, "p=1 players at map-left should slide by -allowance*mapW/2")

	local rightX, _ = parallax.computePlayersCenter({ { x = mapW, y = 0, w = 0, h = 0 } })
	local slideRight = parallax.computeSlide(allowance, 1, rightX, mapW)
	assertNear(allowance * mapW * 0.5, slideRight, 0.001, "p=1 players at map-right should slide by +allowance*mapW/2")
end)

test("computeZoomT normalizes between full-map and closest scales and clamps at both ends", function()
	local fullMapScale, closestScale = 0.25, 2.5

	assertNear(
		0,
		parallax.computeZoomT(fullMapScale, fullMapScale, closestScale),
		0.001,
		"zoomT should be 0 at the full-map view"
	)
	assertNear(
		1,
		parallax.computeZoomT(closestScale, fullMapScale, closestScale),
		0.001,
		"zoomT should be 1 at the closest view"
	)
	assertNear(
		0.5,
		parallax.computeZoomT((fullMapScale + closestScale) * 0.5, fullMapScale, closestScale),
		0.001,
		"zoomT should lerp linearly between the reference scales"
	)

	assertNear(
		0,
		parallax.computeZoomT(fullMapScale - 1, fullMapScale, closestScale),
		0.001,
		"zoomT should clamp to 0 below the full-map view"
	)
	assertNear(
		1,
		parallax.computeZoomT(closestScale + 10, fullMapScale, closestScale),
		0.001,
		"zoomT should clamp to 1 above the closest view"
	)
end)

test("computeAllowance lerps between the shared presets", function()
	assertNear(
		parallax.ZOOMED_OUT_ALLOWANCE,
		parallax.computeAllowance(0),
		0.001,
		"allowance at zoom-out should be the zoomed-out preset"
	)
	assertNear(0.20, parallax.computeAllowance(0.5), 0.001, "allowance at zoomT=0.5 should be the midpoint")
	assertNear(
		parallax.ZOOMED_IN_ALLOWANCE,
		parallax.computeAllowance(1),
		0.001,
		"allowance at zoom-in should be the zoomed-in preset"
	)
end)

test("cover-guarantees-coverage: drawn rect contains the world rect for all zooms and aspects", function()
	local mapW, mapH = 2048, 1536
	local screenW, screenH = SCREEN_W, SCREEN_H
	local tileSize = 32
	local minViewTiles = 6

	local fullMapScale = math.min(screenW / mapW, screenH / mapH)
	local closestScale = math.min(screenW / (minViewTiles * tileSize), screenH / (minViewTiles * tileSize))

	local aspects = {
		{ 1920, 1080 },
		{ 800, 800 },
		{ 4096, 1024 },
		{ 512, 4096 },
		{ 2048, 2048 },
		{ 64, 64 },
	}
	local scales = {
		fullMapScale * 0.5,
		fullMapScale,
		(fullMapScale + closestScale) * 0.25,
		(fullMapScale + closestScale) * 0.5,
		(fullMapScale + closestScale) * 0.75,
		closestScale,
		closestScale * 1.5,
	}
	local parallaxes = { 0, 0.5, 1 }
	local centersX = { 0, mapW * 0.5, mapW }
	local centersY = { 0, mapH * 0.5, mapH }

	for _, aspect in ipairs(aspects) do
		local imgW, imgH = aspect[1], aspect[2]
		for _, scale in ipairs(scales) do
			local zoomT = parallax.computeZoomT(scale, fullMapScale, closestScale)
			local allowance = parallax.computeAllowance(zoomT)
			local cover = parallax.computeCover(mapW, mapH, imgW, imgH)
			local s = (1 + allowance) * cover * scale
			local drawW, drawH = imgW * s, imgH * s
			local worldW, worldH = mapW * scale, mapH * scale

			for _, p in ipairs(parallaxes) do
				for _, cx in ipairs(centersX) do
					for _, cy in ipairs(centersY) do
						local slideX = allowance * p * (cx - mapW * 0.5) * scale
						local slideY = allowance * p * (cy - mapH * 0.5) * scale
						local slackX = (drawW - worldW) * 0.5
						local slackY = (drawH - worldH) * 0.5

						-- EPS absorbs float roundoff: the p=1, camera-at-map-edge
						-- case has slide == slack exactly, which either float
						-- path may land a hair below zero on.
						local EPS = 1e-6
						assertTrue(
							slackX + EPS >= math.abs(slideX),
							string.format(
								"x slack %.6f < slide %.6f (img %dx%d scale %.3f p %.1f cx %d)",
								slackX,
								slideX,
								imgW,
								imgH,
								scale,
								p,
								cx
							)
						)
						assertTrue(
							slackY + EPS >= math.abs(slideY),
							string.format(
								"y slack %.6f < slide %.6f (img %dx%d scale %.3f p %.1f cy %d)",
								slackY,
								slideY,
								imgW,
								imgH,
								scale,
								p,
								cy
							)
						)
					end
				end
			end
		end
	end
end)
