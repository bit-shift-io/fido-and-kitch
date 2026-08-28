-- Resolves a Tiled external tileset (.tsx or .tsj) into a table shaped exactly like
-- the tileset tables STI already builds for an embedded tileset, so the
-- rest of STI (rendering, animation, Map:getTileProperties) needs no
-- further changes to consume an external reference. See
-- .scratch/external-tilesets/DECISIONS.md for the shape contract.
local xml2lua = require('lib.xml2lua.xml2lua')
local xmlTreeHandler = require('lib.xml2lua.xmlhandler.tree')
local stiUtils = require('lib.sti.utils')
local json = require('src.utils.json')

local ExternalTileset = {}

-- Prefers love.filesystem.read (works both unfused and packaged into a
-- .love archive) over io.open, matching how the rest of this codebase reads
-- game files; falls back to io.open only when no `love` global exists at
-- all (e.g. plain unit-test runs, which always inject their own readFile).
local function defaultReadFile(path)
	if love and love.filesystem and love.filesystem.read then
		return love.filesystem.read(path)
	end

	local file = io.open(path, 'r')
	if not file then
		return nil
	end
	local contents = file:read('*a')
	file:close()
	return contents
end

local function dirname(path)
	local dir = path:match('^(.*)/[^/]+$')
	return dir and (dir .. '/') or ''
end

local function deepCopy(value)
	if type(value) ~= 'table' then
		return value
	end

	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function toNumber(value, default)
	if value == nil then
		return default
	end
	return tonumber(value)
end

local function asArray(xmlNode)
	if xmlNode._attr or xmlNode[1] == nil then
		-- xml2lua only arrays up repeated siblings; a single child parses
		-- to one table (identifiable by an `_attr` key), not a one-element
		-- array, so wrap it to give callers a uniform shape.
		return { xmlNode }
	end
	return xmlNode
end

local function parsePropertyValue(propertyAttrs)
	local value = propertyAttrs.value
	local propType = propertyAttrs.type

	if propType == 'bool' then
		return value == 'true'
	elseif propType == 'int' or propType == 'float' then
		return tonumber(value)
	end

	return value
end

local function parseProperties(propertiesXml)
	local properties = {}

	for _, propertyXml in ipairs(asArray(propertiesXml.property)) do
		properties[propertyXml._attr.name] = parsePropertyValue(propertyXml._attr)
	end

	return properties
end

local function parseAnimation(animationXml)
	local animation = {}

	for _, frameXml in ipairs(asArray(animationXml.frame)) do
		table.insert(animation, {
			tileid   = toNumber(frameXml._attr.tileid),
			duration = toNumber(frameXml._attr.duration),
		})
	end

	return animation
end

local function parseObjectGroup(objectGroupXml)
	local objects = {}

	if objectGroupXml.object then
		for _, objectXml in ipairs(asArray(objectGroupXml.object)) do
			local objectAttrs = objectXml._attr
			table.insert(objects, {
				id     = toNumber(objectAttrs.id),
				name   = objectAttrs.name or '',
				type   = objectAttrs.type or '',
				shape  = 'rectangle',
				x      = toNumber(objectAttrs.x, 0),
				y      = toNumber(objectAttrs.y, 0),
				width  = toNumber(objectAttrs.width, 0),
				height = toNumber(objectAttrs.height, 0),
				rotation = toNumber(objectAttrs.rotation, 0),
				visible  = true,
				properties = {},
			})
		end
	end

	return { objects = objects }
end

--- Adds `properties`/`animation`/`objectGroup` (Tile Collision Editor data)
-- onto `tile` when present on `tileXml`, in the same shape STI already
-- gives embedded tiles. Parsed for parity with embedded tilesets; this
-- project's own collision model does not consume `objectGroup`.
local function mergeTileMetadata(tile, tileXml)
	if tileXml.properties then
		tile.properties = parseProperties(tileXml.properties)
	end

	if tileXml.animation then
		tile.animation = parseAnimation(tileXml.animation)
	end

	if tileXml.objectgroup then
		tile.objectGroup = parseObjectGroup(tileXml.objectgroup)
	end
end

-- Resolved tilesets keyed by path (.tsx or .tsj), for the process lifetime --
-- files don't change mid-session, so no invalidation is needed. Cached
-- without `firstgid`/`tiles`' gids baked in, since the same file can be
-- referenced at a different firstgid by different maps.
local resolvedShapeCache = {}

--- Builds the base STI-shaped tileset table from the tileset attrs.
local function parseTilesetAttrs(attrs)
	return {
		name       = attrs.name,
		tilewidth  = toNumber(attrs.tilewidth),
		tileheight = toNumber(attrs.tileheight),
		spacing    = toNumber(attrs.spacing, 0),
		margin     = toNumber(attrs.margin, 0),
		columns    = toNumber(attrs.columns, 0),
		tilecount  = toNumber(attrs.tilecount, 0),
		tiles      = {},
		tileoffset = { x = 0, y = 0 },
	}
end

--- Reads a tileoffset element into `tileset` when present.
local function applyTileOffset(tileset, tilesetXml)
	local tileOffsetXml = tilesetXml.tileoffset
	if tileOffsetXml and tileOffsetXml._attr then
		tileset.tileoffset = {
			x = toNumber(tileOffsetXml._attr.x, 0),
			y = toNumber(tileOffsetXml._attr.y, 0),
		}
	end
end

--- Fills `tileset` for a grid tileset: a single shared <image> sliced into
-- a grid, with optional sibling <tile> elements carrying only per-tile
-- metadata (properties/animation/objectgroup) -- no per-tile image/geometry,
-- which comes from the shared grid instead.
local function parseGridImage(tileset, tsxPath, tilesetXml)
	local imageXml = tilesetXml.image
	local imageAttrs = imageXml._attr
	tileset.image = stiUtils.format_path(dirname(tsxPath) .. imageAttrs.source)
	tileset.imagewidth  = toNumber(imageAttrs.width)
	tileset.imageheight = toNumber(imageAttrs.height)

	if tilesetXml.tile then
		for _, tileXml in ipairs(asArray(tilesetXml.tile)) do
			local tile = { id = toNumber(tileXml._attr.id) }
			mergeTileMetadata(tile, tileXml)
			table.insert(tileset.tiles, tile)
		end
	end
end

--- Fills `tileset` for an image-collection tileset: one <image> per <tile>,
-- each optionally cropped to a sub-region of its own referenced image via
-- x/y/width/height on the <tile> element itself (distinct from the <image>'s
-- own width/height, its full source dimensions).
local function parseImageCollection(tileset, tsxPath, tilesetXml)
	for _, tileXml in ipairs(asArray(tilesetXml.tile)) do
		local tileImageXml = tileXml.image
		local tileImageAttrs = tileImageXml and tileImageXml._attr

		local tile = {
			id    = toNumber(tileXml._attr.id),
			image = tileImageAttrs and stiUtils.format_path(dirname(tsxPath) .. tileImageAttrs.source) or nil,
			width  = toNumber(tileXml._attr.width, tileImageAttrs and toNumber(tileImageAttrs.width)),
			height = toNumber(tileXml._attr.height, tileImageAttrs and toNumber(tileImageAttrs.height)),
		}

		if tileXml._attr.x ~= nil then
			tile.x = toNumber(tileXml._attr.x)
			tile.y = toNumber(tileXml._attr.y, 0)
		end

		mergeTileMetadata(tile, tileXml)

		table.insert(tileset.tiles, tile)
	end
end

--- Parses a .tsj (JSON) tileset file into an STI-shaped tileset table.
local function resolveTsjUncached(tsjPath, deps)
	local readFile = deps.readFile or defaultReadFile

	local contents = readFile(tsjPath)
	if not contents then
		error('External tileset not found: ' .. tsjPath, 2)
	end

	local ts = json.decode(contents)
	if not ts or ts.type ~= 'tileset' then
		error('Malformed tsj "' .. tsjPath .. '": not a tileset', 2)
	end

	-- Use the same logic as TMJ embedded tilesets
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
	}

	local tsDir = dirname(tsjPath)

	-- Grid tileset with shared image
	if ts.image then
		tileset.image = stiUtils.format_path(tsDir .. ts.image)
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
				image = tile.image and stiUtils.format_path(tsDir .. tile.image) or nil,
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

--- Parses and shapes a .tsx's tileset/tile data, independent of firstgid
-- (which callers may vary per map even for the same .tsx path).
local function resolveShapeUncached(tsxPath, deps)
	local readFile = deps.readFile or defaultReadFile

	local contents = readFile(tsxPath)
	if not contents then
		error('External tileset not found: ' .. tsxPath, 2)
	end

	local handler = xmlTreeHandler:new()
	local parser = xml2lua.parser(handler)

	local ok, err = pcall(function() parser:parse(contents) end)
	if not ok then
		error('Malformed external tileset "' .. tsxPath .. '": ' .. tostring(err), 2)
	end

	local tilesetXml = handler.root and handler.root.tileset
	if not tilesetXml or not tilesetXml._attr then
		error('Malformed external tileset "' .. tsxPath .. '": missing <tileset> root element', 2)
	end

	local tileset = parseTilesetAttrs(tilesetXml._attr)
	applyTileOffset(tileset, tilesetXml)

	local imageXml = tilesetXml.image
	if imageXml and imageXml._attr then
		parseGridImage(tileset, tsxPath, tilesetXml)
	elseif tilesetXml.tile then
		parseImageCollection(tileset, tsxPath, tilesetXml)
	end

	return tileset
end

--- Resolve an external .tsx or .tsj tileset to an STI-shaped tileset table.
-- @param path Path to the .tsx or .tsj file, as it would be opened from the
--   current working directory (already joined with the referencing map's
--   directory by the caller).
-- @param firstgid The tileset's firstgid, carried through to the result.
-- @param deps Optional dependency overrides; `deps.readFile(path)` returns
--   the file's contents or nil/false if it can't be read.
function ExternalTileset.resolve(path, firstgid, deps)
	deps = deps or {}

	local shape = resolvedShapeCache[path]
	if not shape then
		if path:sub(-4) == '.tsj' then
			shape = resolveTsjUncached(path, deps)
		else
			shape = resolveShapeUncached(path, deps)
		end
		resolvedShapeCache[path] = shape
	end

	-- Deep-copy: a shallow copy would leave `tiles` (and each tile's own
	-- `properties`/`animation`/`objectGroup`) shared by reference with the
	-- cache and every other map using this tileset. Nothing mutates them
	-- today, but tile custom-property lookups read through these
	-- references, so aliasing them is a latent bug waiting for a future
	-- mutation to turn live.
	local tileset = deepCopy(shape)
	tileset.firstgid = firstgid

	return tileset
end

return ExternalTileset