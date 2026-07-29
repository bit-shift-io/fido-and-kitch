-- Unit tests for object template resolution (issue 04): inheritance,
-- property merging, tile-numbering remap and tileset auto-registration.
-- See CONTEXT.md's "Object template" entry and DECISIONS.md Q5/Q6.
local Tmx = require('src.map.tmx')

local PROPS_TSX = [[<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.11" tiledversion="1.12.2" name="props" tilewidth="32" tileheight="32" tilecount="11" columns="0">
 <tile id="0"><image source="../img/default.png" width="32" height="32"/></tile>
</tileset>
]]

local GENERIC_TSX = [[<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.5" tiledversion="1.7.2" name="generic_platformer_tiles" tilewidth="32" tileheight="32" tilecount="144" columns="8">
 <image source="../img/generic_platformer_tiles.png" width="256" height="576"/>
</tileset>
]]

local SPAWN_TX = [[<?xml version="1.0" encoding="UTF-8"?>
<template>
 <tileset firstgid="1" source="../tilesets/props.tsx"/>
 <object name="spawn" type="spawn" gid="1" width="32" height="32"/>
</template>
]]

local CAGE_TX = [[<?xml version="1.0" encoding="UTF-8"?>
<template>
 <tileset firstgid="1" source="../tilesets/props.tsx"/>
 <object name="cage" type="cage" gid="10" width="32" height="32">
  <properties>
   <property name="color" value="red"/>
  </properties>
 </object>
</template>
]]

local function multiReader(filesByPath)
	return function(path)
		return filesByPath[path]
	end
end

local function readerWithTemplates()
	return multiReader({
		['tests/fixtures/tilesets/props.tsx'] = PROPS_TSX,
		['tests/fixtures/tilesets/generic_platformer_tiles.tsx'] = GENERIC_TSX,
		['tests/fixtures/templates/spawn.tx'] = SPAWN_TX,
		['tests/fixtures/templates/cage.tx'] = CAGE_TX,
	})
end

local function mapXml(objectsXml, declareGeneric)
	local tilesetTag = declareGeneric
		and '<tileset firstgid="1" source="../tilesets/generic_platformer_tiles.tsx"/>'
		or ''
	return ([[<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.12.2" orientation="orthogonal" renderorder="right-down" width="4" height="3" tilewidth="32" tileheight="32" infinite="0" nextlayerid="2" nextobjectid="10">
 %s
 <objectgroup id="1" name="game">
  %s
 </objectgroup>
</map>
]]):format(tilesetTag, objectsXml)
end

test('an instance placed from a template inherits its name, type, gid and properties', function()
	local map = Tmx.parse('tests/fixtures/tmx/spawn_map.tmx', {
		readFile = function(path)
			if path == 'tests/fixtures/tmx/spawn_map.tmx' then
				return mapXml('<object id="1" template="../templates/spawn.tx" x="96" y="192"/>', true)
			end
			return readerWithTemplates()(path)
		end,
	})

	local object = map.layers[1].objects[1]
	assertEqual('spawn', object.name)
	assertEqual('spawn', object.type)
	assertEqual(32, object.width)
	assertEqual(32, object.height)
	assertEqual(96, object.x)
	assertEqual(192, object.y)
end)

test('instance attributes override the template\'s, and properties merge with the instance winning', function()
	local map = Tmx.parse('tests/fixtures/tmx/cage_map.tmx', {
		readFile = function(path)
			if path == 'tests/fixtures/tmx/cage_map.tmx' then
				return mapXml(
					'<object id="1" template="../templates/cage.tx" name="blue_cage" x="0" y="0">'
					.. '<properties><property name="color" value="blue"/><property name="path" type="object" value="7"/></properties>'
					.. '</object>',
					true
				)
			end
			return readerWithTemplates()(path)
		end,
	})

	local object = map.layers[1].objects[1]
	assertEqual('blue_cage', object.name) -- instance overrides template's "cage"
	assertEqual('cage', object.type) -- inherited, not overridden
	assertEqual('blue', object.properties.color) -- instance wins the collision
	assertEqual(7, object.properties.path.id) -- instance-only property survives the merge
end)

test('a template\'s tile reference remaps from its own tileset numbering into the map\'s', function()
	-- generic_platformer_tiles (144 tiles) declared first, so props.tsx
	-- (also declared, at firstgid 145) offsets spawn.tx's gid=1 to 145 --
	-- matching DECISIONS.md Q5's verified formula.
	local map = Tmx.parse('tests/fixtures/tmx/spawn_map2.tmx', {
		readFile = function(path)
			if path == 'tests/fixtures/tmx/spawn_map2.tmx' then
				return ([[<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.12.2" orientation="orthogonal" renderorder="right-down" width="4" height="3" tilewidth="32" tileheight="32" infinite="0" nextlayerid="2" nextobjectid="10">
 <tileset firstgid="1" source="../tilesets/generic_platformer_tiles.tsx"/>
 <tileset firstgid="145" source="../tilesets/props.tsx"/>
 <objectgroup id="1" name="game">
  <object id="1" template="../templates/spawn.tx" x="0" y="0"/>
 </objectgroup>
</map>
]])
			end
			return readerWithTemplates()(path)
		end,
	})

	assertEqual(145, map.layers[1].objects[1].gid)
end)

test('a template referencing a tileset the map does not declare auto-registers it', function()
	local map = Tmx.parse('tests/fixtures/tmx/auto_register_map.tmx', {
		readFile = function(path)
			if path == 'tests/fixtures/tmx/auto_register_map.tmx' then
				return mapXml('<object id="1" template="../templates/spawn.tx" x="0" y="0"/>', true)
			end
			return readerWithTemplates()(path)
		end,
	})

	-- generic_platformer_tiles (144 tiles) is the only map-declared
	-- tileset; props.tsx (spawn.tx's tileset) isn't declared at all, so it
	-- must be auto-registered right after it, at firstgid 145.
	assertEqual(2, #map.tilesets)
	assertEqual('generic_platformer_tiles', map.tilesets[1].name)
	assertEqual(1, map.tilesets[1].firstgid)
	assertEqual('props', map.tilesets[2].name)
	assertEqual(145, map.tilesets[2].firstgid)
	assertEqual(145, map.layers[1].objects[1].gid)
end)

test('auto-registering the same undeclared tileset for two templates only adds it once', function()
	local map = Tmx.parse('tests/fixtures/tmx/two_templates_map.tmx', {
		readFile = function(path)
			if path == 'tests/fixtures/tmx/two_templates_map.tmx' then
				return mapXml(
					'<object id="1" template="../templates/spawn.tx" x="0" y="0"/>'
					.. '<object id="2" template="../templates/cage.tx" x="10" y="10"/>',
					true
				)
			end
			return readerWithTemplates()(path)
		end,
	})

	assertEqual(2, #map.tilesets)
	assertEqual(145, map.layers[1].objects[1].gid) -- spawn.tx gid 1 -> 145
	assertEqual(154, map.layers[1].objects[2].gid) -- cage.tx gid 10 -> 154
end)

test('both spellings of type/class are accepted on a template object', function()
	local classSpelledSpawnTx = SPAWN_TX:gsub('type="spawn"', 'class="spawn"')
	local map = Tmx.parse('tests/fixtures/tmx/class_spelling_map.tmx', {
		readFile = function(path)
			if path == 'tests/fixtures/tmx/class_spelling_map.tmx' then
				return mapXml('<object id="1" template="../templates/spawn.tx" x="0" y="0"/>', true)
			elseif path == 'tests/fixtures/templates/spawn.tx' then
				return classSpelledSpawnTx
			end
			return readerWithTemplates()(path)
		end,
	})

	assertEqual('spawn', map.layers[1].objects[1].type)
end)
