-- Unit tests for the .tmx parser (src/map/tmx.lua). Mirrors
-- tests/unit/external_tileset_test.lua's pattern: literal XML strings, an
-- injectable file reader, no filesystem or love.* dependency. See
-- .scratch/tmx-direct-loading/PRD.md and DECISIONS.md for the shape
-- contract this is pinned against.
local Tmx = require('src.map.tmx')

local TILESET_TSX = [[<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.5" tiledversion="1.7.2" name="generic_platformer_tiles" tilewidth="32" tileheight="32" tilecount="144" columns="8">
 <image source="../img/generic_platformer_tiles.png" width="256" height="576"/>
</tileset>
]]

local function multiReader(filesByPath)
	return function(path)
		return filesByPath[path]
	end
end

-- A minimal but structurally real fixture: map attributes, all supported
-- property types on the map and on a layer, an external tileset, and one
-- base64 tile layer -- built from the shape of res/map/ll1.tmx and
-- res/editor/tileset_generic_platformer_tiles.tsx rather than invented from
-- scratch, per the planning docs.
local BASIC_MAP_TMX = [[<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.12.2" orientation="orthogonal" renderorder="right-down" width="4" height="3" tilewidth="32" tileheight="32" infinite="0" nextlayerid="2" nextobjectid="1">
 <properties>
  <property name="background" value="mushroom_cave"/>
  <property name="isBoss" type="bool" value="true"/>
  <property name="lives" type="int" value="3"/>
  <property name="gravity" type="float" value="9.8"/>
  <property name="icon" type="file" value="../img/icon.png"/>
  <property name="tint" type="color" value="#ff0000ff"/>
 </properties>
 <tileset firstgid="1" source="../tilesets/generic_platformer_tiles.tsx"/>
 <layer id="1" name="ground" width="4" height="3">
  <properties>
   <property name="collision" type="bool" value="true"/>
  </properties>
  <data encoding="base64">
   AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  </data>
 </layer>
</map>
]]

local function parseBasicMap()
	return Tmx.parse('tests/fixtures/tmx/basic_map.tmx', {
		readFile = multiReader({
			['tests/fixtures/tmx/basic_map.tmx'] = BASIC_MAP_TMX,
			['tests/fixtures/tilesets/generic_platformer_tiles.tsx'] = TILESET_TSX,
		}),
	})
end

test('parses map attributes, including the ones the exporter synthesises', function()
	local map = parseBasicMap()

	assertEqual('1.10', map.version)
	assertEqual('5.1', map.luaversion)
	assertEqual('1.12.2', map.tiledversion)
	assertEqual('', map.class)
	assertEqual('orthogonal', map.orientation)
	assertEqual('right-down', map.renderorder)
	assertEqual(4, map.width)
	assertEqual(3, map.height)
	assertEqual(32, map.tilewidth)
	assertEqual(32, map.tileheight)
	assertEqual(2, map.nextlayerid)
	assertEqual(1, map.nextobjectid)
end)

test('coerces every supported map property type to the value the exporter would produce', function()
	local map = parseBasicMap()

	assertEqual('mushroom_cave', map.properties.background)
	assertEqual(true, map.properties.isBoss)
	assertEqual(3, map.properties.lives)
	assertNear(9.8, map.properties.gravity)
	assertEqual('../img/icon.png', map.properties.icon)
	assertEqual('#ff0000ff', map.properties.tint)
end)

test('coerces a layer bool property', function()
	local map = parseBasicMap()
	assertEqual(true, map.layers[1].properties.collision)
end)

test('resolves the external tileset reference with a name, firstgid and project-root-relative filename', function()
	local map = parseBasicMap()

	assertEqual(1, #map.tilesets)
	assertEqual('generic_platformer_tiles', map.tilesets[1].name)
	assertEqual(1, map.tilesets[1].firstgid)
	assertEqual('tests/fixtures/tilesets/generic_platformer_tiles.tsx', map.tilesets[1].filename)
end)

test('a tile layer\'s data is emitted still base64-encoded, not decoded', function()
	local map = parseBasicMap()
	local layer = map.layers[1]

	assertEqual('tilelayer', layer.type)
	assertEqual('base64', layer.encoding)
	assertEqual(nil, layer.compression)
	assertTrue(layer.data:match('^%s*AAAA') ~= nil, 'expected data to still be the base64 string')
end)

test('materialises values Tiled omits from XML to the exporter\'s defaults', function()
	local map = parseBasicMap()
	local layer = map.layers[1]

	assertEqual(0, layer.offsetx)
	assertEqual(0, layer.offsety)
	assertEqual(1, layer.parallaxx)
	assertEqual(1, layer.parallaxy)
	assertEqual(1, layer.opacity)
	assertEqual(true, layer.visible)
	assertEqual('', layer.class)
	assertEqual(0, layer.x)
	assertEqual(0, layer.y)
	assertEqual(4, layer.width)
	assertEqual(3, layer.height)
end)

test('raises a clear error naming the file when the .tmx cannot be read', function()
	local ok, err = pcall(function()
		Tmx.parse('tests/fixtures/tmx/missing.tmx', { readFile = function() return nil end })
	end)

	assertEqual(false, ok)
	assertTrue(string.find(tostring(err), 'tests/fixtures/tmx/missing.tmx', 1, true) ~= nil,
		'expected error to mention the missing file, got: ' .. tostring(err))
end)

test('raises a clear error naming the file when the .tmx is malformed', function()
	local ok, err = pcall(function()
		Tmx.parse('tests/fixtures/tmx/broken.tmx', {
			readFile = multiReader({ ['tests/fixtures/tmx/broken.tmx'] = '<map><layer></map>' }),
		})
	end)

	assertEqual(false, ok)
	assertTrue(string.find(tostring(err), 'tests/fixtures/tmx/broken.tmx', 1, true) ~= nil,
		'expected error to mention the broken file, got: ' .. tostring(err))
end)

test('raises a clear error naming the file and construct for CSV-encoded tile data', function()
	local csvMap = BASIC_MAP_TMX:gsub('encoding="base64"', 'encoding="csv"')
	local ok, err = pcall(function()
		Tmx.parse('tests/fixtures/tmx/csv_map.tmx', {
			readFile = multiReader({
				['tests/fixtures/tmx/csv_map.tmx'] = csvMap,
				['tests/fixtures/tilesets/generic_platformer_tiles.tsx'] = TILESET_TSX,
			}),
		})
	end)

	assertEqual(false, ok)
	assertTrue(string.find(tostring(err), 'tests/fixtures/tmx/csv_map.tmx', 1, true) ~= nil, tostring(err))
	assertTrue(string.find(tostring(err), 'csv', 1, true) ~= nil, tostring(err))
end)

test('raises a clear error naming the file for an infinite/chunked map', function()
	local infiniteMap = BASIC_MAP_TMX:gsub('infinite="0"', 'infinite="1"')
	local ok, err = pcall(function()
		Tmx.parse('tests/fixtures/tmx/infinite_map.tmx', {
			readFile = multiReader({
				['tests/fixtures/tmx/infinite_map.tmx'] = infiniteMap,
				['tests/fixtures/tilesets/generic_platformer_tiles.tsx'] = TILESET_TSX,
			}),
		})
	end)

	assertEqual(false, ok)
	assertTrue(string.find(tostring(err), 'tests/fixtures/tmx/infinite_map.tmx', 1, true) ~= nil, tostring(err))
end)

test('raises a clear error naming the file and construct for an unrecognised layer type', function()
	local weirdMap = BASIC_MAP_TMX:gsub(
		'<layer id="1" name="ground" width="4" height="3">.-</layer>',
		'<futurelayer id="1" name="ground"/>'
	)
	local ok, err = pcall(function()
		Tmx.parse('tests/fixtures/tmx/weird_map.tmx', {
			readFile = multiReader({
				['tests/fixtures/tmx/weird_map.tmx'] = weirdMap,
				['tests/fixtures/tilesets/generic_platformer_tiles.tsx'] = TILESET_TSX,
			}),
		})
	end)

	assertEqual(false, ok)
	assertTrue(string.find(tostring(err), 'futurelayer', 1, true) ~= nil, tostring(err))
end)

test('raises a clear error naming the file for an embedded (non-external) tileset', function()
	local embeddedMap = BASIC_MAP_TMX:gsub(
		'<tileset firstgid="1" source="../tilesets/generic_platformer_tiles.tsx"/>',
		'<tileset firstgid="1" name="inline" tilewidth="32" tileheight="32"><image source="x.png" width="32" height="32"/></tileset>'
	)
	local ok, err = pcall(function()
		Tmx.parse('tests/fixtures/tmx/embedded_tileset_map.tmx', {
			readFile = multiReader({ ['tests/fixtures/tmx/embedded_tileset_map.tmx'] = embeddedMap }),
		})
	end)

	assertEqual(false, ok)
	assertTrue(string.find(tostring(err), 'embedded_tileset_map.tmx', 1, true) ~= nil, tostring(err))
end)

-- Object layers and shapes (issue 02) -----------------------------------

local OBJECT_LAYER_TMX = [[<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.12.2" orientation="orthogonal" renderorder="right-down" width="4" height="3" tilewidth="32" tileheight="32" infinite="0" nextlayerid="2" nextobjectid="10">
 <objectgroup id="1" name="game">
  <object id="1" name="spawn" type="spawn" gid="5" x="64" y="96" width="32" height="32">
   <properties>
    <property name="color" value="red"/>
    <property name="target" type="object" value="9"/>
   </properties>
  </object>
  <object id="2" name="waypoint" x="10" y="20">
   <polyline points="0,0 32,-16 64,0"/>
  </object>
  <object id="3" name="area" x="0" y="0">
   <polygon points="0,0 32,0 32,32 0,32"/>
  </object>
  <object id="4" name="round" x="5" y="5" width="16" height="16">
   <ellipse/>
  </object>
  <object id="5" name="marker" x="8" y="8">
   <point/>
  </object>
 </objectgroup>
</map>
]]

local function parseObjectLayer()
	return Tmx.parse('tests/fixtures/tmx/object_layer.tmx', {
		readFile = multiReader({ ['tests/fixtures/tmx/object_layer.tmx'] = OBJECT_LAYER_TMX }),
	})
end

test('a rectangle (tile) object carries its gid, name, type and merged properties', function()
	local map = parseObjectLayer()
	local layer = map.layers[1]

	assertEqual('objectgroup', layer.type)
	assertEqual('topdown', layer.draworder)

	local spawn = layer.objects[1]
	assertEqual(1, spawn.id)
	assertEqual('spawn', spawn.name)
	assertEqual('spawn', spawn.type)
	assertEqual('rectangle', spawn.shape)
	assertEqual(64, spawn.x)
	assertEqual(96, spawn.y)
	assertEqual(32, spawn.width)
	assertEqual(32, spawn.height)
	assertEqual(5, spawn.gid)
	assertEqual('red', spawn.properties.color)
	assertEqual(9, spawn.properties.target.id)
end)

test('a polyline object carries its points relative to the object origin', function()
	local map = parseObjectLayer()
	local waypoint = map.layers[1].objects[2]

	assertEqual('polyline', waypoint.shape)
	assertEqual(nil, waypoint.gid)
	assertEqual(3, #waypoint.polyline)
	assertEqual(0, waypoint.polyline[1].x)
	assertEqual(0, waypoint.polyline[1].y)
	assertEqual(32, waypoint.polyline[2].x)
	assertEqual(-16, waypoint.polyline[2].y)
end)

test('a polygon object carries its points under the polygon key', function()
	local map = parseObjectLayer()
	local area = map.layers[1].objects[3]

	assertEqual('polygon', area.shape)
	assertEqual(4, #area.polygon)
	assertEqual(32, area.polygon[3].x)
	assertEqual(32, area.polygon[3].y)
end)

test('an ellipse object is recognised by its shape', function()
	local map = parseObjectLayer()
	assertEqual('ellipse', map.layers[1].objects[4].shape)
end)

test('a point object is recognised by its shape', function()
	local map = parseObjectLayer()
	assertEqual('point', map.layers[1].objects[5].shape)
end)

-- Image layers (issue 03) -------------------------------------------------

local IMAGE_LAYER_TMX = [[<?xml version="1.0" encoding="UTF-8"?>
<map version="1.11" tiledversion="1.12.2" orientation="orthogonal" renderorder="right-down" width="30" height="20" tilewidth="32" tileheight="32" infinite="0" nextlayerid="3" nextobjectid="1">
 <imagelayer id="2" name="sky" offsetx="0" offsety="-200" parallaxx="0" parallaxy="0" repeatx="true" repeaty="false">
  <image source="../img/backgrounds/background_night_sky.png" width="1207" height="161"/>
 </imagelayer>
</map>
]]

test('an image layer resolves its image to a project-root-relative path and carries repeat/parallax/offset', function()
	local map = Tmx.parse('tests/fixtures/tmx/image_layer.tmx', {
		readFile = multiReader({ ['tests/fixtures/tmx/image_layer.tmx'] = IMAGE_LAYER_TMX }),
	})

	assertEqual(0, #map.tilesets)
	local layer = map.layers[1]
	assertEqual('imagelayer', layer.type)
	assertEqual('tests/fixtures/img/backgrounds/background_night_sky.png', layer.image)
	assertEqual(0, layer.offsetx)
	assertEqual(-200, layer.offsety)
	assertEqual(0, layer.parallaxx)
	assertEqual(0, layer.parallaxy)
	assertEqual(true, layer.repeatx)
	assertEqual(false, layer.repeaty)
end)

-- Group layers (issue 05) --------------------------------------------------

local GROUP_LAYER_TMX = [[<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.12.2" orientation="orthogonal" renderorder="right-down" width="4" height="3" tilewidth="32" tileheight="32" infinite="0" nextlayerid="4" nextobjectid="3">
 <group id="1" name="decor" offsetx="10" offsety="20">
  <objectgroup id="2" name="inner">
   <object id="1" name="a" x="0" y="0" width="4" height="4"/>
  </objectgroup>
  <objectgroup id="3" name="inner2">
   <object id="2" name="b" x="1" y="1" width="4" height="4"/>
  </objectgroup>
 </group>
</map>
]]

test('a group layer is emitted with its own nested layers array, unflattened', function()
	local map = Tmx.parse('tests/fixtures/tmx/group_layer.tmx', {
		readFile = multiReader({ ['tests/fixtures/tmx/group_layer.tmx'] = GROUP_LAYER_TMX }),
	})

	assertEqual(1, #map.layers)
	local group = map.layers[1]
	assertEqual('group', group.type)
	assertEqual('decor', group.name)
	assertEqual(10, group.offsetx)
	assertEqual(20, group.offsety)
	assertEqual(2, #group.layers)
	assertEqual('inner', group.layers[1].name)
	assertEqual('inner2', group.layers[2].name)
end)
