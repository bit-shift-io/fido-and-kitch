-- Serialises the generator's in-memory level description into a .tmx XML
-- string that opens in Tiled and loads directly in the game (src/map/tmx.lua
-- parses .tmx without any Tiled-side export step).
local TmxWriter = {}

local B64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function packUint32LE(n)
	return string.char(
		n % 256,
		math.floor(n / 256) % 256,
		math.floor(n / 65536) % 256,
		math.floor(n / 16777216) % 256
	)
end

-- Standard base64 (Tiled's uncompressed tile-layer encoding: raw bytes, no
-- zlib/gzip -- see src/map/tmx.lua's parseTileLayer, which only accepts
-- base64 and treats a missing compression attribute as uncompressed).
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
		out[#out + 1] = hasB2 and B64_CHARS:sub(c3 + 1, c3 + 1) or '='
		out[#out + 1] = hasB3 and B64_CHARS:sub(c4 + 1, c4 + 1) or '='
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

local function escapeXml(s)
	s = tostring(s)
	s = s:gsub('&', '&amp;')
	s = s:gsub('<', '&lt;')
	s = s:gsub('>', '&gt;')
	s = s:gsub('"', '&quot;')
	return s
end

local function propertyTypeAttr(propType)
	if propType == nil or propType == 'string' then
		return ''
	end
	return string.format(' type="%s"', propType)
end

local function writeProperties(out, properties)
	if not properties or #properties == 0 then
		return
	end
	out[#out + 1] = ' <properties>\n'
	for _, prop in ipairs(properties) do
		out[#out + 1] = string.format(
			'  <property name="%s"%s value="%s"/>\n',
			escapeXml(prop.name), propertyTypeAttr(prop.type), escapeXml(prop.value)
		)
	end
	out[#out + 1] = ' </properties>\n'
end

local function writeTileLayer(out, layer)
	out[#out + 1] = string.format(
		'<layer id="%d" name="%s" width="%d" height="%d">\n',
		layer.id, escapeXml(layer.name), layer.width, layer.height
	)
	writeProperties(out, layer.properties)
	out[#out + 1] = '<data encoding="base64">\n'
	out[#out + 1] = encodeTileData(layer.data)
	out[#out + 1] = '\n</data>\n'
	out[#out + 1] = '</layer>\n'
end

local function writeObject(out, object)
	local attrs = string.format('id="%d"', object.id)
	if object.name then
		attrs = attrs .. string.format(' name="%s"', escapeXml(object.name))
	end
	if object.type then
		attrs = attrs .. string.format(' type="%s"', escapeXml(object.type))
	end
	if object.template then
		attrs = attrs .. string.format(' template="%s"', escapeXml(object.template))
	end
	attrs = attrs .. string.format(' x="%s" y="%s"', tostring(object.x), tostring(object.y))
	if object.width then
		attrs = attrs .. string.format(' width="%s"', tostring(object.width))
	end
	if object.height then
		attrs = attrs .. string.format(' height="%s"', tostring(object.height))
	end

	local hasProperties = object.properties and #object.properties > 0
	local hasPolyline = object.polyline and #object.polyline > 0

	if hasProperties or hasPolyline then
		out[#out + 1] = string.format('<object %s>\n', attrs)
		writeProperties(out, object.properties)
		if hasPolyline then
			local points = {}
			for _, point in ipairs(object.polyline) do
				points[#points + 1] = string.format('%s,%s', tostring(point.x), tostring(point.y))
			end
			out[#out + 1] = string.format('<polyline points="%s"/>\n', table.concat(points, ' '))
		end
		out[#out + 1] = '</object>\n'
	else
		out[#out + 1] = string.format('<object %s/>\n', attrs)
	end
end

local function writeObjectGroup(out, layer)
	out[#out + 1] = string.format(
		'<objectgroup id="%d" name="%s">\n',
		layer.id, escapeXml(layer.name)
	)
	writeProperties(out, layer.properties)
	for _, object in ipairs(layer.objects or {}) do
		writeObject(out, object)
	end
	out[#out + 1] = '</objectgroup>\n'
end

local function writeLayer(out, layer)
	if layer.type == 'tilelayer' then
		writeTileLayer(out, layer)
	elseif layer.type == 'objectgroup' then
		writeObjectGroup(out, layer)
	else
		error('TmxWriter: unsupported layer type "' .. tostring(layer.type) .. '"')
	end
end

--- Serialises a level description table into a .tmx XML string.
-- @param map { width, height, tilewidth, tileheight, properties, tilesets, layers, nextobjectid }
function TmxWriter.write(map)
	local out = {}
	out[#out + 1] = '<?xml version="1.0" encoding="UTF-8"?>\n'
	out[#out + 1] = string.format(
		'<map version="1.10" tiledversion="1.12.2" orientation="orthogonal" renderorder="right-down" '
			.. 'width="%d" height="%d" tilewidth="%d" tileheight="%d" infinite="0" '
			.. 'nextlayerid="%d" nextobjectid="%d">\n',
		map.width, map.height, map.tilewidth, map.tileheight,
		#map.layers + 1, map.nextobjectid or 1
	)
	writeProperties(out, map.properties)
	for _, tileset in ipairs(map.tilesets) do
		out[#out + 1] = string.format(
			'<tileset firstgid="%d" source="%s"/>\n', tileset.firstgid, escapeXml(tileset.source)
		)
	end
	for _, layer in ipairs(map.layers) do
		writeLayer(out, layer)
	end
	out[#out + 1] = '</map>\n'
	return table.concat(out)
end

return TmxWriter
