-- Pure math for background-layer parallax. No love/sti dependency so it can
-- be unit tested headlessly; see tests/unit/map_parallax_test.lua.
--
-- Map:draw2 draws everything (main layers + background) onto a map-sized
-- canvas at world scale 1, then that whole canvas is translated by
-- (tx, ty) and scaled by (sx, sy) once at presentation time -- so anything
-- drawn onto the canvas already gets panned/zoomed uniformly for free.
-- A parallax layer needs an *extra* canvas-space shift so that, after that
-- uniform transform, it appears to move at `parallax` times the rate of the
-- main map as the camera pans, while zoom (which the uniform transform
-- already applies to everything) must not touch this shift at all.
--
-- Camera:getDrawParams() produces tx = screenW/2 - cx*scale (and ty
-- likewise), so the world camera centre (cx, cy) can be recovered from
-- (tx, ty, sx, sy, screenW, screenH) regardless of the current zoom.
local M = {}

function M.computeCameraCenter(tx, ty, sx, sy, screenW, screenH)
	local cx = (screenW / 2 - tx) / sx
	local cy = (screenH / 2 - ty) / sy
	return cx, cy
end

-- Derived so that a layer's on-screen displacement per unit of camera pan is
-- exactly `parallax` times the main map's: parallax=1 sits at its authored
-- offset and moves with the map; parallax=0 tracks the camera one-to-one
-- (reads as a fixed, infinitely-distant background); values in between
-- interpolate.
function M.computeLayerOffset(cx, cy, parallaxx, parallaxy, offsetx, offsety)
	local px = math.floor((1 - parallaxx) * cx) + (offsetx or 0)
	local py = math.floor((1 - parallaxy) * cy) + (offsety or 0)
	return px, py
end

return M
