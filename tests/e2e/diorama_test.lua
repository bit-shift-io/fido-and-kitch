-- The Diorama world-edge frame & void fill under real rendering. Geometry is
-- covered headless in tests/unit/diorama_test.lua; what only a real window
-- can give is proof that the draw pipeline renders the right thing at the
-- right pixels: the tiling void fills the out-of-world strips and the
-- world-space frame sits centred on the world boundary.
--
-- Runs against res/map/sandbox.tmj (20x20 tiles = 640x640px) at a wide
-- 1200x500 window so the camera's view is wider than the map and the screen
-- has left/right void strips. The camera is forced to the deterministic
-- full-map overview so the projected world rect is exact:
-- scale = min(1200/640, 500/640) = 0.78125, tx = 600 - 320*0.78125 = 350,
-- ty = 0, world rect = {350, 0, 500, 500}, void strips = left {0,0,350,500}
-- and right {850,0,350,500}.
--
-- Frame/tile/void art does not exist yet, so every Diorama config path is
-- pre-seeded in AssetManager.textures with a solid-colour placeholder and the
-- test asserts on those exact colours.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Capture = require('tests.support.capture')
local AssetManager = require('src.utils.asset_manager')
local Diorama = require('src.diorama')
local Camera = require('src.camera')

local MAP = 'res/map/sandbox.tmj'

local COLORS = {
	void = { 255, 255, 255 },
	horizontal = { 255, 0, 0 },
	vertical = { 0, 255, 0 },
	corner = { 255, 0, 255 },
	ornament = { 0, 255, 255 },
}

-- Build a solid-colour placeholder image so geometry is verifiable before
-- real art lands. Texture-less in the sense that it's a bare ImageData
-- wrapped in a love Image, not a file on disk.
local function makePlaceholder(r, g, b)
	local id = love.image.newImageData(32, 32)
	for y = 0, 31 do
		for x = 0, 31 do
			id:setPixel(x, y, r, g, b, 255)
		end
	end
	return love.graphics.newImage(id)
end

local function seedPlaceholders()
	local c = COLORS
	AssetManager.textures[Diorama.config.void.img] = makePlaceholder(c.void[1], c.void[2], c.void[3])

	-- Top/bottom share one horizontal tile texture and left/right share one
	-- vertical tile texture, so seed by unique path (a per-side seed would
	-- silently overwrite the shared entry).
	local f = Diorama.config.frame
	local seeded = {}
	for _, side in ipairs({ 'top', 'bottom', 'left', 'right' }) do
		local path = f.tiles[side]
		if not seeded[path] then
			seeded[path] = true
			local color = (side == 'top' or side == 'bottom') and c.horizontal or c.vertical
			AssetManager.textures[path] = makePlaceholder(color[1], color[2], color[3])
		end
	end

	for _, key in ipairs({ 'topLeft', 'topRight', 'bottomLeft', 'bottomRight' }) do
		AssetManager.textures[f.ornaments.corners[key].img] = makePlaceholder(c.corner[1], c.corner[2], c.corner[3])
	end

	for side, orn in pairs(f.ornaments) do
		if side ~= 'corners' then
			for _, item in ipairs(orn) do
				AssetManager.textures[item.img] = makePlaceholder(c.ornament[1], c.ornament[2], c.ornament[3])
			end
		end
	end
end

local function renderToCanvas(game)
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	local canvas = love.graphics.newCanvas(w, h)
	love.graphics.push('all')
	love.graphics.setCanvas(canvas)
	love.graphics.clear()
	game:draw()
	love.graphics.setCanvas()
	love.graphics.pop()
	return canvas
end

-- ImageData:getPixel returns 0-1 floats; bring them back to the 0-255 space
-- the COLORS table is written in.
local function pixelAt(canvas, px, py)
	local r, g, b = canvas:newImageData():getPixel(px, py)
	return { math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5) }
end

local function sameColor(a, b)
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

-- World->screen using the same floored transform drawMainLayers/drawFrame use.
local function worldToScreen(wx, wy, tx, ty, sx, sy)
	return math.floor(tx) + wx * sx, math.floor(ty) + wy * sy
end

test('the void fills the out-of-world strips and the frame sits on the world boundary', function()
	love.window.setMode(1200, 500)

	local game = GameHarness.startGame(MAP, {real = true})
	seedPlaceholders()

	local mapW, mapH = map:getPixelSize()
	local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
	assertEqual(1200, screenW, 'expected the wide test window')
	assertEqual(500, screenH, 'expected the short test window')
	assertEqual(640, mapW, 'sandbox is 20x20 tiles of 32px')
	assertEqual(640, mapH)

	-- Force the deterministic full-map overview (exact geometry, no easing).
	-- The game camera opts into a 16px void gutter around every map edge
	-- (InGameState) that would spread the projected rect past the map on all
	-- four sides and turn the two wide-screen strips into four. This test is
	-- about the diorama pipeline under a known projection, so pin the padding
	-- off to keep the writer/reader math in this file exact.
	local cam = game.fsm.currentState.camera
	cam.padding = 0
	local full = Camera.fullMapView(mapW, mapH, screenW, screenH)
	cam.cx, cam.cy, cam.scale = full.cx, full.cy, full.scale
	cam:setMode('overview')

	FrameStepper.step(game, 30) -- settle the world/players after the resize

	-- Recover the projected world rect exactly as Diorama sees it.
	local vr = cam:getDrawParams()
	local tx, ty, sx, sy = vr.tx, vr.ty, vr.sx, vr.sy
	local internal = Diorama._internal
	local wr = internal.worldScreenRect(vr.tx, vr.ty, vr.sx, vr.sy, mapW, mapH)
	local rects = internal.computeVoidRects(screenW, screenH, wr)

	assertEqual(2, #rects, 'a wide screen over a 1:1 map yields left and right void strips')
	assertTrue(rects[1].w > 0 and rects[2].w > 0, 'both void strips must be non-zero')

	-- The void strips must be free of any map/world content: pure void colour.
	local canvas = renderToCanvas(game)
	Capture.capture('01_void_and_frame')

	local voidLeft = pixelAt(canvas, math.floor(rects[1].x + rects[1].w / 2), math.floor(rects[1].y + rects[1].h / 2))
	assertTrue(sameColor(voidLeft, COLORS.void), 'left void strip should be the void placeholder colour')
	local voidRight = pixelAt(canvas, math.floor(rects[2].x + rects[2].w / 2), math.floor(rects[2].y + rects[2].h / 2))
	assertTrue(sameColor(voidRight, COLORS.void), 'right void strip should be the void placeholder colour')

	-- The frame band is centred on the outset frame line, so a point just
	-- outside the world (left/right edges, and the top edge where it is on
	-- screen) is the frame's own edge-tile colour, drawn over the void.
	-- Left/right share the vertical tile texture, top/bottom the horizontal.
	local lx, ly = worldToScreen(-4, 336, tx, ty, sx, sy)
	local lc = pixelAt(canvas, math.floor(lx), math.floor(ly))
	assertTrue(sameColor(lc, COLORS.vertical), 'left frame edge tile should sit just outside the world')
	local rx, ry = worldToScreen(644, 336, tx, ty, sx, sy)
	assertTrue(sameColor(pixelAt(canvas, math.floor(rx), math.floor(ry)), COLORS.vertical), 'right frame edge tile should sit just outside the world')

	if ty > 4 then
		local txp, typ = worldToScreen(336, -4, tx, ty, sx, sy)
		assertTrue(sameColor(pixelAt(canvas, math.floor(txp), math.floor(typ)), COLORS.horizontal), 'top frame edge tile should sit just above the world')
	end

	-- The inside of the world is map content, neither void nor frame colour.
	local ix, iy = worldToScreen(320, 320, tx, ty, sx, sy)
	local inside = pixelAt(canvas, math.floor(ix), math.floor(iy))
	assertFalse(sameColor(inside, COLORS.void), 'world interior should not be void colour')
	for _, c in ipairs({ COLORS.horizontal, COLORS.vertical }) do
		assertFalse(sameColor(inside, c), 'world interior should not be a frame edge-tile colour')
	end

	Capture.capture('02_inside_world')
end)