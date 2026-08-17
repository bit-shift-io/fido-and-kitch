-- Pure geometry for the Diorama world-edge frame & void fill. No love.* at
-- module scope (same contract as src/map/map_parallax.lua), so this requires
-- src/diorama directly under the headless runner.
local Diorama = require('src.diorama')
local _internal = Diorama._internal

local worldScreenRect = _internal.worldScreenRect
local computeVoidRects = _internal.computeVoidRects
local computeFrame = _internal.computeFrame
local assignOrnaments = _internal.assignOrnaments

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
					topLeft = { img = 'res/img/diorama/diorama_corner_tl.png', scale = 1 },
					topRight = { img = 'res/img/diorama/diorama_corner_tr.png', scale = 1 },
					bottomLeft = { img = 'res/img/diorama/diorama_corner_bl.png', scale = 1 },
					bottomRight = { img = 'res/img/diorama/diorama_corner_br.png', scale = 1 },
				},
				top = {
					count = 2,
					items = {
						{ img = 'res/img/diorama/diorama_orn_top_a.png', weight = 0.4, scale = 1 },
						{ img = 'res/img/diorama/diorama_orn_top_b.png', weight = 0.3, scale = 0.75 },
						{ img = 'res/img/diorama/diorama_orn_top_c.png', weight = 0.3, scale = 1.25 },
					},
				},
				bottom = {
					count = 2,
					items = {
						{ img = 'res/img/diorama/diorama_orn_bot_a.png', weight = 0.5, scale = 1 },
						{ img = 'res/img/diorama/diorama_orn_bot_b.png', weight = 0.5, scale = 1 },
					},
				},
				left = {
					count = 1,
					items = {
						{ img = 'res/img/diorama/diorama_orn_left_a.png', weight = 1, scale = 1 },
					},
				},
				right = {
					count = 2,
					items = {
						{ img = 'res/img/diorama/diorama_orn_right_a.png', weight = 0.7, scale = 1 },
						{ img = 'res/img/diorama/diorama_orn_right_b.png', weight = 0.3, scale = 0.5 },
					},
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
		assertTrue(type(f.ornaments.corners[key].img) == 'string', 'frame.ornaments.corners.' .. key .. '.img should be a path string')
		assertTrue(type(f.ornaments.corners[key].scale) == 'number' and f.ornaments.corners[key].scale > 0, 'frame.ornaments.corners.' .. key .. '.scale should be positive')
	end
	for _, side in ipairs({ 'top', 'bottom', 'left', 'right' }) do
		local orn = f.ornaments[side]
		assertTrue(type(orn) == 'table', 'frame.ornaments.' .. side .. ' should exist')
		assertTrue(type(orn.count) == 'number' and orn.count >= 1, 'frame.ornaments.' .. side .. '.count should be a positive number')
		assertTrue(type(orn.items) == 'table' and #orn.items > 0, 'frame.ornaments.' .. side .. '.items should be a non-empty pool')
		for _, item in ipairs(orn.items) do
			assertTrue(type(item.img) == 'string', 'ornament img should be a path string')
			assertTrue(type(item.weight) == 'number' and item.weight > 0, 'ornament weight should be positive')
			assertTrue(type(item.scale) == 'number' and item.scale > 0, 'ornament scale should be a positive number')
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
		assertEqual(config.frame.ornaments.corners[key].scale, frame.cornerOrnaments[key].scale, key .. ' scale')
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

test('ornament slots are a fixed count per edge at even intervals on the outset frame line', function()
	local frame = computeFrame(640, 480, makeConfig())

	assertEqual(2, #frame.ornamentSlots.top, 'top edge has its configured count of slots')
	assertEqual(2, #frame.ornamentSlots.bottom)
	assertEqual(1, #frame.ornamentSlots.left, 'left edge has its configured count of slots')
	assertEqual(2, #frame.ornamentSlots.right)

	local first = frame.ornamentSlots.top[1]
	assertNear(640 / 3, first.x, 0.000001, 'first top slot is at edgeLen/(count+1), inset from the corner')
	assertNear(2 * 640 / 3, frame.ornamentSlots.top[2].x, 0.000001, 'second top slot is at 2*edgeLen/(count+1)')
	assertEqual(-8, first.y, 'top slots sit centred on the y=-outset frame line')

	local leftSlot = frame.ornamentSlots.left[1]
	assertEqual(-8, leftSlot.x, 'left slot sits on the x=-outset frame line')
	assertNear(480 / 2, leftSlot.y, 0.000001, 'a single left slot sits centred on the edge')
end)

test('assignOrnaments is deterministic and uses every pool item', function()
	local pool = {
		{ img = 'a', weight = 0.5, scale = 1 },
		{ img = 'b', weight = 0.3, scale = 2 },
		{ img = 'c', weight = 0.2, scale = 0.5 },
	}

	local first = assignOrnaments(pool, 10)
	local second = assignOrnaments(pool, 10)

	assertEqual(#first, 10)
	for i = 1, 10 do
		assertEqual(first[i].img, second[i].img, 'deterministic: same input, same output')
	end

	local seen = {}
	for _, item in ipairs(first) do
		seen[item.img] = (seen[item.img] or 0) + 1
	end
	assertEqual(5, seen.a, 'weight 0.5 of 10 slots')
	assertEqual(3, seen.b, 'weight 0.3 of 10 slots')
	assertEqual(2, seen.c, 'weight 0.2 of 10 slots')
end)

test('assignOrnaments carries each item through with its scale', function()
	local pool = {
		{ img = 'a', weight = 0.5, scale = 1 },
		{ img = 'b', weight = 0.3, scale = 2 },
		{ img = 'c', weight = 0.2, scale = 0.5 },
	}
	local out = assignOrnaments(pool, 10)
	for _, item in ipairs(out) do
		assertEqual(pool[item.img == 'a' and 1 or (item.img == 'b' and 2 or 3)].scale, item.scale, 'item keeps its own scale')
	end
end)

test('assignOrnaments distributes a single-item pool to every slot', function()
	local pool = { { img = 'only', weight = 1 } }
	local out = assignOrnaments(pool, 7)
	assertEqual(7, #out)
	for i = 1, 7 do
		assertEqual('only', out[i].img)
	end
end)

test('assignOrnaments returns empty for zero slots', function()
	local pool = { { img = 'a', weight = 1 } }
	assertEqual(0, #assignOrnaments(pool, 0))
end)