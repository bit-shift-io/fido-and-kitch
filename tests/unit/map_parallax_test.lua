-- Pure math for background-layer parallax offsets. Pulled out of src/map.lua
-- so it can be unit tested without lib.sti/love.graphics -- see
-- src/map_parallax.lua for the derivation.
local parallax = require('src.map_parallax')

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

test('camera centre round-trips through computeCameraCenter regardless of zoom', function()
	local cx, cy = 1234, 567

	for _, scale in ipairs({0.5, 1, 2, 3.7}) do
		local tx, ty, sx, sy = drawParamsFor(cx, cy, scale)
		local gotCx, gotCy = parallax.computeCameraCenter(tx, ty, sx, sy, SCREEN_W, SCREEN_H)
		assertNear(cx, gotCx, 0.001, 'camera centre x should round-trip at scale ' .. scale)
		assertNear(cy, gotCy, 0.001, 'camera centre y should round-trip at scale ' .. scale)
	end
end)

test('changing zoom alone does not change a background layer draw offset', function()
	local cx, cy = 1234, 567
	local parallaxx, parallaxy = 0.5, 0.5

	local offsets = {}
	for _, scale in ipairs({0.5, 1, 2, 3.7}) do
		local tx, ty, sx, sy = drawParamsFor(cx, cy, scale)
		local ccx, ccy = parallax.computeCameraCenter(tx, ty, sx, sy, SCREEN_W, SCREEN_H)
		local px, py = parallax.computeLayerOffset(ccx, ccy, parallaxx, parallaxy, 0, 0)
		table.insert(offsets, {px, py})
	end

	for i = 2, #offsets do
		assertEqual(offsets[1][1], offsets[i][1], 'px should be zoom-invariant for a fixed camera centre')
		assertEqual(offsets[1][2], offsets[i][2], 'py should be zoom-invariant for a fixed camera centre')
	end
end)

test('panning the camera shifts a parallax layer offset by (1 - parallax) * delta', function()
	local scale = 1.5
	local parallaxx, parallaxy = 0.25, 0.25

	local tx1, ty1, sx1, sy1 = drawParamsFor(1000, 500, scale)
	local cx1, cy1 = parallax.computeCameraCenter(tx1, ty1, sx1, sy1, SCREEN_W, SCREEN_H)
	local px1, py1 = parallax.computeLayerOffset(cx1, cy1, parallaxx, parallaxy, 0, 0)

	local tx2, ty2, sx2, sy2 = drawParamsFor(1400, 620, scale)
	local cx2, cy2 = parallax.computeCameraCenter(tx2, ty2, sx2, sy2, SCREEN_W, SCREEN_H)
	local px2, py2 = parallax.computeLayerOffset(cx2, cy2, parallaxx, parallaxy, 0, 0)

	local expectedDx = (1 - parallaxx) * (1400 - 1000)
	local expectedDy = (1 - parallaxy) * (620 - 500)
	assertNear(expectedDx, px2 - px1, 0.001, 'px delta should scale by (1 - parallaxx)')
	assertNear(expectedDy, py2 - py1, 0.001, 'py delta should scale by (1 - parallaxy)')
end)

test('a parallax of 1 (matches the main map) never shifts beyond its authored offset', function()
	for _, scale in ipairs({0.5, 1, 2}) do
		for _, cx in ipairs({0, 500, -300}) do
			local tx, ty, sx, sy = drawParamsFor(cx, 0, scale)
			local ccx, _ = parallax.computeCameraCenter(tx, ty, sx, sy, SCREEN_W, SCREEN_H)
			local px, _ = parallax.computeLayerOffset(ccx, 0, 1, 1, 42, 0)
			assertEqual(42, px, 'parallax=1 layer should sit exactly at its authored offsetx')
		end
	end
end)

test('a parallax of 0 (fixed background) tracks the camera centre one-to-one', function()
	local tx, ty, sx, sy = drawParamsFor(777, 333, 2)
	local cx, cy = parallax.computeCameraCenter(tx, ty, sx, sy, SCREEN_W, SCREEN_H)
	local px, py = parallax.computeLayerOffset(cx, cy, 0, 0, 10, 20)

	assertNear(777 + 10, px, 0.001, 'parallax=0 layer offset should equal camera centre plus authored offsetx')
	assertNear(333 + 20, py, 0.001, 'parallax=0 layer offset should equal camera centre plus authored offsety')
end)
