-- Round-trips TmxWriter output through the game's real .tmx parser
-- (src/map/tmx.lua) rather than diffing raw XML: this is the parser that
-- actually loads generated levels in the game, so it's the true public
-- interface the writer must satisfy.
local TmxWriter = require('tools.level_generator.tmx_writer')
local Tmx = require('src.map.tmx')

local GENERATED_PATH = 'res/map/generated/test.tmx'

local function walkingSkeletonMap()
	return {
		width = 20,
		height = 15,
		tilewidth = 32,
		tileheight = 32,
		nextobjectid = 3,
		properties = {
			{name = 'name', value = 'Generated'},
			{name = 'players', type = 'int', value = 1},
		},
		tilesets = {
			{firstgid = 1, source = '../../editor/tileset_generic_platformer_tiles.tsx'},
			{firstgid = 145, source = '../../editor/tileset_props.tsx'},
		},
		layers = {
			{
				id = 1,
				type = 'tilelayer',
				name = 'ground',
				width = 20,
				height = 15,
				properties = {{name = 'collision', type = 'bool', value = true}},
				data = (function()
					local rows = {}
					for y = 1, 15 do
						local row = {}
						for x = 1, 20 do
							row[x] = (y == 15) and 1 or 0
						end
						rows[y] = row
					end
					return rows
				end)(),
			},
			{
				id = 2,
				type = 'objectgroup',
				name = 'game',
				objects = {
					{id = 1, template = '../../editor/spawn.tx', name = 'spawn', x = 64, y = 448},
					{
						id = 2,
						template = '../../editor/exit_door.tx',
						name = 'exit_door',
						x = 544,
						y = 448,
						properties = {{name = 'actor_count', type = 'int', value = 0}},
					},
				},
			},
		},
	}
end

local B64_DECODE = {}
do
	local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	for i = 1, #chars do
		B64_DECODE[chars:sub(i, i)] = i - 1
	end
end

-- Tmx.parse deliberately leaves tile layer data base64-encoded (the real
-- decode step needs love.data/LuaJIT ffi via lib/sti, unavailable headless)
-- so this test decodes it independently to assert on actual tile gids.
local function decodeTileGids(base64Data, width, height)
	local clean = base64Data:gsub('%s', '')
	local bytes = {}
	for i = 1, #clean, 4 do
		local chunk = clean:sub(i, i + 3)
		local n = 0
		for j = 1, 4 do
			local c = chunk:sub(j, j)
			n = n * 64 + (c == '=' and 0 or B64_DECODE[c])
		end
		local b1 = math.floor(n / 65536) % 256
		local b2 = math.floor(n / 256) % 256
		local b3 = n % 256
		table.insert(bytes, b1)
		table.insert(bytes, b2)
		table.insert(bytes, b3)
	end

	local grid = {}
	local idx = 1
	for y = 1, height do
		local row = {}
		for x = 1, width do
			local gid = bytes[idx] + bytes[idx + 1] * 256 + bytes[idx + 2] * 65536 + bytes[idx + 3] * 16777216
			row[x] = gid
			idx = idx + 4
		end
		grid[y] = row
	end
	return grid
end

local function parseGenerated(xml)
	return Tmx.parse(GENERATED_PATH, {
		readFile = function(path)
			if path == GENERATED_PATH then
				return xml
			end
			return require('src.map.tmx_xml').defaultReadFile(path)
		end,
	})
end

test('emits a map with the requested dimensions', function()
	local xml = TmxWriter.write(walkingSkeletonMap())
	local map = parseGenerated(xml)

	assertEqual(20, map.width)
	assertEqual(15, map.height)
	assertEqual(32, map.tilewidth)
end)

test('ground layer carries the collision property so the game builds static bodies for it', function()
	local xml = TmxWriter.write(walkingSkeletonMap())
	local map = parseGenerated(xml)

	local ground = map.layers[1]
	assertEqual('ground', ground.name)
	assertTrue(ground.properties.collision, 'expected ground layer collision property to be true')
end)

test('ground tiles fill only the bottom row', function()
	local xml = TmxWriter.write(walkingSkeletonMap())
	local map = parseGenerated(xml)

	local ground = map.layers[1]
	local grid = decodeTileGids(ground.data, ground.width, ground.height)
	assertTrue(grid[15][1] > 0, 'expected a tile at the bottom-left')
	assertEqual(0, grid[1][1], 'expected no tile at the top-left')
end)

test('spawn and exit objects are placed on the ground with the right templates', function()
	local xml = TmxWriter.write(walkingSkeletonMap())
	local map = parseGenerated(xml)

	local gameLayer = map.layers[2]
	assertEqual('spawn', gameLayer.objects[1].name)
	assertEqual(64, gameLayer.objects[1].x)
	assertEqual(448, gameLayer.objects[1].y)

	local exit = gameLayer.objects[2]
	assertEqual('exit_door', exit.name)
	assertEqual(0, exit.properties.actor_count)
end)

test('emits a polyline sub-element for path objects', function()
	local map = walkingSkeletonMap()
	table.insert(map.layers, {
		id = 3,
		type = 'objectgroup',
		name = 'waypoints',
		objects = {
			{id = 10, name = 'jump_path', x = 64, y = 448, polyline = {{x = 0, y = 0}, {x = 64, y = -32}, {x = 128, y = 0}}},
		},
	})

	local xml = TmxWriter.write(map)
	local parsedMap = parseGenerated(xml)
	local waypoints = parsedMap.layers[3]

	assertEqual(1, #waypoints.objects)
	local points = waypoints.objects[1].polyline
	assertEqual(3, #points)
	assertEqual(0, points[1].x)
	assertEqual(64, points[2].x)
	assertEqual(-32, points[2].y)
end)

test('same input produces byte-identical output (determinism)', function()
	local a = TmxWriter.write(walkingSkeletonMap())
	local b = TmxWriter.write(walkingSkeletonMap())
	assertEqual(a, b)
end)
