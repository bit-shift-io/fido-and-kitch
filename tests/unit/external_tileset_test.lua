local TjTileset = require('src.map.tj_tileset')

local GENERIC_PLATFORMER_TILES_TSJ = [[{
  "columns": 8,
  "image": "../img/generic_platformer_tiles.png",
  "imageheight": 576,
  "imagewidth": 256,
  "margin": 0,
  "name": "generic_platformer_tiles",
  "spacing": 0,
  "tilecount": 144,
  "tileheight": 32,
  "tilewidth": 32,
  "type": "tileset",
  "version": "1.5"
}]]

local SWITCH_TSJ = [[{
  "columns": 0,
  "grid": {
    "height": 1,
    "orientation": "orthogonal",
    "width": 1
  },
  "margin": 0,
  "name": "switch",
  "spacing": 0,
  "tilecount": 1,
  "tiledversion": "1.12.2",
  "tileheight": 128,
  "tiles": [
    {
      "id": 0,
      "image": "../img/entity_switch.png",
      "imageheight": 128,
      "imagewidth": 640,
      "width": 128,
      "x": 0,
      "y": 0
    }
  ],
  "tilewidth": 128,
  "type": "tileset",
  "version": "1.11"
}]]

local function fakeReader(contents)
	return function(path)
		return contents
	end
end

test('resolves a single-image tileset to an STI-shaped tileset table', function()
	local tileset = TjTileset.resolve('res/editor/tileset_generic_platformer_tiles.tsj', 1, {
		readFile = fakeReader(GENERIC_PLATFORMER_TILES_TSJ),
	})

	assertEqual('res/img/generic_platformer_tiles.png', tileset.image)
	assertEqual(256, tileset.imagewidth)
	assertEqual(576, tileset.imageheight)
	assertEqual(32, tileset.tilewidth)
	assertEqual(32, tileset.tileheight)
	assertEqual(8, tileset.columns)
	assertEqual(0, tileset.spacing)
	assertEqual(0, tileset.margin)
	assertEqual(144, tileset.tilecount)
	assertEqual(0, #tileset.tiles)
end)

test("resolved image path is relative to the tsj file's own directory, not the working directory", function()
	local tileset = TjTileset.resolve('some/other/dir/generic_platformer_tiles.tsj', 1, {
		readFile = fakeReader(GENERIC_PLATFORMER_TILES_TSJ),
	})

	assertEqual('some/other/img/generic_platformer_tiles.png', tileset.image)
end)

test('raises a clear error naming the file when the tsj cannot be read', function()
	local ok, err = pcall(function()
		TjTileset.resolve('res/editor/tileset_missing.tsj', 1, {
			readFile = function(path) return nil end,
		})
	end)

	assertEqual(false, ok)
	assertTrue(string.find(tostring(err), 'res/editor/tileset_missing.tsj', 1, true) ~= nil,
		'expected error to mention the missing file path, got: ' .. tostring(err))
end)

test('resolves a single-tile tileset to per-tile image entries', function()
	local tileset = TjTileset.resolve('res/editor/switch.tsj', 1, {
		readFile = fakeReader(SWITCH_TSJ),
	})

	assertEqual(0, tileset.columns)
	assertEqual(nil, tileset.image)
	assertEqual(1, #tileset.tiles)

	local switchTile = tileset.tiles[1]
	assertEqual(0, switchTile.id)
	assertEqual('res/img/entity_switch.png', switchTile.image)
	assertEqual(0, switchTile.x)
	assertEqual(0, switchTile.y)
	assertEqual(128, switchTile.width)
	assertEqual(128, switchTile.height)
end)

test('resolving the same tsj path twice only reads/parses it once', function()
	local readCount = 0
	local readFile = function(path)
		readCount = readCount + 1
		return GENERIC_PLATFORMER_TILES_TSJ
	end

	TjTileset.resolve('res/editor/tileset_cache_test_a.tsj', 1, { readFile = readFile })
	local second = TjTileset.resolve('res/editor/tileset_cache_test_a.tsj', 1, { readFile = readFile })

	assertEqual(1, readCount)
	assertEqual('res/img/generic_platformer_tiles.png', second.image)
	assertEqual(144, second.tilecount)
end)

test('two different tsj paths are cached independently', function()
	local tilesetA = TjTileset.resolve('res/editor/tileset_cache_test_b.tsj', 1, {
		readFile = fakeReader(GENERIC_PLATFORMER_TILES_TSJ),
	})
	local tilesetB = TjTileset.resolve('res/editor/tileset_cache_test_c.tsj', 145, {
		readFile = fakeReader(SWITCH_TSJ),
	})

	assertEqual('res/img/generic_platformer_tiles.png', tilesetA.image)
	assertEqual(8, tilesetA.columns)
	assertEqual(0, tilesetB.columns)
	assertEqual(1, #tilesetB.tiles)
end)

test('a cached resolution still reflects the firstgid passed on that call', function()
	local readFile = fakeReader(GENERIC_PLATFORMER_TILES_TSJ)

	TjTileset.resolve('res/editor/tileset_cache_test_d.tsj', 1, { readFile = readFile })
	local second = TjTileset.resolve('res/editor/tileset_cache_test_d.tsj', 50, { readFile = readFile })

	assertEqual(50, second.firstgid)
end)

test('raises a clear error naming the file when the tsj is malformed', function()
	local ok, err = pcall(function()
		TjTileset.resolve('res/editor/tileset_broken.tsj', 1, {
			readFile = fakeReader('{"name": "not a tileset"}'),
		})
	end)

	assertEqual(false, ok)
	assertTrue(string.find(tostring(err), 'res/editor/tileset_broken.tsj', 1, true) ~= nil,
		'expected error to mention the broken file path, got: ' .. tostring(err))
end)
