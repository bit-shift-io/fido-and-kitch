-- Unit tests for the pixel-map export (src/export_png.lua). Covers the
-- pure pieces -- buildColorGrid and buildImageData -- with synthetic
-- decoded maps; decodeTileGrid needs love.data and is exercised by the
-- real `love . export=<map>` run instead (its input shape is pinned by
-- Tmx.parse, which tmx_test.lua already locks down).
local ExportPng = require('src.export_png')

local COLOR_EMPTY = { 0, 0, 0 }
local COLOR_SOLID = { 0, 255, 0 }
local COLOR_KILLZONE = { 0, 0, 255 }

local function makeMap(overrides)
	local map = {
		width = 4,
		height = 3,
		tilewidth = 32,
		tileheight = 32,
		_exportName = 'mymap',
		layers = {},
	}
	for k, v in pairs(overrides or {}) do
		map[k] = v
	end
	return map
end

local function emptyGrid(width, height)
	local grid = {}
	for y = 1, height do
		grid[y] = {}
		for x = 1, width do
			grid[y][x] = 0
		end
	end
	return grid
end

local function collisionObjectGroup(objects)
	return {
		type = 'objectgroup',
		properties = { collision = true },
		objects = objects,
	}
end

local function objectGroup(objects)
	return {
		type = 'objectgroup',
		properties = {},
		objects = objects,
	}
end

local function killZone(x, y, width, height, deathType)
	local obj = {
		type = 'kill_zone',
		shape = 'rectangle',
		x = x,
		y = y,
		width = width,
		height = height,
		properties = {},
	}
	if deathType then
		obj.properties.deathType = deathType
	end
	return obj
end

local function collisionRect(x, y, width, height)
	return {
		type = 'collision',
		shape = 'rectangle',
		x = x,
		y = y,
		width = width,
		height = height,
		properties = {},
	}
end

local function rowColorString(row, channel)
	channel = channel or 1
	local out = {}
	for x = 1, #row do
		table.insert(out, tostring(row[x][channel]))
	end
	return table.concat(out, ',')
end

local function sameColor(a, b)
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

local function samePixel(a, b)
	return sameColor(a, b) and a[4] == b[4]
end

test('collision tile layer paints green and leaves empty cells black', function()
	local grid = emptyGrid(4, 3)
	for x = 1, 4 do
		grid[1][x] = 5
	end
	grid[3][1] = 5

	local map = makeMap({
		layers = {
			{
				type = 'tilelayer',
				properties = { collision = true },
				data = grid,
			},
		},
	})

	local out = ExportPng.buildColorGrid(map)
	assertEqual('255,255,255,255', rowColorString(out[1], 2), 'solid row green')
	assertEqual('0,0,0,0', rowColorString(out[2], 2), 'empty row black')
	assertEqual('255,0,0,0', rowColorString(out[3], 2), 'single solid cell green')
	assertTrue(sameColor(COLOR_SOLID, out[1][1]), 'grid holds the solid color')
	assertTrue(sameColor(COLOR_EMPTY, out[2][1]), 'empty cells hold the empty color')
end)

test('collision objectgroup rects paint green', function()
	local map = makeMap({
		layers = {
			collisionObjectGroup({ collisionRect(0, 0, 32, 64) }),
		},
	})

	local out = ExportPng.buildColorGrid(map)
	assertEqual('255,0,0,0', rowColorString(out[1], 2), 'first cell covered by 32x64 rect')
	assertEqual('255,0,0,0', rowColorString(out[2], 2), 'rect spans two rows')
	assertEqual('0,0,0,0', rowColorString(out[3], 2), 'below the rect black')
end)

test('collision-less tile layers are ignored', function()
	local grid = emptyGrid(4, 3)
	grid[1][1] = 5

	local map = makeMap({
		layers = {
			{ type = 'tilelayer', properties = {}, data = grid },
		},
	})

	local out = ExportPng.buildColorGrid(map)
	assertEqual('0,0,0,0', rowColorString(out[1], 2), 'no collision property, no solid')
end)

test('all kill zone deathTypes paint the same blue', function()
	local map = makeMap({
		layers = {
			objectGroup({
				killZone(0, 0, 32, 32, 'water'),
				killZone(32, 0, 32, 32, 'fire'),
				killZone(64, 0, 32, 32, 'lava'),
				killZone(96, 0, 32, 32, 'spikes'),
			}),
		},
	})

	local out = ExportPng.buildColorGrid(map)
	assertEqual('255,255,255,255', rowColorString(out[1], 3), 'every hazard is blue')
	assertEqual('0,0,0,0', rowColorString(out[2], 3), 'rects span one row, blue channel only')
end)

test('unset or unknown kill zone deathType still paints blue', function()
	local map = makeMap({
		layers = {
			objectGroup({
				killZone(0, 0, 32, 32),
				killZone(32, 0, 32, 32, 'lava_pit'),
			}),
		},
	})

	local out = ExportPng.buildColorGrid(map)
	assertEqual('255,255,0,0', rowColorString(out[1], 3), 'both fall back to blue')
end)

test('kill zones paint over solid ground', function()
	local grid = emptyGrid(4, 3)
	grid[1][1] = 5

	local map = makeMap({
		layers = {
			{
				type = 'tilelayer',
				properties = { collision = true },
				data = grid,
			},
			objectGroup({ killZone(0, 0, 32, 32, 'water') }),
		},
	})

	local out = ExportPng.buildColorGrid(map)
	assertTrue(sameColor(COLOR_KILLZONE, out[1][1]), 'hazard cell wins over solid')
end)

test('buildImageData maps the grid to ImageData pixels', function()
	local realLove = love
	local pixels = {}
	love = {
		image = {
			newImageData = function(w, h)
				local imageData = { width = w, height = h }
				function imageData:setPixel(x, y, r, g, b, a)
					pixels[(y * w + x) + 1] = { r, g, b, a }
				end
				return imageData
			end,
		},
	}

	local ok, err = xpcall(function()
		local grid = {
			{ COLOR_EMPTY, COLOR_SOLID, COLOR_KILLZONE },
			{ COLOR_SOLID, COLOR_KILLZONE, COLOR_EMPTY },
		}
		local imageData = ExportPng.buildImageData(grid, 3, 2)
		assertEqual(3, imageData.width, 'image width = tiles across')
		assertEqual(2, imageData.height, 'image height = tiles down')
		assertEqual(6, #pixels, 'one pixel per tile')
		assertTrue(sameColor(COLOR_EMPTY, { pixels[1][1], pixels[1][2], pixels[1][3] }), 'empty pixel black')
		assertTrue(samePixel({ 0, 255, 0, 255 }, pixels[2]), 'solid pixel green, opaque')
		assertTrue(samePixel({ 0, 0, 255, 255 }, pixels[3]), 'killzone pixel blue, opaque')
	end, debug.traceback)
	love = realLove
	if not ok then
		error(err, 2)
	end
end)

test('buildImageData renders each tile as a scale x scale block', function()
	local realLove = love
	local pixels = {}
	love = {
		image = {
			newImageData = function(w, h)
				local imageData = { width = w, height = h }
				function imageData:setPixel(x, y, r, g, b, a)
					pixels[(y * w + x) + 1] = { r, g, b, a }
				end
				return imageData
			end,
		},
	}

	local ok, err = xpcall(function()
		local grid = {
			{ COLOR_SOLID, COLOR_KILLZONE },
			{ COLOR_EMPTY, COLOR_SOLID },
		}
		local imageData = ExportPng.buildImageData(grid, 2, 2, 64)
		assertEqual(128, imageData.width, 'image width = tiles across x scale')
		assertEqual(128, imageData.height, 'image height = tiles down x scale')
		assertEqual(128 * 128, #pixels, 'one block of 64x64 per tile')

		-- top-left tile is solid green -- its whole 64x64 block
		assertTrue(samePixel({ 0, 255, 0, 255 }, pixels[(0 * 128 + 0) + 1]), 'block top-left green')
		assertTrue(samePixel({ 0, 255, 0, 255 }, pixels[(0 * 128 + 63) + 1]), 'block top-right corner green')
		assertTrue(samePixel({ 0, 255, 0, 255 }, pixels[(63 * 128 + 0) + 1]), 'block bottom-left corner green')
		assertTrue(samePixel({ 0, 255, 0, 255 }, pixels[(63 * 128 + 63) + 1]), 'block bottom-right corner green')
		-- boundary into the top-right tile (killzone blue)
		assertTrue(samePixel({ 0, 0, 255, 255 }, pixels[(0 * 128 + 64) + 1]), 'next tile starts at x=64')
	end, debug.traceback)
	love = realLove
	if not ok then
		error(err, 2)
	end
end)
