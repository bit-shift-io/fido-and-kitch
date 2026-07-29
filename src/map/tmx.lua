-- Parses a Tiled .tmx map directly into the table structure Tiled's Lua
-- export plugin emits, so the vendored map loader (lib/sti) needs no
-- changes to consume it. See docs/adr/0004-direct-tmx-loading.md for why,
-- and .scratch/tmx-direct-loading/DECISIONS.md for the field-by-field
-- verification this shape is checked against.
--
-- Tile layer data is emitted still base64-encoded (with its encoding
-- marker) rather than decoded, because the loader already decodes exactly
-- that form; values Tiled omits from XML when they equal a default are
-- materialised here to the defaults the exporter writes, because
-- downstream code reads them unconditionally.
local TmxXml = require('src.map.tmx_xml')
local TmxTemplate = require('src.map.tmx_template')
local ExternalTileset = require('src.map.external_tileset')

local Tmx = {}

local LAYER_TAGS = { layer = true, objectgroup = true, imagelayer = true, group = true }
local KNOWN_NON_LAYER_MAP_CHILDREN = { properties = true, tileset = true, editorsettings = true }

local function isLayerTag(name)
	return LAYER_TAGS[name] == true
end

-- Tracks, for one map parse, which .tsx paths are already registered on
-- `tilesets` and at what firstgid -- both the map's own declared tilesets
-- and any a template auto-registers (DECISIONS.md Q6). `nextFirstgid` is
-- where the *next* auto-registered tileset would be allocated: one past
-- the highest gid any currently-registered tileset occupies.
local function newTilesetAllocator(tilesets)
	return { tilesets = tilesets, byPath = {}, nextFirstgid = 1 }
end

local function declareTileset(allocator, tsxPath, firstgid, tilecount)
	allocator.byPath[tsxPath] = firstgid
	local afterThisTileset = firstgid + tilecount
	if afterThisTileset > allocator.nextFirstgid then
		allocator.nextFirstgid = afterThisTileset
	end
end

--- The firstgid a map-local reference to `tsxPath` should use: its declared
-- one if the map already lists it, otherwise a newly allocated one -- which
-- auto-registers it onto `allocator.tilesets` so it renders like any other
-- tileset the map declares (this is what lets a template's tileset work
-- even when the map itself never mentions it).
local function firstgidFor(allocator, tsxPath, deps)
	local existing = allocator.byPath[tsxPath]
	if existing then
		return existing
	end

	local firstgid = allocator.nextFirstgid
	local resolved = ExternalTileset.resolve(tsxPath, firstgid, deps)
	table.insert(allocator.tilesets, { name = resolved.name, firstgid = firstgid, filename = tsxPath })
	declareTileset(allocator, tsxPath, firstgid, resolved.tilecount)
	return firstgid
end

local function parsePoints(pointsAttr)
	local points = {}
	for pair in pointsAttr:gmatch('%S+') do
		local x, y = pair:match('^(%-?[%d%.]+),(%-?[%d%.]+)$')
		table.insert(points, { x = tonumber(x), y = tonumber(y) })
	end
	return points
end

--- Returns the object's shape name and, for the point-list shapes, the key
-- to store its points under and the parsed points themselves.
local function parseObjectShape(objectNode, tmxPath, objectId)
	if TmxXml.child(objectNode, 'text') then
		error('Unsupported object shape "text" on object ' .. tostring(objectId) .. ' in "' .. tmxPath .. '"', 2)
	end

	local polygonNode = TmxXml.child(objectNode, 'polygon')
	if polygonNode then
		return 'polygon', 'polygon', parsePoints(TmxXml.attrs(polygonNode).points)
	end

	local polylineNode = TmxXml.child(objectNode, 'polyline')
	if polylineNode then
		return 'polyline', 'polyline', parsePoints(TmxXml.attrs(polylineNode).points)
	end

	if TmxXml.child(objectNode, 'ellipse') then
		return 'ellipse', nil, nil
	end

	if TmxXml.child(objectNode, 'point') then
		return 'point', nil, nil
	end

	return 'rectangle', nil, nil
end

local function parseObject(objectNode, mapDir, tmxPath, deps, allocator)
	local a = TmxXml.attrs(objectNode)

	-- An instance placed from a template inherits every attribute from the
	-- template's own <object>; anything present on the instance overrides
	-- it, and properties merge (instance wins on a name collision).
	local base = { properties = {} }
	local templateGid = nil

	if a.template then
		local templatePath = TmxXml.resolvePath(mapDir, a.template)
		local template = TmxTemplate.resolve(templatePath, deps)
		base = template.object

		if template.tilesetRef and base.gid then
			local mapFirstgid = firstgidFor(allocator, template.tilesetRef.path, deps)
			templateGid = base.gid - template.tilesetRef.firstgid + mapFirstgid
		end
	end

	local shape, shapeKey, points = parseObjectShape(objectNode, tmxPath, a.id)

	local object = {
		id = TmxXml.toNumber(a.id),
		name = a.name or base.name or '',
		type = TmxXml.typeOrClass(a, base.type or ''),
		shape = shape,
		x = TmxXml.toNumber(a.x, 0),
		y = TmxXml.toNumber(a.y, 0),
		width = TmxXml.toNumber(a.width, base.width or 0),
		height = TmxXml.toNumber(a.height, base.height or 0),
		rotation = TmxXml.toNumber(a.rotation, 0),
		opacity = TmxXml.toNumber(a.opacity, 1),
		visible = TmxXml.toBool(a.visible, true),
		properties = TmxXml.mergeProperties(base.properties, TmxXml.parseProperties(objectNode)),
	}

	local gid = TmxXml.toNumber(a.gid) or templateGid
	if gid then
		object.gid = gid
	end

	if shapeKey then
		object[shapeKey] = points
	end

	return object
end

local function parseCommonLayerFields(layerNode)
	local a = TmxXml.attrs(layerNode)
	return {
		id = TmxXml.toNumber(a.id),
		name = a.name or '',
		class = TmxXml.typeOrClass(a, ''),
		visible = TmxXml.toBool(a.visible, true),
		opacity = TmxXml.toNumber(a.opacity, 1),
		offsetx = TmxXml.toNumber(a.offsetx, 0),
		offsety = TmxXml.toNumber(a.offsety, 0),
		parallaxx = TmxXml.toNumber(a.parallaxx, 1),
		parallaxy = TmxXml.toNumber(a.parallaxy, 1),
		properties = TmxXml.parseProperties(layerNode),
	}
end

local function parseTileLayer(layerNode, tmxPath, mapWidth, mapHeight)
	local a = TmxXml.attrs(layerNode)
	local dataNode = TmxXml.child(layerNode, 'data')
	if not dataNode then
		error('Tile layer "' .. (a.name or '') .. '" in "' .. tmxPath .. '" has no <data>', 2)
	end

	local dataAttrs = TmxXml.attrs(dataNode)
	if dataAttrs.encoding == 'csv' or dataAttrs.encoding == nil then
		error('Unsupported tile layer encoding "' .. tostring(dataAttrs.encoding)
			.. '" on layer "' .. (a.name or '') .. '" in "' .. tmxPath .. '" (only base64 is supported)', 2)
	elseif dataAttrs.encoding ~= 'base64' then
		error('Unsupported tile layer encoding "' .. dataAttrs.encoding
			.. '" on layer "' .. (a.name or '') .. '" in "' .. tmxPath .. '" (only base64 is supported)', 2)
	end

	local layer = parseCommonLayerFields(layerNode)
	layer.type = 'tilelayer'
	layer.x = TmxXml.toNumber(a.x, 0)
	layer.y = TmxXml.toNumber(a.y, 0)
	layer.width = TmxXml.toNumber(a.width, mapWidth)
	layer.height = TmxXml.toNumber(a.height, mapHeight)
	layer.encoding = 'base64'
	if dataAttrs.compression then
		layer.compression = dataAttrs.compression
	end
	layer.data = TmxXml.textContent(dataNode)

	return layer
end

local function parseImageLayer(layerNode, mapDir)
	local a = TmxXml.attrs(layerNode)
	local layer = parseCommonLayerFields(layerNode)
	layer.type = 'imagelayer'
	layer.repeatx = TmxXml.toBool(a.repeatx, false)
	layer.repeaty = TmxXml.toBool(a.repeaty, false)

	local imageNode = TmxXml.child(layerNode, 'image')
	if imageNode then
		layer.image = TmxXml.resolvePath(mapDir, TmxXml.attrs(imageNode).source)
	end

	return layer
end

local parseLayerNode -- forward declaration; group layers recurse into this

local function parseObjectGroupLayer(layerNode, mapDir, tmxPath, deps, allocator)
	local layer = parseCommonLayerFields(layerNode)
	layer.type = 'objectgroup'
	layer.draworder = TmxXml.attrs(layerNode).draworder or 'topdown'
	layer.objects = {}

	for _, objectNode in ipairs(TmxXml.children(layerNode, 'object')) do
		table.insert(layer.objects, parseObject(objectNode, mapDir, tmxPath, deps, allocator))
	end

	return layer
end

local function parseGroupLayer(layerNode, mapDir, tmxPath, mapWidth, mapHeight, deps, allocator)
	local layer = parseCommonLayerFields(layerNode)
	layer.type = 'group'
	layer.layers = {}

	for _, childNode in ipairs(layerNode._children) do
		if isLayerTag(childNode._name) then
			table.insert(layer.layers, parseLayerNode(childNode, mapDir, tmxPath, mapWidth, mapHeight, deps, allocator))
		end
	end

	return layer
end

parseLayerNode = function(layerNode, mapDir, tmxPath, mapWidth, mapHeight, deps, allocator)
	local name = layerNode._name
	if name == 'layer' then
		return parseTileLayer(layerNode, tmxPath, mapWidth, mapHeight)
	elseif name == 'objectgroup' then
		return parseObjectGroupLayer(layerNode, mapDir, tmxPath, deps, allocator)
	elseif name == 'imagelayer' then
		return parseImageLayer(layerNode, mapDir)
	elseif name == 'group' then
		return parseGroupLayer(layerNode, mapDir, tmxPath, mapWidth, mapHeight, deps, allocator)
	end

	error('Unrecognised layer type "' .. tostring(name) .. '" in "' .. tmxPath .. '"', 2)
end

--- Parses a .tmx file into the exporter-shaped map table.
-- @param tmxPath Project-root-relative path to the .tmx file.
-- @param deps Optional dependency overrides; `deps.readFile(path)` returns
--   a file's contents or nil/false if it can't be read. Threaded through to
--   every .tsx/.tx read this parse triggers.
function Tmx.parse(tmxPath, deps)
	deps = deps or {}

	local mapNode = TmxXml.parseFile(tmxPath, deps)
	if mapNode._name ~= 'map' then
		error('Malformed tmx "' .. tmxPath .. '": missing <map> root element', 2)
	end

	local a = TmxXml.attrs(mapNode)

	if TmxXml.toBool(a.infinite, false) then
		error('Infinite/chunked maps are not supported: "' .. tmxPath .. '"', 2)
	end

	local map = {
		version = a.version,
		luaversion = '5.1',
		tiledversion = a.tiledversion,
		class = TmxXml.typeOrClass(a, ''),
		orientation = a.orientation,
		renderorder = a.renderorder,
		width = TmxXml.toNumber(a.width),
		height = TmxXml.toNumber(a.height),
		tilewidth = TmxXml.toNumber(a.tilewidth),
		tileheight = TmxXml.toNumber(a.tileheight),
		nextlayerid = TmxXml.toNumber(a.nextlayerid),
		nextobjectid = TmxXml.toNumber(a.nextobjectid),
		properties = TmxXml.parseProperties(mapNode),
		tilesets = {},
		layers = {},
	}

	local mapDir = TmxXml.dirname(tmxPath)
	local allocator = newTilesetAllocator(map.tilesets)

	for _, tilesetNode in ipairs(TmxXml.children(mapNode, 'tileset')) do
		local tsAttrs = TmxXml.attrs(tilesetNode)
		if not tsAttrs.source then
			error('Embedded tilesets are not supported (tileset firstgid '
				.. tostring(tsAttrs.firstgid) .. ' in "' .. tmxPath .. '"); use an external .tsx', 2)
		end

		local firstgid = TmxXml.toNumber(tsAttrs.firstgid)
		local tsxPath = TmxXml.resolvePath(mapDir, tsAttrs.source)
		local resolved = ExternalTileset.resolve(tsxPath, firstgid, deps)

		declareTileset(allocator, tsxPath, firstgid, resolved.tilecount)
		table.insert(map.tilesets, { name = resolved.name, firstgid = firstgid, filename = tsxPath })
	end

	for _, childNode in ipairs(mapNode._children) do
		if childNode._type == 'ELEMENT' then
			if isLayerTag(childNode._name) then
				table.insert(map.layers, parseLayerNode(childNode, mapDir, tmxPath, map.width, map.height, deps, allocator))
			elseif not KNOWN_NON_LAYER_MAP_CHILDREN[childNode._name] then
				error('Unrecognised map construct "<' .. childNode._name .. '>" in "' .. tmxPath .. '"', 2)
			end
		end
	end

	return map
end

return Tmx
