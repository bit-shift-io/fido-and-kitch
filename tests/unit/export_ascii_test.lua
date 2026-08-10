-- Unit tests for the ASCII map export (src/export_ascii.lua). Covers the
-- pure pieces -- buildSymbolGrid and renderText -- with synthetic decoded
-- maps; decodeTileGrid needs love.data and is exercised by the real `love .
-- export=<map>` run instead (its input shape is pinned by Tmx.parse, which
-- tmx_test.lua already locks down).
local ExportAscii = require('src.export_ascii')

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

local function render(map, grid)
	return ExportAscii.renderText(map, grid)
end

test('collision tile layer paints # and leaves empty cells blank', function()
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

	local out = ExportAscii.buildSymbolGrid(map)
	assertEqual('####', table.concat(out[1], ''), 'solid row')
	assertEqual('....', table.concat(out[2], ''), 'empty row')
	assertEqual('#...', table.concat(out[3], ''), 'single solid cell')
end)

test('collision objectgroup rects paint #', function()
	local map = makeMap({
		layers = {
			collisionObjectGroup({ collisionRect(0, 0, 32, 64) }),
		},
	})

	local out = ExportAscii.buildSymbolGrid(map)
	assertEqual('#...', table.concat(out[1], ''), 'first cell covered by 32x64 rect')
	assertEqual('#...', table.concat(out[2], ''), 'rect spans two rows')
	assertEqual('....', table.concat(out[3], ''), 'below the rect')
end)

test('collision-less tile layers are ignored', function()
	local grid = emptyGrid(4, 3)
	grid[1][1] = 5

	local map = makeMap({
		layers = {
			{ type = 'tilelayer', properties = {}, data = grid },
		},
	})

	local out = ExportAscii.buildSymbolGrid(map)
	assertEqual('....', table.concat(out[1], ''), 'no collision property, no solid')
end)

test('kill zones map deathType to water/fire/lava/spikes symbols', function()
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

	local out = ExportAscii.buildSymbolGrid(map)
	assertEqual('wfls', table.concat(out[1], ''), 'symbol per deathType')
	assertEqual('....', table.concat(out[2], ''), 'rects span one row')
end)

test('unset or unknown kill zone deathType defaults to water', function()
	local map = makeMap({
		layers = {
			objectGroup({
				killZone(0, 0, 32, 32),
				killZone(32, 0, 32, 32, 'lava_pit'),
			}),
		},
	})

	local out = ExportAscii.buildSymbolGrid(map)
	assertEqual('ww..', table.concat(out[1], ''), 'both fall back to water')
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

	local out = ExportAscii.buildSymbolGrid(map)
	assertEqual('w...', table.concat(out[1], ''), 'hazard cell wins over solid')
end)

test('renderText emits header, grid rows, and legend', function()
	local grid = {
		{ '#', '.', 'w', '.' },
		{ '.', '.', '.', '.' },
		{ 'l', '.', '.', '.' },
	}
	local map = makeMap()

	local text = render(map, grid)

	local expected = table.concat({
		'Export of mymap (4x3, tile 32x32px)',
		'',
		'#.w.',
		'....',
		'l...',
		'',
		'Legend:',
		'#  solid ground',
		'w  water',
		'f  fire',
		'l  lava',
		's  spikes',
		'.  nothing',
	}, '\n')

	assertEqual(expected, text, 'full export text')
	assertTrue(text:find('Export of mymap (4x3, tile 32x32px)', 1, true) ~= nil, 'header present')
	assertTrue(text:find('#  solid ground', 1, true) ~= nil, 'solid legend line')
end)