-- Pure geometry for the Diorama world-edge frame & void fill. No love.* at
-- module scope (same contract as src/map/map_parallax.lua), so this requires
-- src/diorama directly under the headless runner.
local Diorama = require('src.diorama')
local _internal = Diorama._internal

local worldScreenRect = _internal.worldScreenRect
local computeVoidRects = _internal.computeVoidRects
local computeFrame = _internal.computeFrame

local function makeConfig()
	return {
		void = { img = 'res/img/diorama/diorama_void.png' },
		frame = {
			tileSize = 16,
			outset = 8,
			tiles = {
				top = 'res/img/diorama/diorama_frame_top.png',
				bottom = 'res/img/diorama/diorama_frame_bottom.png',
				left = 'res/img/diorama/diorama_frame_left.png',
				right = 'res/img/diorama/diorama_frame_right.png',
			},
			ornaments = {
				corners = {
					topLeft = { img = 'res/img/diorama/diorama_corner_tl.png', scale = { x = 1, y = 1 } },
					topRight = { img = 'res/img/diorama/diorama_corner_tr.png', scale = { x = 1, y = 1 } },
					bottomLeft = { img = 'res/img/diorama/diorama_corner_bl.png', scale = { x = 1, y = 1 } },
					bottomRight = { img = 'res/img/diorama/diorama_corner_br.png', scale = { x = 1, y = 1 } },
				},
				top = {
					{ img = 'res/img/diorama/diorama_orn_top_a.png', pos = 1 / 3, scale = { x = 1, y = 1 } },
					{ img = 'res/img/diorama/diorama_orn_top_b.png', pos = 2 / 3, scale = { x = -1, y = 0.75 }, offset = 10 },
				},
				bottom = {
					{ img = 'res/img/diorama/diorama_orn_bot_a.png', pos = 0.25, offset = -5 },
					{ img = 'res/img/diorama/diorama_orn_bot_b.png', pos = 0.75, scale = { x = 2, y = 0.5 } },
				},
				left = {
					{ img = 'res/img/diorama/diorama_orn_left_a.png', pos = 0.5, scale = { x = 1, y = 1 } },
				},
				right = {
					{ img = 'res/img/diorama/diorama_orn_right_a.png', pos = 0.25, scale = { x = 1, y = 1 }, offset = 6 },
					{ img = 'res/img/diorama/diorama_orn_right_b.png', pos = 0.75, scale = { x = 0.5, y = 0.5 } },
				},
			},
		},
	}
end

test('config defaults are present and stable', function()
	assertEqual('res/img/diorama/diorama_void.png', Diorama.config.void.img)

	local f = Diorama.config.frame
	assertTrue(type(f.tileSize) == 'number', 'frame.tileSize should be a number')
	assertTrue(type(f.outset) == 'number', 'frame.outset should be a number')
	for _, side in ipairs({ 'top', 'bottom', 'left', 'right' }) do
		assertTrue(type(f.tiles[side]) == 'string', 'frame.tiles.' .. side .. ' should be a path string')
	end
	for _, key in ipairs({ 'topLeft', 'topRight', 'bottomLeft', 'bottomRight' }) do
		local orn = f.ornaments.corners[key]
		local scale = orn.scale
		assertTrue(type(orn.img) == 'string', 'frame.ornaments.corners.' .. key .. '.img should be a path string')
		assertTrue(type(scale) == 'table' and type(scale.x) == 'number' and type(scale.y) == 'number', 'frame.ornaments.corners.' .. key .. '.scale should be an {x, y} pair')
		if orn.offset then
			assertTrue(type(orn.offset) == 'number', 'frame.ornaments.corners.' .. key .. '.offset should be a number of world px')
		end
	end
	for _, side in ipairs({ 'top', 'bottom', 'left', 'right' }) do
		local orn = f.ornaments[side]
		assertTrue(type(orn) == 'table' and #orn > 0, 'frame.ornaments.' .. side .. ' should be a non-empty list of ornaments')
		for _, item in ipairs(orn) do
			assertTrue(type(item.img) == 'string', 'ornament img should be a path string')
			assertTrue(type(item.pos) == 'number' and item.pos >= 0 and item.pos <= 1, 'ornament pos should be a 0..1 fraction along the edge')
			if item.scale then
				assertTrue(type(item.scale.x) == 'number' and type(item.scale.y) == 'number', 'ornament scale should be an {x, y} pair')
			end
			if item.offset then
				assertTrue(type(item.offset) == 'number', 'ornament offset should be a number of world px')
			end
		end
	end
end)

test('worldScreenRect floors the transform origin and scales the map size', function()
	local wr = worldScreenRect(100.7, 200.3, 2, 2, 320, 220)
	assertEqual(100, wr.x, 'tx must be floored')
	assertEqual(200, wr.y, 'ty must be floored')
	assertNear(640, wr.w, 0.000001, 'width is mapW * sx')
	assertNear(440, wr.h, 0.000001, 'height is mapH * sy')

	local wr2 = worldScreenRect(-10.9, -5.2, 0.5, 0.5, 100, 80)
	assertEqual(-11, wr2.x, 'negative tx floors away from zero (toward -inf)')
	assertEqual(-6, wr2.y, 'negative ty floors away from zero (toward -inf)')
	assertNear(50, wr2.w, 0.000001)
	assertNear(40, wr2.h, 0.000001)
end)

test('void rects are the two vertical strips for a wide screen', function()
	local wr = { x = 100, y = 0, w = 1000, h = 500 }
	local rects = computeVoidRects(1200, 500, wr)

	assertEqual(2, #rects, 'a wide screen yields exactly the left and right strips')
	assertEqual(0, rects[1].x)
	assertEqual(0, rects[1].y)
	assertEqual(100, rects[1].w)
	assertEqual(500, rects[1].h)
	assertEqual(1100, rects[2].x)
	assertEqual(0, rects[2].y)
	assertEqual(100, rects[2].w)
	assertEqual(500, rects[2].h)
end)

test('void rects are the two horizontal strips for a tall screen', function()
	local wr = { x = 0, y = 100, w = 500, h = 1000 }
	local rects = computeVoidRects(500, 1200, wr)

	assertEqual(2, #rects, 'a tall screen yields exactly the top and bottom strips')
	assertEqual(0, rects[1].x)
	assertEqual(0, rects[1].y)
	assertEqual(500, rects[1].w)
	assertEqual(100, rects[1].h)
	assertEqual(0, rects[2].x)
	assertEqual(1100, rects[2].y)
	assertEqual(500, rects[2].w)
	assertEqual(100, rects[2].h)
end)

test('void rects cover all four sides when the world is fully inset', function()
	local wr = { x = 100, y = 50, w = 600, h = 400 }
	local rects = computeVoidRects(1000, 700, wr)

	assertEqual(4, #rects, 'an inset world rect produces all four strips')
	local union = { 0, 0, 1000, 700 }
	local total = 0
	for _, r in ipairs(rects) do
		assertTrue(r.x >= 0 and r.y >= 0 and r.x + r.w <= 1000 and r.y + r.h <= 700, 'strip must stay inside the screen')
		assertTrue(r.w > 0 and r.h > 0, 'strips must be non-zero size')
		total = total + r.w * r.h
	end
	local worldArea = 600 * 400
	assertNear(1000 * 700 - worldArea, total, 0.000001, 'strips union to exactly screen minus world rect')
	assertEqual(0, rects[1].x, 'left strip starts at screen x=0')
	assertEqual(100, rects[1].w, 'left strip width matches the world rect offset')
end)

test('void rects are empty when the world fills the screen', function()
	local rects = computeVoidRects(800, 600, { x = 0, y = 0, w = 800, h = 600 })
	assertEqual(0, #rects)
end)

test('corner ornaments land on the four corners of the outset frame line', function()
	local frame = computeFrame(640, 480, makeConfig())

	assertEqual(-8, frame.cornerOrnaments.topLeft.x)
	assertEqual(-8, frame.cornerOrnaments.topLeft.y)
	assertEqual(648, frame.cornerOrnaments.topRight.x)
	assertEqual(-8, frame.cornerOrnaments.topRight.y)
	assertEqual(-8, frame.cornerOrnaments.bottomLeft.x)
	assertEqual(488, frame.cornerOrnaments.bottomLeft.y)
	assertEqual(648, frame.cornerOrnaments.bottomRight.x)
	assertEqual(488, frame.cornerOrnaments.bottomRight.y)
end)

test('corner ornament entries carry their config image paths and scale', function()
	local config = makeConfig()
	local frame = computeFrame(640, 480, config)

	for _, key in ipairs({ 'topLeft', 'topRight', 'bottomLeft', 'bottomRight' }) do
		assertEqual(config.frame.ornaments.corners[key].img, frame.cornerOrnaments[key].img, key .. ' img path')
		assertEqual(config.frame.ornaments.corners[key].scale.x, frame.cornerOrnaments[key].scale.x, key .. ' scale.x')
		assertEqual(config.frame.ornaments.corners[key].scale.y, frame.cornerOrnaments[key].scale.y, key .. ' scale.y')
	end
end)

test('edge tile spans run the full edge length on the outset frame line', function()
	local frame = computeFrame(640, 480, makeConfig())

	assertEqual(-8, frame.edges.top.fixed, 'top edge runs along the y=-outset line')
	assertEqual(0, frame.edges.top.from, 'top edge tiles start at the corner')
	assertEqual(640, frame.edges.top.to, 'top edge tiles span the full map width')
	assertEqual(648, frame.edges.right.fixed, 'right edge runs along the x=mapW+outset line')
	assertEqual(0, frame.edges.right.from)
	assertEqual(480, frame.edges.right.to, 'right edge tiles span the full map height')
end)

test('computeTileCount tiles the whole edge length', function()
	local computeTileCount = _internal.computeTileCount

	assertEqual(4, computeTileCount(100, 25), 'exact multiple')
	assertEqual(5, computeTileCount(101, 25), 'ceil overruns the far corner so no gap')
	assertEqual(0, computeTileCount(100, 0), 'degenerate tile length yields no tiles')
end)

test('ornament slots sit at their configured percentage position on the outset frame line', function()
	local config = makeConfig()
	local frame = computeFrame(640, 480, config)

	assertEqual(2, #frame.ornamentSlots.top, 'top edge has one slot per configured ornament')
	assertEqual(2, #frame.ornamentSlots.bottom)
	assertEqual(1, #frame.ornamentSlots.left, 'left edge has one slot per configured ornament')
	assertEqual(2, #frame.ornamentSlots.right)

	local first = frame.ornamentSlots.top[1]
	assertNear(640 / 3, first.x, 0.000001, 'first top slot is at pos * edgeLen')
	assertNear(2 * 640 / 3, frame.ornamentSlots.top[2].x, 0.000001, 'second top slot is at 2/3 of the edge length')
	assertEqual(-8, first.y, 'top slots sit centred on the y=-outset frame line')
	assertEqual('res/img/diorama/diorama_orn_top_a.png', first.img, 'slot carries its configured image')
	assertNear(1, first.scale.x, 0.000001, 'slot carries its configured scale.x')
	assertNear(1, first.scale.y, 0.000001, 'slot carries its configured scale.y')

	local flipped = frame.ornamentSlots.top[2]
	assertNear(-1, flipped.scale.x, 0.000001, 'a negative scale.x is carried through for flipping')
	assertNear(0.75, flipped.scale.y, 0.000001)

	local stretched = frame.ornamentSlots.bottom[2]
	assertNear(2, stretched.scale.x, 0.000001, 'a stretched scale.x is carried through verbatim')
	assertNear(0.5, stretched.scale.y, 0.000001)

	local bare = frame.ornamentSlots.bottom[1]
	assertEqual(nil, bare.scale, 'an ornament omitting scale passes nil through')

	local leftSlot = frame.ornamentSlots.left[1]
	assertEqual(-8, leftSlot.x, 'left slot sits on the x=-outset frame line')
	assertNear(480 / 2, leftSlot.y, 0.000001, 'a slot at pos 0.5 sits centred on the edge')
end)

test('ornament offset shifts pieces perpendicular to the edge, away from the playfield when positive', function()
	local config = makeConfig()
	local frame = computeFrame(640, 480, config)

	local top = frame.ornamentSlots.top[2]
	assertNear(2 * 640 / 3, top.x, 0.000001, 'offset must not move the piece along the edge')
	assertEqual(-18, top.y, 'a positive offset on the top edge pushes out: y = -outset - 10')

	local bottom = frame.ornamentSlots.bottom[1]
	assertNear(640 * 0.25, bottom.x, 0.000001, 'offset must not move the piece along the edge')
	assertEqual(483, bottom.y, 'a negative offset on the bottom edge pulls in: y = mapH + outset - 5')

	local right = frame.ornamentSlots.right[1]
	assertNear(480 * 0.25, right.y, 0.000001, 'offset must not move the piece along the edge')
	assertEqual(654, right.x, 'a positive offset on the right edge pushes out: x = mapW + outset + 6')

	local left = frame.ornamentSlots.left[1]
	assertEqual(-8, left.x, 'an ornament without offset stays centred on the frame line')
end)

test('corner ornament offset moves the corner diagonally away from the map corner', function()
	local config = makeConfig()
	config.frame.ornaments.corners.topLeft.offset = 4
	config.frame.ornaments.corners.bottomRight.offset = 3
	local frame = computeFrame(640, 480, config)

	assertEqual(-12, frame.cornerOrnaments.topLeft.x, 'topLeft offset pushes x outward')
	assertEqual(-12, frame.cornerOrnaments.topLeft.y, 'topLeft offset pushes y outward')
	assertEqual(651, frame.cornerOrnaments.bottomRight.x, 'bottomRight offset pushes x outward')
	assertEqual(491, frame.cornerOrnaments.bottomRight.y, 'bottomRight offset pushes y outward')

	assertEqual(648, frame.cornerOrnaments.topRight.x, 'an offset-free corner keeps its default position')
	assertEqual(-8, frame.cornerOrnaments.topRight.y)
end)