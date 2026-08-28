-- Parses a Tiled .tmj (JSON) map into the table structure Tiled's Lua
-- export plugin emits, so the vendored map loader (lib/sti) needs no
-- changes to consume it. This is the JSON equivalent of tmx.lua.
local json = require('src.utils.json')
local stiUtils = require('lib.sti.utils')

local Tmj = {}

--- Resolves a tileset from the TMJ's embedded tileset data.
-- @param ts Table from the TMJ's tilesets array
-- @param firstgid The tileset's firstgid
-- @param mapDir Directory of the map file (for resolving image paths)
-- @return STI-shaped tileset table
local function resolveEmbeddedTileset(ts, firstgid, mapDir)
	local tileset = {
		name       = ts.name,
		tilewidth  = tonumber(ts.tilewidth),
		tileheight = tonumber(ts.tileheight),
		spacing    = tonumber(ts.spacing) or 0,
		margin     = tonumber(ts.margin) or 0,
		columns    = tonumber(ts.columns) or 0,
		tilecount  = tonumber(ts.tilecount) or 0,
		tiles      = {},
		tileoffset = { x = 0, y = 0 },
		firstgid   = firstgid,
	}

	-- Image collection vs grid tileset
	if ts.image then
		-- Grid tileset with shared image
		tileset.image = stiUtils.format_path(mapDir .. ts.image)
		tileset.imagewidth  = tonumber(ts.imagewidth)
		tileset.imageheight = tonumber(ts.imageheight)

		if ts.tiles then
			for _, tile in ipairs(ts.tiles) do
				local t = { id = tonumber(tile.id) }
				if tile.properties then
					t.properties = {}
					for _, prop in ipairs(tile.properties) do
						t.properties[prop.name] = prop.value
					end
				end
				if tile.animation then
					t.animation = {}
					for _, frame in ipairs(tile.animation) do
						table.insert(t.animation, {
							tileid   = tonumber(frame.tileid),
							duration = tonumber(frame.duration),
						})
					end
				end
				if tile.objectgroup then
					t.objectGroup = { objects = {} }
					for _, obj in ipairs(tile.objectgroup.objects) do
						table.insert(t.objectGroup.objects, {
							id     = tonumber(obj.id),
							name   = obj.name or '',
							type   = obj.type or '',
							shape  = obj.shape or 'rectangle',
							x      = tonumber(obj.x) or 0,
							y      = tonumber(obj.y) or 0,
							width  = tonumber(obj.width) or 0,
							height = tonumber(obj.height) or 0,
							rotation = tonumber(obj.rotation) or 0,
							visible  = obj.visible ~= false,
							properties = obj.properties or {},
						})
					end
				end
				table.insert(tileset.tiles, t)
			end
		end
	elseif ts.tiles then
		-- Image collection tileset
		for _, tile in ipairs(ts.tiles) do
			local t = {
				id    = tonumber(tile.id),
				image = tile.image and stiUtils.format_path(mapDir .. tile.image) or nil,
				width  = tonumber(tile.width) or (tile.imagewidth and tonumber(tile.imagewidth)),
				height = tonumber(tile.height) or (tile.imageheight and tonumber(tile.imageheight)),
			}
			if tile.x ~= nil then
				t.x = tonumber(tile.x)
				t.y = tonumber(tile.y) or 0
			end
			if tile.properties then
				t.properties = {}
				for _, prop in ipairs(tile.properties) do
					t.properties[prop.name] = prop.value
				end
			end
			if tile.animation then
				t.animation = {}
				for _, frame in ipairs(tile.animation) do
					table.insert(t.animation, {
						tileid   = tonumber(frame.tileid),
						duration = tonumber(frame.duration),
					})
				end
			end
			if tile.objectgroup then
				t.objectGroup = { objects = {} }
				for _, obj in ipairs(tile.objectgroup.objects) do
					table.insert(t.objectGroup.objects, {
						id     = tonumber(obj.id),
						name   = obj.name or '',
						type   = obj.type or '',
						shape  = obj.shape or 'rectangle',
						x      = tonumber(obj.x) or 0,
						y      = tonumber(obj.y) or 0,
						width  = tonumber(obj.width) or 0,
						height = tonumber(obj.height) or 0,
						rotation = tonumber(obj.rotation) or 0,
						visible  = obj.visible ~= false,
						properties = obj.properties or {},
					})
				end
			end
			table.insert(tileset.tiles, t)
		end
	end

	if ts.tileoffset then
		tileset.tileoffset = {
			x = tonumber(ts.tileoffset.x) or 0,
			y = tonumber(ts.tileoffset.y) or 0,
		}
	end

	return tileset
end

--- Parses an object from TMJ format.
local function parseObject(obj, tsFirstgidByGid)
	local shape = obj.shape or 'rectangle'
	local shapeKey, points = nil, nil

	if obj.polygon then
		shape = 'polygon'
		shapeKey = 'polygon'
		points = {}
		for _, p in ipairs(obj.polygon) do
			table.insert(points, { x = tonumber(p.x), y = tonumber(p.y) })
		end
	elseif obj.polyline then
		shape = 'polyline'
		shapeKey = 'polyline'
		points = {}
		for _, p in ipairs(obj.polyline) do
			table.insert(points, { x = tonumber(p.x), y = tonumber(p.y) })
		end
	elseif obj.ellipse then
		shape = 'ellipse'
	elseif obj.point then
		shape = 'point'
	end

	local object = {
		id = tonumber(obj.id),
		name = obj.name or '',
		type = obj.type or obj.class or '',
		shape = shape,
		x = tonumber(obj.x) or 0,
		y = tonumber(obj.y) or 0,
		width = tonumber(obj.width) or 0,
		height = tonumber(obj.height) or 0,
		rotation = tonumber(obj.rotation) or 0,
		opacity = tonumber(obj.opacity) or 1,
		visible = obj.visible ~= false,
		properties = {},
	}

	if obj.gid then
		object.gid = tonumber(obj.gid)
	end

	if shapeKey then
		object[shapeKey] = points
	end

	if obj.properties then
		for _, prop in ipairs(obj.properties) do
			local val = prop.value
			if prop.type == 'bool' then
				val = prop.value == true or prop.value == 'true'
			elseif prop.type == 'int' or prop.type == 'float' then
				val = tonumber(prop.value)
			elseif prop.type == 'object' then
				val = { id = tonumber(prop.value) }
			end
			object.properties[prop.name] = val
		end
	end

	return object
end

--- Parses TMJ properties array into a key-value table.
local function parseProperties(props)
	local result = {}
	if props then
		for _, prop in ipairs(props) do
			local val = prop.value
			if prop.type == 'bool' then
				val = prop.value == true or prop.value == 'true'
			elseif prop.type == 'int' or prop.type == 'float' then
				val = tonumber(prop.value)
			elseif prop.type == 'object' then
				val = { id = tonumber(prop.value) }
			end
			result[prop.name] = val
		end
	end
	return result
end

--- Parses a layer from TMJ format.
local function parseLayer(layer, mapWidth, mapHeight, tsFirstgidByGid)
	local layerType = layer.type

	if layerType == 'tilelayer' then
		local data = layer.data
		-- TMJ stores data as base64 string when encoding="base64"
		-- STI expects the raw base64 string, so pass it through
		-- If it's a CSV array (table), we'd need to encode it, but Tiled's
		-- JSON export uses base64 strings for base64 encoding.

		return {
			id = tonumber(layer.id),
			name = layer.name or '',
			class = layer.class or '',
			visible = layer.visible ~= false,
			opacity = tonumber(layer.opacity) or 1,
			offsetx = tonumber(layer.offsetx) or 0,
			offsety = tonumber(layer.offsety) or 0,
			parallaxx = tonumber(layer.parallaxx) or 1,
			parallaxy = tonumber(layer.parallaxy) or 1,
			properties = parseProperties(layer.properties),
			type = 'tilelayer',
			x = tonumber(layer.x) or 0,
			y = tonumber(layer.y) or 0,
			width = tonumber(layer.width) or mapWidth,
			height = tonumber(layer.height) or mapHeight,
			encoding = layer.encoding or 'base64',
			compression = (layer.compression and layer.compression ~= '') and layer.compression or nil,
			data = data,
		}
	elseif layerType == 'objectgroup' then
		local objects = {}
		if layer.objects then
			for _, obj in ipairs(layer.objects) do
				table.insert(objects, parseObject(obj, tsFirstgidByGid))
			end
		end
		return {
			id = tonumber(layer.id),
			name = layer.name or '',
			class = layer.class or '',
			visible = layer.visible ~= false,
			opacity = tonumber(layer.opacity) or 1,
			offsetx = tonumber(layer.offsetx) or 0,
			offsety = tonumber(layer.offsety) or 0,
			parallaxx = tonumber(layer.parallaxx) or 1,
			parallaxy = tonumber(layer.parallaxy) or 1,
			properties = parseProperties(layer.properties),
			type = 'objectgroup',
			draworder = layer.draworder or 'topdown',
			objects = objects,
		}
	elseif layerType == 'imagelayer' then
		return {
			id = tonumber(layer.id),
			name = layer.name or '',
			class = layer.class or '',
			visible = layer.visible ~= false,
			opacity = tonumber(layer.opacity) or 1,
			offsetx = tonumber(layer.offsetx) or 0,
			offsety = tonumber(layer.offsety) or 0,
			parallaxx = tonumber(layer.parallaxx) or 1,
			parallaxy = tonumber(layer.parallaxy) or 1,
			properties = parseProperties(layer.properties),
			type = 'imagelayer',
			repeatx = layer.repeatx or false,
			repeaty = layer.repeaty or false,
			image = layer.image and stiUtils.format_path(layer.image) or nil,
		}
	elseif layerType == 'group' then
		local layers = {}
		if layer.layers then
			for _, childLayer in ipairs(layer.layers) do
				table.insert(layers, parseLayer(childLayer, mapWidth, mapHeight, tsFirstgidByGid))
			end
		end
		return {
			id = tonumber(layer.id),
			name = layer.name or '',
			class = layer.class or '',
			visible = layer.visible ~= false,
			opacity = tonumber(layer.opacity) or 1,
			offsetx = tonumber(layer.offsetx) or 0,
			offsety = tonumber(layer.offsety) or 0,
			parallaxx = tonumber(layer.parallaxx) or 1,
			parallaxy = tonumber(layer.parallaxy) or 1,
			properties = parseProperties(layer.properties),
			type = 'group',
			layers = layers,
		}
	end

	error('Unrecognised layer type "' .. tostring(layerType) .. '"')
end

--- Parses a .tmj file into the exporter-shaped map table.
-- @param tmjPath Project-root-relative path to the .tmj file.
function Tmj.parse(tmjPath)
	local readFile
	if love and love.filesystem and love.filesystem.read then
		readFile = love.filesystem.read
	else
		readFile = function(path)
			local file = io.open(path, 'r')
			if not file then return nil end
			local contents = file:read('*a')
			file:close()
			return contents
		end
	end

	local contents = readFile(tmjPath)
	if not contents then
		error('File not found: ' .. tmjPath, 2)
	end

	local mapData = json.decode(contents)
	if not mapData or mapData.type ~= 'map' then
		error('Malformed tmj "' .. tmjPath .. '": not a map', 2)
	end

	if mapData.infinite then
		error('Infinite/chunked maps are not supported: "' .. tmjPath .. '"', 2)
	end

	local mapDir = tmjPath:match('^(.*)/[^/]+$')
	mapDir = mapDir and (mapDir .. '/') or ''

	-- Build firstgid lookup for gid->tileset mapping
	local tsFirstgidByGid = {}
	for _, ts in ipairs(mapData.tilesets) do
		local firstgid = tonumber(ts.firstgid)
		local tilecount = tonumber(ts.tilecount) or 0
		for gid = firstgid, firstgid + tilecount - 1 do
			tsFirstgidByGid[gid] = firstgid
		end
	end

	local map = {
		version = mapData.version,
		luaversion = '5.1',
		tiledversion = mapData.tiledversion,
		class = mapData.class or '',
		orientation = mapData.orientation,
		renderorder = mapData.renderorder,
		width = tonumber(mapData.width),
		height = tonumber(mapData.height),
		tilewidth = tonumber(mapData.tilewidth),
		tileheight = tonumber(mapData.tileheight),
		nextlayerid = tonumber(mapData.nextlayerid),
		nextobjectid = tonumber(mapData.nextobjectid),
		properties = {},
		tilesets = {},
		layers = {},
	}

	if mapData.properties then
		for _, prop in ipairs(mapData.properties) do
			local val = prop.value
			if prop.type == 'bool' then
				val = prop.value == true or prop.value == 'true'
			elseif prop.type == 'int' or prop.type == 'float' then
				val = tonumber(prop.value)
			elseif prop.type == 'object' then
				val = { id = tonumber(prop.value) }
			end
			map.properties[prop.name] = val
		end
	end

	-- Resolve tilesets (embedded in TMJ)
	for _, ts in ipairs(mapData.tilesets) do
		local firstgid = tonumber(ts.firstgid)
		local resolved = resolveEmbeddedTileset(ts, firstgid, mapDir)
		table.insert(map.tilesets, resolved)
	end

	-- Parse layers
	if mapData.layers then
		for _, layer in ipairs(mapData.layers) do
			table.insert(map.layers, parseLayer(layer, map.width, map.height, tsFirstgidByGid))
		end
	end

	return map
end

return Tmj