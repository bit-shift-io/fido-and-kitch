-- File-typed (Tiled "file" property type) object properties carry image/asset
-- paths authored relative to their file: template props are relative to the
-- .tj's directory, instance props to the map's directory. Both must be
-- converted to project-root-relative runtime paths at load (same lexing as
-- stiUtils.format_path already applies to tileset images).
local TjTemplate = require("src.map.tj_template")
local Tmj = require("src.map.tmj")

local KEY_TJ = [[{
  "type": "template",
  "name": "key",
  "object": {
    "id": 1,
    "name": "Key",
    "type": "key",
    "gid": 1,
    "width": 32,
    "height": 32,
    "rotation": 0,
    "properties": [
      { "name": "image", "type": "file", "value": "../img/entity_key.png" },
      { "name": "frames", "type": "int", "value": 1 },
      { "name": "color", "type": "string", "value": "yellow" }
    ]
  }
}]]

local INSTANCE_MAP = [[{
  "type": "map",
  "version": "1.10",
  "tiledversion": "1.12.2",
  "orientation": "orthogonal",
  "renderorder": "right-down",
  "width": 10,
  "height": 10,
  "tilewidth": 32,
  "tileheight": 32,
  "nextlayerid": 2,
  "nextobjectid": 2,
  "tilesets": [],
  "layers": [
    {
      "id": 1,
      "name": "entities",
      "type": "objectgroup",
      "draworder": "topdown",
      "opacity": 1,
      "visible": true,
      "x": 0,
      "y": 0,
      "objects": [
        {
          "id": 1,
          "name": "Cage",
          "type": "cage",
          "x": 64,
          "y": 64,
          "width": 32,
          "height": 32,
          "properties": [
            { "name": "image", "type": "file", "value": "../img/cage/cage.png" },
            { "name": "spawn_type", "type": "string", "value": "bird" },
            { "name": "dest_x", "type": "int", "value": 160 }
          ]
        }
      ]
    }
  ]
}]]

-- A template whose `image` file prop has been removed: art lives only in the
-- inline tileset tile the editor previews. The loader must inject that tile
-- image into the merged properties so entity sprites still get a texture.
local TILESET_ART_TJ = [[{
  "type": "template",
  "name": "teleport",
  "tileset": {
    "firstgid": 1,
    "tilewidth": 512,
    "name": "teleport",
    "version": "1.11",
    "columns": 0,
    "tilecount": 1,
    "tiles": [
      { "image": "../img/entity_teleporter.png", "id": 0, "imagewidth": 512, "imageheight": 512 }
    ]
  },
  "object": {
    "id": 1,
    "name": "Teleporter",
    "type": "teleport",
    "gid": 1,
    "width": 64,
    "height": 64,
    "properties": [
      { "name": "frames", "type": "int", "value": 1 },
      { "name": "target", "type": "object", "value": "28" }
    ]
  }
}]]

local INSTANCE_MAP_TILESET_ART = [[{
  "type": "map",
  "version": "1.10",
  "tiledversion": "1.12.2",
  "orientation": "orthogonal",
  "renderorder": "right-down",
  "width": 10,
  "height": 10,
  "tilewidth": 32,
  "tileheight": 32,
  "nextlayerid": 2,
  "nextobjectid": 2,
  "tilesets": [],
  "layers": [
    {
      "id": 1,
      "name": "entities",
      "type": "objectgroup",
      "draworder": "topdown",
      "opacity": 1,
      "visible": true,
      "x": 0,
      "y": 0,
      "objects": [
        {
          "id": 5,
          "name": "Teleporter",
          "template": "templates/teleport_test.tj",
          "type": "teleport",
          "x": 64,
          "y": 64
        }
      ]
    }
  ]
}]]

local function fakeReader(contents)
	return function(path)
		return contents
	end
end

test("template file props are resolved relative to the template directory", function()
	-- Fake content cached under this path -- it intentionally plays no real
	-- template's identity (a stub asserting template-file-prop conversion must
	-- not shadow res/entities/key.tj inside the process-wide resolve cache).
	local template = TjTemplate.resolve("res/entities/key_fake_test.tj", {
		readFile = fakeReader(KEY_TJ),
	})

	local byName = {}
	for _, prop in ipairs(template.object.properties) do
		byName[prop.name] = prop
	end

	assertEqual("res/img/entity_key.png", byName.image.value)
	assertEqual(1, byName.frames.value)
	assertEqual("yellow", byName.color.value)
end)

test("template file-prop conversion happens once per cached path", function()
	local readCount = 0
	local readFile = function(path)
		readCount = readCount + 1
		return KEY_TJ
	end

	TjTemplate.resolve("res/entities/key_cache_test.tj", { readFile = readFile })
	local cached = TjTemplate.resolve("res/entities/key_cache_test.tj", { readFile = readFile })

	assertEqual(1, readCount)
	local image
	for _, prop in ipairs(cached.object.properties) do
		if prop.name == "image" then
			image = prop.value
		end
	end
	assertEqual("res/img/entity_key.png", image)
end)

test("map instance file props are resolved relative to the map directory", function()
	local tmpDir = "tests/unit/_tmptmp"
	local tmpFile = tmpDir .. "/fileprops.tmj"
	os.execute("mkdir -p " .. tmpDir)
	local file = assert(io.open(tmpFile, "w"))
	file:write(INSTANCE_MAP)
	file:close()

	local map = Tmj.parse(tmpFile)

	local obj = map.layers[1].objects[1]
	assertEqual("tests/unit/img/cage/cage.png", obj.properties.image)
	assertEqual("bird", obj.properties.spawn_type)
	assertEqual(160, obj.properties.dest_x)

	os.remove(tmpFile)
	os.execute("rmdir " .. tmpDir .. " 2>/dev/null")
end)

test("instance without an image prop inherits art from the template tileset tile", function()
	local tmpDir = "tests/unit/_tmptmp"
	local tmplDir = tmpDir .. "/templates"
	local tmpFile = tmpDir .. "/tilesetart.tmj"
	os.execute("mkdir -p " .. tmplDir)
	local tf = assert(io.open(tmplDir .. "/teleport_test.tj", "w"))
	tf:write(TILESET_ART_TJ)
	tf:close()
	local file = assert(io.open(tmpFile, "w"))
	file:write(INSTANCE_MAP_TILESET_ART)
	file:close()

	local map = Tmj.parse(tmpFile)

	local obj = map.layers[1].objects[1]
	assertEqual(1, obj.properties.frames)
	assertEqual(28, obj.properties.target.id)
	assertEqual(
		"tests/unit/_tmptmp/img/entity_teleporter.png",
		obj.properties.image,
		"tile art injected into merged props"
	)

	os.remove(tmpFile)
	os.remove(tmplDir .. "/teleport_test.tj")
	os.execute("rmdir " .. tmplDir .. " 2>/dev/null")
	os.execute("rmdir " .. tmpDir .. " 2>/dev/null")
end)
