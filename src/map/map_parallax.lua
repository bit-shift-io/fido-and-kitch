-- Pure math for background-layer parallax. No love/sti dependency so it can
-- be unit tested headlessly; see tests/unit/map_parallax_test.lua.
--
-- Map:draw2 draws everything (main layers + background) onto a map-sized
-- canvas at world scale 1, then that whole canvas is translated by
-- (tx, ty) and scaled by (sx, sy) once at presentation time -- so anything
-- drawn onto the canvas already gets panned/zoomed uniformly for free.
-- A parallax layer needs an *extra* canvas-space shift so that, after that
-- uniform transform, it appears to move at `parallax` times the rate of the
-- main map as the camera pans.
--
-- Background layers are zoom-coupled: the image is scaled relative to the
-- camera zoom so it always covers the whole projected world rect, never just
-- the screen. Each layer anchors to world-center and slides proportionally
-- to the smoothed camera center, clamped so a texture edge can never show
-- inside the world.
--
-- Camera:getDrawParams() produces tx = screenW/2 - cx*scale (and ty
-- likewise), so the world camera centre (cx, cy) can be recovered from
-- (tx, ty, sx, sy, screenW, screenH) regardless of the current zoom.
local M = {}

-- Two shared presets (one place, no per-map values). allowance is lerped
-- between them by zoomT: at full-map zoom-out the image is scaled to 110% of
-- world-cover (max slide ~±5% of world for p=1), at closest zoom 130% (±15%).
M.ZOOMED_OUT_ALLOWANCE = 0.10
M.ZOOMED_IN_ALLOWANCE = 0.30

function M.computeCameraCenter(tx, ty, sx, sy, screenW, screenH)
	local cx = (screenW / 2 - tx) / sx
	local cy = (screenH / 2 - ty) / sy
	return cx, cy
end

-- Camera scale normalized between the full-map view (0) and the closest view
-- (1, currently minViewTiles = 6), clamped to [0, 1].
function M.computeZoomT(scale, fullMapScale, closestScale)
	local zoomT = (scale - fullMapScale) / (closestScale - fullMapScale)
	if zoomT < 0 then return 0 end
	if zoomT > 1 then return 1 end
	return zoomT
end

-- Linear lerp between the two shared allowance presets.
function M.computeAllowance(zoomT)
	return M.ZOOMED_OUT_ALLOWANCE + (M.ZOOMED_IN_ALLOWANCE - M.ZOOMED_OUT_ALLOWANCE) * zoomT
end

-- Cover factor (world units) that makes an image always fill the whole map:
-- scale the image by this (then by cameraScale) to guarantee at least
-- `allowance` slack on each axis.
function M.computeCover(mapW, mapH, imgW, imgH)
	return math.max(mapW / imgW, mapH / imgH)
end

-- Proportional slide in world units: how far the layer center moves off
-- world-center, per axis, given the reference position in world units.
-- p=0 pins the layer to world-center; extremes are `center` at the map edges.
function M.computeSlide(allowance, parallax, center, mapSize)
	return allowance * parallax * (center - mapSize * 0.5)
end

-- Union-bounds midpoint (per axis, world units) of a list of rects
-- ({x, y, w, h}, e.g. InGameState:collectPlayerTargets()). Returns nil when
-- no rects are supplied so callers can fall back to the recovered camera
-- center. Mirrors Camera.computeFraming's unionBounds: at the zoomed-out
-- view the camera center is pinned to map-center (viewW > mapW clamps
-- viewX), which would zero the slide -- the players' own positions are the
-- reference that keeps parallax alive at any zoom.
function M.computePlayersCenter(targets)
	local minX, minY, maxX, maxY
	for _, t in ipairs(targets or {}) do
		local x1, y1 = t.x, t.y
		local x2, y2 = t.x + (t.w or 0), t.y + (t.h or 0)
		if not minX or x1 < minX then minX = x1 end
		if not minY or y1 < minY then minY = y1 end
		if not maxX or x2 > maxX then maxX = x2 end
		if not maxY or y2 > maxY then maxY = y2 end
	end
	if not minX then return nil end
	return (minX + maxX) / 2, (minY + maxY) / 2
end

return M
