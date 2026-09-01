-- Parses a Tiled .tmj (JSON) map into the table structure Tiled's Lua
-- export plugin emits, so the vendored map loader (lib/sti) needs no
-- changes to consume it. This is the JSON equivalent of tmx.lua.
local json = require('src.utils.json')
local stiUtils = require('lib.sti.utils')
local TjTemplate = require('src.map.tj_template')
local TjTileset = require('src.map.tj_tileset')

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

--- Identity key for an embedded tileset, used to match a template's inline
--- tileset against the map's declared tilesets (and to cache auto-registered
--- ones), mirroring how an external .tsj is keyed by path.
local function embeddedTilesetKey(resolved)
	if resolved.image then
		return { image = resolved.image, kind = 'grid' }
	end
	local images = {}
	for _, t in ipairs(resolved.tiles) do
		images[#images + 1] = t.image
	end
	table.sort(images)
	return { images = images, kind = 'collection' }
end

-- Do two identity keys denote the same tileset content?
local function embeddedKeyEquals(a, b)
	if a.kind ~= b.kind then
		return false
	end
	if a.kind == 'grid' then
		return a.image == b.image
	end
	if #a.images ~= #b.images then
		return false
	end
	for i = 1, #a.images do
		if a.images[i] ~= b.images[i] then
			return false
		end
	end
	return true
end

--- Resolves template-local gid into map-global gid using the tileset allocator.
-- External template tilesets (.tsj source) resolve by path; embedded template
-- tilesets (no source) resolve by matching against the map's declared
-- tilesets on identity.
--
-- Entity-specific template tilesets are not part of the map: the map's
-- tilesets array declares only the tilesets the map's TILE layers use. When
-- the template's tileset is not declared, an inert NEGATIVE marker gid is
-- returned instead of registering the tileset into the map (registering it
-- would allocate firstgids inside the declared tilesets' gid domain and the
-- tile layers' low gids would render the wrong textures). The marker is
-- truthy for anchor semantics (NPCBase/cage/map_card check `if object.gid`)
-- and ignored by STI's decorative object batching (`gid > 0` required).
local GID_MARKER = -1
local function resolveTemplateGid(template, firstgidFor, firstgidForEmbedded, deps)
	local tmpl = template
	if tmpl.object.gid then
		if tmpl.tilesetRef then
			local mapFirstgid = firstgidFor(tmpl.tilesetRef.path, deps)
			if not mapFirstgid then
				return GID_MARKER
			end
			return tmpl.object.gid - tmpl.tilesetRef.firstgid + mapFirstgid
		elseif tmpl.tilesetEmbedded then
			local mapFirstgid = firstgidForEmbedded(tmpl.tilesetEmbedded, tmpl.dir, deps)
			if not mapFirstgid then
				return GID_MARKER
			end
			return tmpl.object.gid - (tmpl.tilesetEmbedded.firstgid or 1) + mapFirstgid
		end
	end
	return nil
end

--- Parses an object from TMJ format, resolving template references when present.
-- @param firstgidFor Function to resolve a template's tileset path to a map
--   firstgid (from the allocator), same contract as tmx.lua's firstgidFor.
local function parseObject(obj, tsFirstgidByGid, mapDir, firstgidFor, firstgidForEmbedded, deps)
	-- Resolve template: the template provides defaults for type, gid, name,
	-- width, height, and properties. Instance fields override.
	local base = { properties = {} }
	local templateGid = nil
	local templateTilesetImage = nil

	if obj.template then
		local templatePath = stiUtils.format_path(mapDir .. obj.template)
		local template = TjTemplate.resolve(templatePath, deps)
		base = template.object
		templateGid = resolveTemplateGid(template, firstgidFor, firstgidForEmbedded, deps)
		templateTilesetImage = template.tilesetImage
	end

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

	-- An empty-string type (e.g. a generated .tmj writing `type: ""` for a
	-- template instance) must fall through to the template's type, not win
	-- over it: in Lua '' is truthy and would mask the template default.
	local instanceType = obj.type
	if instanceType == '' then instanceType = nil end
	local instanceClass = obj.class
	if instanceClass == '' then instanceClass = nil end

	local object = {
		id = tonumber(obj.id),
		name = obj.name or base.name or '',
		type = instanceType or instanceClass or base.type or '',
		shape = shape,
		x = tonumber(obj.x) or 0,
		y = tonumber(obj.y) or 0,
		width = tonumber(obj.width) or base.width or 0,
		height = tonumber(obj.height) or base.height or 0,
		rotation = tonumber(obj.rotation) or 0,
		opacity = tonumber(obj.opacity) or 1,
		visible = obj.visible ~= false,
		properties = {},
	}

	-- Gid: instance explicit > template remapped > nothing
	local gid = tonumber(obj.gid) or templateGid
	if gid then
		object.gid = gid
	end

	if shapeKey then
		object[shapeKey] = points
	end

	-- Properties: merge template defaults with instance overrides.
	-- TjTemplate.resolve returns a template's properties either as a keyed
	-- table (name -> value, when parsed from a .tj) or as the raw JSON array
	-- form ([{name,type,value}, ...], when parsed from a .tj). Normalise both
	-- to keyed values, then overlay the instance's parsed keyed properties.
	if base.properties then
		if base.properties[1] and base.properties[1].name then
			-- JSON array form from a .tj template
			for _, prop in ipairs(base.properties) do
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
		else
			-- Keyed form from a .tj template
			for name, val in pairs(base.properties) do
				object.properties[name] = val
			end
		end
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
			elseif prop.type == 'file' and type(prop.value) == 'string' and prop.value ~= '' then
				-- Instance asset paths are authored relative to the map's dir.
				val = stiUtils.format_path(mapDir .. prop.value)
			end
			object.properties[prop.name] = val
		end
	end

	-- Sprite art's single source of truth is the template's inline tileset
	-- tile (what the editor previews), not a duplicated `image` property.
	-- Fall back to it when the instance carries no image of its own.
	if templateTilesetImage and object.properties.image == nil then
		object.properties.image = templateTilesetImage
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
local function parseLayer(layer, mapWidth, mapHeight, tsFirstgidByGid, mapDir, firstgidFor, firstgidForEmbedded, deps)
	local layerType = layer.type

	if layerType == 'tilelayer' then
		local data = layer.data
		-- Tiled's JSON export writes tile data either as a base64 string
		-- (with an explicit `encoding` field) or, for the CSV tile layer
		-- format, as a plain array of gids with no `encoding` field at all.
		-- STI takes the base64 string as-is and decodes it, but wants the
		-- already-decoded array left alone -- so only default `encoding`
		-- to base64 when the data really is a string.
		local encoding = layer.encoding
		if encoding == nil and type(data) ~= 'table' then
			encoding = 'base64'
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
			type = 'tilelayer',
			x = tonumber(layer.x) or 0,
			y = tonumber(layer.y) or 0,
			width = tonumber(layer.width) or mapWidth,
			height = tonumber(layer.height) or mapHeight,
			encoding = encoding,
			compression = (layer.compression and layer.compression ~= '') and layer.compression or nil,
			data = data,
		}
	elseif layerType == 'objectgroup' then
		local objects = {}
		if layer.objects then
			for _, obj in ipairs(layer.objects) do
				table.insert(objects, parseObject(obj, tsFirstgidByGid, mapDir, firstgidFor, firstgidForEmbedded, deps))
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
			image = layer.image and stiUtils.format_path(mapDir .. layer.image) or nil,
		}
	elseif layerType == 'group' then
		local layers = {}
		if layer.layers then
			for _, childLayer in ipairs(layer.layers) do
				table.insert(layers, parseLayer(childLayer, mapWidth, mapHeight, tsFirstgidByGid, mapDir, firstgidFor, firstgidForEmbedded, deps))
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

	-- Resolve tilesets (embedded or external)
	for _, ts in ipairs(mapData.tilesets) do
		local firstgid = tonumber(ts.firstgid)
		if ts.source then
			-- External tileset reference
			local tsxPath = stiUtils.format_path(mapDir .. ts.source)
			local resolved = TjTileset.resolve(tsxPath, firstgid, { readFile = readFile })
			table.insert(map.tilesets, resolved)
		else
			-- Embedded tileset
			local resolved = resolveEmbeddedTileset(ts, firstgid, mapDir)
			table.insert(map.tilesets, resolved)
		end
	end

	-- Tileset allocator for template auto-registration (same as tmx.lua)
	local allocator = {
		tilesets = map.tilesets,
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
			local resolved = resolveEmbeddedTileset(ts, firstgid, mapDir)
			allocator.byPath[resolved.image and resolved.image:gsub('^%.%.', '') or ''] = firstgid
			trueCount = tonumber(ts.tilecount) or 0
		end
		if firstgid >= allocator.nextFirstgid then
			allocator.nextFirstgid = firstgid + trueCount
		end
	end

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
		local shape = resolveEmbeddedTileset(embedTs, embedTs.firstgid or 1, tsDir)
		local key = embeddedTilesetKey(shape)

		-- Match against tilesets already in the map (declared ones only).
		for _, existing in ipairs(map.tilesets) do
			if embeddedKeyEquals(key, embeddedTilesetKey(existing)) then
				return existing.firstgid
			end
		end

		return nil
	end

	-- Parse layers
	if mapData.layers then
		local deps = { readFile = readFile }
		for _, layer in ipairs(mapData.layers) do
			table.insert(map.layers, parseLayer(layer, map.width, map.height, tsFirstgidByGid, mapDir, firstgidFor, firstgidForEmbedded, deps))
		end
	end
	return map
end

return Tmj