local ExternalTileset = require('src.map.external_tileset')

local GENERIC_PLATFORMER_TILES_TSX = [[<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.5" tiledversion="1.7.2" name="generic_platformer_tiles" tilewidth="32" tileheight="32" tilecount="144" columns="8">
 <image source="../img/generic_platformer_tiles.png" trans="000000" width="256" height="576"/>
</tileset>
]]

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

local GRID_WITH_TILE_METADATA_TSX = [[<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.5" tiledversion="1.7.2" name="generic_platformer_tiles" tilewidth="32" tileheight="32" tilecount="144" columns="8">
 <image source="../img/generic_platformer_tiles.png" width="256" height="576"/>
 <tile id="5">
  <properties>
   <property name="solid" type="bool" value="true"/>
   <property name="label" value="ground"/>
  </properties>
 </tile>
 <tile id="10">
  <animation>
   <frame tileid="10" duration="100"/>
   <frame tileid="11" duration="150"/>
  </animation>
 </tile>
 <tile id="20">
  <objectgroup draworder="index" id="2">
   <object id="1" x="4" y="4" width="24" height="24"/>
  </objectgroup>
 </tile>
</tileset>
]]

local function fakeReader(contents)
	return function(path)
		return contents
	end
end

test('resolves a single-image tileset to an STI-shaped tileset table', function()
	local tileset = ExternalTileset.resolve('res/editor/tileset_generic_platformer_tiles.tsx', 1, {
		readFile = fakeReader(GENERIC_PLATFORMER_TILES_TSX),
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

test('resolved image path is relative to the tsx file\'s own directory, not the working directory', function()
	local tileset = ExternalTileset.resolve('some/other/dir/generic_platformer_tiles.tsx', 1, {
		readFile = fakeReader(GENERIC_PLATFORMER_TILES_TSX),
	})

	assertEqual('some/other/img/generic_platformer_tiles.png', tileset.image)
end)

test('raises a clear error naming the file when the tsx cannot be read', function()
	local ok, err = pcall(function()
		ExternalTileset.resolve('res/editor/tileset_missing.tsx', 1, {
			readFile = function(path) return nil end,
		})
	end)

	assertEqual(false, ok)
	assertTrue(string.find(tostring(err), 'res/editor/tileset_missing.tsx', 1, true) ~= nil,
		'expected error to mention the missing file path, got: ' .. tostring(err))
end)

test('resolves a single-tile tileset to per-tile image entries', function()
	local tileset = ExternalTileset.resolve('res/editor/switch.tsj', 1, {
		readFile = fakeReader(SWITCH_TSJ),
	})

	assertEqual(0, tileset.columns)
	assertEqual(nil, tileset.image)
	assertEqual(1, #tileset.tiles)
end)

test('an uncropped tile resolves the whole referenced image', function()
	local tileset = ExternalTileset.resolve('res/editor/switch.tsj', 1, {
		readFile = fakeReader(SWITCH_TSJ),
	})

	local switchTile = tileset.tiles[1]
	assertEqual(0, switchTile.id)
	assertEqual('../img/entity_switch.png', switchTile.image)
	assertEqual(640, switchTile.width)
	assertEqual(128, switchTile.height)
	assertEqual(nil, switchTile.x)
	assertEqual(nil, switchTile.y)
end)

test('a cropped tile resolves its own sub-region rect, not the full source image', function()
	-- The switch tile is cropped (has x,y,width,height)
	local tileset = ExternalTileset.resolve('res/editor/switch.tsj', 1, {
		readFile = fakeReader(SWITCH_TSJ),
	})

	local switchTile = tileset.tiles[1]
	assertEqual(0, switchTile.id)
	assertEqual('../img/entity_switch.png', switchTile.image)
	assertEqual(0, switchTile.x)
	assertEqual(0, switchTile.y)
	assertEqual(128, switchTile.width)
	assertEqual(128, switchTile.height)
end)

test('resolves per-tile custom properties on a grid tileset', function()
	local tileset = ExternalTileset.resolve('res/editor/tileset_generic_platformer_tiles_with_metadata.tsx', 1, {
		readFile = fakeReader(GRID_WITH_TILE_METADATA_TSX),
	})

	local tileWithProperties = nil
	for _, tile in ipairs(tileset.tiles) do
		if tile.id == 5 then tileWithProperties = tile end
	end

	assertTrue(tileWithProperties ~= nil, 'expected tile id 5 to be present in tileset.tiles')
	assertEqual(true, tileWithProperties.properties['solid'])
	assertEqual('ground', tileWithProperties.properties['label'])
end)

test('resolves per-tile animation frames on a grid tileset', function()
	local tileset = ExternalTileset.resolve('res/editor/tileset_generic_platformer_tiles_with_metadata.tsx', 1, {
		readFile = fakeReader(GRID_WITH_TILE_METADATA_TSX),
	})

	local animatedTile = nil
	for _, tile in ipairs(tileset.tiles) do
		if tile.id == 10 then animatedTile = tile end
	end

	assertTrue(animatedTile ~= nil, 'expected tile id 10 to be present in tileset.tiles')
	assertEqual(2, #animatedTile.animation)
	assertEqual(10, animatedTile.animation[1].tileid)
	assertEqual(100, animatedTile.animation[1].duration)
	assertEqual(11, animatedTile.animation[2].tileid)
	assertEqual(150, animatedTile.animation[2].duration)
end)

test('resolves a per-tile objectGroup (Tile Collision Editor shape) on a grid tileset', function()
	local tileset = ExternalTileset.resolve('res/editor/tileset_generic_platformer_tiles_with_metadata.tsx', 1, {
		readFile = fakeReader(GRID_WITH_TILE_METADATA_TSX),
	})

	local tileWithCollision = nil
	for _, tile in ipairs(tileset.tiles) do
		if tile.id == 20 then tileWithCollision = tile end
	end

	assertTrue(tileWithCollision ~= nil, 'expected tile id 20 to be present in tileset.tiles')
	assertTrue(tileWithCollision.objectGroup ~= nil, 'expected an objectGroup on tile id 20')
	assertEqual(1, #tileWithCollision.objectGroup.objects)
	assertEqual(4, tileWithCollision.objectGroup.objects[1].x)
	assertEqual(4, tileWithCollision.objectGroup.objects[1].y)
	assertEqual(24, tileWithCollision.objectGroup.objects[1].width)
	assertEqual(24, tileWithCollision.objectGroup.objects[1].height)
end)

test('resolving the same tsx path twice only reads/parses its XML once', function()
	local readCount = 0
	local readFile = function(path)
		readCount = readCount + 1
		return GENERIC_PLATFORMER_TILES_TSX
	end

	ExternalTileset.resolve('res/editor/tileset_cache_test_a.tsx', 1, { readFile = readFile })
	local second = ExternalTileset.resolve('res/editor/tileset_cache_test_a.tsx', 1, { readFile = readFile })

	assertEqual(1, readCount)
	assertEqual('res/img/generic_platformer_tiles.png', second.image)
	assertEqual(144, second.tilecount)
end)

test('two different tsx paths are cached independently', function()
	local tilesetA = ExternalTileset.resolve('res/editor/tileset_cache_test_b.tsx', 1, {
		readFile = fakeReader(GENERIC_PLATFORMER_TILES_TSX),
	})
	local tilesetB = ExternalTileset.resolve('res/editor/tileset_cache_test_c.tsx', 145, {
		readFile = fakeReader(SWITCH_TSJ),
	})

	assertEqual('res/img/generic_platformer_tiles.png', tilesetA.image)
	assertEqual(8, tilesetA.columns)
	assertEqual(0, tilesetB.columns)
	assertEqual(1, #tilesetB.tiles)
end)

test('a cached resolution still reflects the firstgid passed on that call', function()
	local readFile = fakeReader(GENERIC_PLATFORMER_TILES_TSX)

	ExternalTileset.resolve('res/editor/tileset_cache_test_d.tsx', 1, { readFile = readFile })
	local second = ExternalTileset.resolve('res/editor/tileset_cache_test_d.tsx', 50, { readFile = readFile })

	assertEqual(50, second.firstgid)
end)

test('raises a clear error naming the file when the tsx is malformed', function()
	local ok, err = pcall(function()
		ExternalTileset.resolve('res/editor/tileset_broken.tsx', 1, {
			readFile = fakeReader('<tileset><image></tileset>'),
		})
	end)

	assertEqual(false, ok)
	assertTrue(string.find(tostring(err), 'res/editor/tileset_broken.tsx', 1, true) ~= nil,
		'expected error to mention the broken file path, got: ' .. tostring(err))
end)
