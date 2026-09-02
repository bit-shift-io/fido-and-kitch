-- Serialises the generator's in-memory level description into a .tmj JSON
-- string that opens in Tiled and loads directly in the game (src/map/tmj.lua
-- parses .tmj without any Tiled-side export step).
local TmjWriter = {}

package.path = package.path .. ";lib/?.lua"
local json = require("dkjson")

local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function packUint32LE(n)
	return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end

local function base64Encode(data)
	local out = {}
	for i = 1, #data, 3 do
		local b1, b2, b3 = data:byte(i, i + 2)
		local hasB2 = b2 ~= nil
		local hasB3 = b3 ~= nil
		b2 = b2 or 0
		b3 = b3 or 0
		local n = b1 * 65536 + b2 * 256 + b3
		local c1 = math.floor(n / 262144) % 64
		local c2 = math.floor(n / 4096) % 64
		local c3 = math.floor(n / 64) % 64
		local c4 = n % 64
		out[#out + 1] = B64_CHARS:sub(c1 + 1, c1 + 1)
		out[#out + 1] = B64_CHARS:sub(c2 + 1, c2 + 1)
		out[#out + 1] = hasB2 and B64_CHARS:sub(c3 + 1, c3 + 1) or "="
		out[#out + 1] = hasB3 and B64_CHARS:sub(c4 + 1, c4 + 1) or "="
	end
	return table.concat(out)
end

local function encodeTileData(rows)
	local bytes = {}
	for _, row in ipairs(rows) do
		for _, gid in ipairs(row) do
			bytes[#bytes + 1] = packUint32LE(gid)
		end
	end
	return base64Encode(table.concat(bytes))
end

local function writeProperties(properties)
	if not properties or #properties == 0 then
		return nil
	end
	local props = {}
	for _, prop in ipairs(properties) do
		local p = { name = prop.name, value = prop.value }
		if prop.type and prop.type ~= "string" then
			p.type = prop.type
		end
		table.insert(props, p)
	end
	return props
end

local function writeTileLayer(layer)
	return {
		id = layer.id,
		name = layer.name,
		width = layer.width,
		height = layer.height,
		type = "tilelayer",
		visible = true,
		opacity = 1,
		offsetx = 0,
		offsety = 0,
		parallaxx = 1,
		parallaxy = 1,
		properties = writeProperties(layer.properties),
		encoding = "base64",
		compression = "",
		data = encodeTileData(layer.data),
	}
end

local function writeObject(object)
	local obj = {
		id = object.id,
		name = object.name or "",
		type = object.type or "",
		x = object.x,
		y = object.y,
		visible = true,
		rotation = 0,
		properties = writeProperties(object.properties) or {},
	}
	if object.width then
		obj.width = object.width
	end
	if object.height then
		obj.height = object.height
	end
	if object.gid then
		obj.gid = object.gid
	end
	if object.template then
		obj.template = object.template
	end
	if object.polyline then
		obj.shape = "polyline"
		obj.polyline = object.polyline
	else
		obj.shape = "rectangle"
	end
	return obj
end

local function writeObjectGroup(layer)
	return {
		id = layer.id,
		name = layer.name,
		type = "objectgroup",
		visible = true,
		opacity = 1,
		offsetx = 0,
		offsety = 0,
		parallaxx = 1,
		parallaxy = 1,
		draworder = "topdown",
		properties = writeProperties(layer.properties),
		objects = {},
	}
end

local function writeLayer(layer)
	if layer.type == "tilelayer" then
		return writeTileLayer(layer)
	elseif layer.type == "objectgroup" then
		local group = writeObjectGroup(layer)
		for _, object in ipairs(layer.objects or {}) do
			table.insert(group.objects, writeObject(object))
		end
		return group
	else
		error('TmjWriter: unsupported layer type "' .. tostring(layer.type) .. '"')
	end
end

--- Serialises a level description table into a .tmj JSON string.
-- @param map { width, height, tilewidth, tileheight, properties, tilesets, layers, nextobjectid }
function TmjWriter.write(map)
	local tmj = {
		compressionlevel = -1,
		height = map.height,
		infinite = false,
		nextlayerid = #map.layers + 1,
		nextobjectid = map.nextobjectid or 1,
		orientation = "orthogonal",
		renderorder = "right-down",
		tiledversion = "1.12.2",
		tileheight = map.tileheight,
		tilesets = {},
		tilewidth = map.tilewidth,
		type = "map",
		version = "1.11",
		width = map.width,
		properties = writeProperties(map.properties),
		layers = {},
	}

	for _, tileset in ipairs(map.tilesets) do
		table.insert(tmj.tilesets, {
			firstgid = tileset.firstgid,
			source = tileset.source,
		})
	end

	for _, layer in ipairs(map.layers) do
		table.insert(tmj.layers, writeLayer(layer))
	end

	return json.encode(tmj)
end

return TmjWriter
