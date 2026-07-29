local ExternalTileset = require('src.map.external_tileset')

local GENERIC_PLATFORMER_TILES_TSX = [[<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.5" tiledversion="1.7.2" name="generic_platformer_tiles" tilewidth="32" tileheight="32" tilecount="144" columns="8">
 <image source="../img/generic_platformer_tiles.png" trans="000000" width="256" height="576"/>
</tileset>
]]

local PROPS_TSX = [[<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.11" tiledversion="1.12.2" name="props" tilewidth="1000" tileheight="1000" tilecount="11" columns="0">
 <grid orientation="orthogonal" width="1" height="1"/>
 <tile id="0">
  <image source="../img/default.png" width="32" height="32"/>
 </tile>
 <tile id="1">
  <image source="../img/pushable_crate_wood.png" width="256" height="256"/>
 </tile>
 <tile id="2" x="96" y="0" width="32" height="32">
  <image source="../img/ladder.png" width="128" height="32"/>
 </tile>
 <tile id="3" x="0" y="0" width="162" height="162">
  <image source="../img/switch.png" width="488" height="162"/>
 </tile>
</tileset>
]]

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
	local tileset = ExternalTileset.resolve('res/tilesets/generic_platformer_tiles.tsx', 1, {
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
		ExternalTileset.resolve('res/tilesets/missing.tsx', 1, {
			readFile = function(path) return nil end,
		})
	end)

	assertEqual(false, ok)
	assertTrue(string.find(tostring(err), 'res/tilesets/missing.tsx', 1, true) ~= nil,
		'expected error to mention the missing file path, got: ' .. tostring(err))
end)

test('resolves an image-collection tileset to per-tile image entries', function()
	local tileset = ExternalTileset.resolve('res/tilesets/props.tsx', 145, {
		readFile = fakeReader(PROPS_TSX),
	})

	assertEqual(0, tileset.columns)
	assertEqual(nil, tileset.image)
	assertEqual(4, #tileset.tiles)
end)

test('an uncropped tile resolves the whole referenced image', function()
	local tileset = ExternalTileset.resolve('res/tilesets/props.tsx', 145, {
		readFile = fakeReader(PROPS_TSX),
	})

	local pushableCrate = tileset.tiles[2]
	assertEqual(1, pushableCrate.id)
	assertEqual('res/img/pushable_crate_wood.png', pushableCrate.image)
	assertEqual(256, pushableCrate.width)
	assertEqual(256, pushableCrate.height)
	assertEqual(nil, pushableCrate.x)
	assertEqual(nil, pushableCrate.y)
end)

test('a cropped tile resolves its own sub-region rect, not the full source image', function()
	local tileset = ExternalTileset.resolve('res/tilesets/props.tsx', 145, {
		readFile = fakeReader(PROPS_TSX),
	})

	local switch = tileset.tiles[4]
	assertEqual(3, switch.id)
	assertEqual('res/img/switch.png', switch.image)
	assertEqual(0, switch.x)
	assertEqual(0, switch.y)
	assertEqual(162, switch.width)
	assertEqual(162, switch.height)

	local ladder = tileset.tiles[3]
	assertEqual(2, ladder.id)
	assertEqual(96, ladder.x)
	assertEqual(0, ladder.y)
	assertEqual(32, ladder.width)
	assertEqual(32, ladder.height)
end)

test('resolves per-tile custom properties on a grid tileset', function()
	local tileset = ExternalTileset.resolve('res/tilesets/generic_platformer_tiles_with_metadata.tsx', 1, {
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
	local tileset = ExternalTileset.resolve('res/tilesets/generic_platformer_tiles_with_metadata.tsx', 1, {
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
	local tileset = ExternalTileset.resolve('res/tilesets/generic_platformer_tiles_with_metadata.tsx', 1, {
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

	ExternalTileset.resolve('res/tilesets/cache_test_a.tsx', 1, { readFile = readFile })
	local second = ExternalTileset.resolve('res/tilesets/cache_test_a.tsx', 1, { readFile = readFile })

	assertEqual(1, readCount)
	assertEqual('res/img/generic_platformer_tiles.png', second.image)
	assertEqual(144, second.tilecount)
end)

test('two different tsx paths are cached independently', function()
	local tilesetA = ExternalTileset.resolve('res/tilesets/cache_test_b.tsx', 1, {
		readFile = fakeReader(GENERIC_PLATFORMER_TILES_TSX),
	})
	local tilesetB = ExternalTileset.resolve('res/tilesets/cache_test_c.tsx', 145, {
		readFile = fakeReader(PROPS_TSX),
	})

	assertEqual('res/img/generic_platformer_tiles.png', tilesetA.image)
	assertEqual(8, tilesetA.columns)
	assertEqual(0, tilesetB.columns)
	assertEqual(4, #tilesetB.tiles)
end)

test('a cached resolution still reflects the firstgid passed on that call', function()
	local readFile = fakeReader(GENERIC_PLATFORMER_TILES_TSX)

	ExternalTileset.resolve('res/tilesets/cache_test_d.tsx', 1, { readFile = readFile })
	local second = ExternalTileset.resolve('res/tilesets/cache_test_d.tsx', 50, { readFile = readFile })

	assertEqual(50, second.firstgid)
end)

test('raises a clear error naming the file when the tsx is malformed', function()
	local ok, err = pcall(function()
		ExternalTileset.resolve('res/tilesets/broken.tsx', 1, {
			readFile = fakeReader('<tileset><image></tileset>'),
		})
	end)

	assertEqual(false, ok)
	assertTrue(string.find(tostring(err), 'res/tilesets/broken.tsx', 1, true) ~= nil,
		'expected error to mention the broken file path, got: ' .. tostring(err))
end)
