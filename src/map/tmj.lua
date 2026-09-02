-- Parses a Tiled .tmj (JSON) map into the table structure Tiled's Lua
-- export plugin emits, so the vendored map loader (lib/sti) needs no
-- changes to consume it. This is the JSON equivalent of tmx.lua.
local json = require('src.utils.json')
local stiUtils = require('lib.sti.utils')
local TjTileset = require('src.map.tj_tileset')
local TmjParse = require('src.map.tmj_parse')

local Tmj = {}

--- Reads, decodes, and validates a .tmj file. Returns the read function
--- (for resolving external tilesets) and the decoded mapData.
local function readAndDecode(tmjPath)
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

	return readFile, mapData
end

--- Builds a gid -> tileset-firstgid lookup for tile-layer mapping.
local function buildGidToFirstgid(mapData)
	local tsFirstgidByGid = {}
	for _, ts in ipairs(mapData.tilesets) do
		local firstgid = tonumber(ts.firstgid)
		local tilecount = tonumber(ts.tilecount) or 0
		for gid = firstgid, firstgid + tilecount - 1 do
			tsFirstgidByGid[gid] = firstgid
		end
	end
	return tsFirstgidByGid
end

--- Builds the empty exporter-shaped map skeleton table.
local function buildMapSkeleton(mapData)
	return {
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
end

--- Parses the TMJ's top-level map properties into a key-value table.
local function parseMapProperties(mapData)
	local properties = {}
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
			properties[prop.name] = val
		end
	end
	return properties
end

--- Resolves the map's tilesets (embedded or external) into STI-shaped tables.
local function resolveMapTilesets(mapData, mapDir, readFile)
	local tilesets = {}
	for _, ts in ipairs(mapData.tilesets) do
		local firstgid = tonumber(ts.firstgid)
		if ts.source then
			-- External tileset reference
			local tsxPath = stiUtils.format_path(mapDir .. ts.source)
			local resolved = TjTileset.resolve(tsxPath, firstgid, { readFile = readFile })
			table.insert(tilesets, resolved)
		else
			-- Embedded tileset
			table.insert(tilesets, TmjParse.resolveEmbeddedTileset(ts, firstgid, mapDir))
		end
	end
	return tilesets
end

--- Builds the template tileset allocator: maps external .tsj paths and
--- embedded tileset identities to firstgids, tracking nextFirstgid.
local function buildTemplateAllocator(mapData, mapDir, readFile)
	local allocator = {
		tilesets = {},
		byPath = {},
		byEmbedded = {},
		nextFirstgid = 1,
	}
	for _, ts in ipairs(mapData.tilesets) do
		local firstgid = tonumber(ts.firstgid)
		local trueCount = 0
		if ts.source then
			-- Track external tileset by its .tsj path
			local tsxPath = stiUtils.format_path(mapDir .. ts.source)
			allocator.byPath[tsxPath] = firstgid
			-- An external tileset entry in the tmj carries only a source ref,
			-- no tilecount; resolve it so nextFirstgid reflects the tileset's
			-- true footprint (the tile layer's gids are all inside it).
			local resolved = TjTileset.resolve(tsxPath, firstgid, { readFile = readFile })
			trueCount = resolved.tilecount or 0
		else
			-- Embedded tileset - track by image path
			local resolved = TmjParse.resolveEmbeddedTileset(ts, firstgid, mapDir)
			allocator.byPath[resolved.image and resolved.image:gsub('^%.%.', '') or ''] = firstgid
			trueCount = tonumber(ts.tilecount) or 0
		end
		if firstgid >= allocator.nextFirstgid then
			allocator.nextFirstgid = firstgid + trueCount
		end
	end
	return allocator
end

--- Parses a .tmj file into the exporter-shaped map table.
-- @param tmjPath Project-root-relative path to the .tmj file.
function Tmj.parse(tmjPath)
	local readFile, mapData = readAndDecode(tmjPath)

	local mapDir = tmjPath:match('^(.*)/[^/]+$')
	mapDir = mapDir and (mapDir .. '/') or ''

	local tsFirstgidByGid = buildGidToFirstgid(mapData)
	local map = buildMapSkeleton(mapData)
	map.properties = parseMapProperties(mapData)
	map.tilesets = resolveMapTilesets(mapData, mapDir, readFile)
	local allocator = buildTemplateAllocator(mapData, mapDir, readFile)

	local function firstgidFor(tsxPath, deps)
		-- Look-up only: an external tileset is mapped only if the map declares
		-- it. Entity-specific template tilesets are intentionally NOT
		-- registered into the map (see resolveTemplateGid's doc), so a miss
		-- here means the template object's gid falls back to the marker.
		return allocator.byPath[tsxPath]
	end

	-- Resolve an embedded template tileset's map-global firstgid. Matches it
	-- against the map's DECLARED tilesets by identity and returns nil when
	-- none matches: entity-specific template tilesets are never auto-registered
	-- into the map's tilesets (they belong to the entity, not the map).
	-- @param embedTs Raw embedded tileset table from the .tj.
	-- @param templateDir Template's directory (for resolving image paths).
	local function firstgidForEmbedded(embedTs, templateDir, deps)
		local tsDir = templateDir
		local shape = TmjParse.resolveEmbeddedTileset(embedTs, embedTs.firstgid or 1, tsDir)
		local key = TmjParse.embeddedTilesetKey(shape)

		-- Match against tilesets already in the map (declared ones only).
		for _, existing in ipairs(map.tilesets) do
			if TmjParse.embeddedKeyEquals(key, TmjParse.embeddedTilesetKey(existing)) then
				return existing.firstgid
			end
		end

		return nil
	end

	-- Parse layers
	if mapData.layers then
		local deps = { readFile = readFile }
		for _, layer in ipairs(mapData.layers) do
			table.insert(map.layers, TmjParse.parseLayer(layer, map.width, map.height, tsFirstgidByGid, mapDir, firstgidFor, firstgidForEmbedded, deps))
		end
	end
	return map
end

return Tmj