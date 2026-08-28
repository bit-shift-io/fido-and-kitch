-- Resolves a Tiled object template (.tj file): the reusable object an
-- instance in a map's <object template="..."> inherits from. See
-- CONTEXT.md's "Object template" glossary entry and DECISIONS.md Q5/Q6.
--
-- Deliberately returns only the template's own data (its object's
-- attributes/properties, and which tileset + template-local gid its tile
-- reference names) -- remapping that gid into a specific map's numbering,
-- and auto-registering the tileset if that map doesn't declare it, are
-- map-specific concerns that belong to the caller (src/map/tmj.lua), not
-- to this cache.
local json = require('src.utils.json')

local TjTemplate = {}

-- Keyed by resolved template path, for the process lifetime -- .tj files
-- don't change mid-session. Templates are only ever read during resolution
-- (merging builds fresh object/property tables in the caller), so nothing
-- aliases a cached entry.
local cache = {}

local function parseTj(templatePath, deps)
	local readFile
	if deps and deps.readFile then
		readFile = deps.readFile
	else
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
	end

	local contents = readFile(templatePath)
	if not contents then
		error('File not found: ' .. templatePath, 2)
	end

	local tj = json.decode(contents)
	if not tj or tj.type ~= 'template' then
		error('Malformed template "' .. templatePath .. '": not a template', 2)
	end

	local templateDir = templatePath:match('^(.*)/[^/]+$')
	templateDir = templateDir and (templateDir .. '/') or ''

	local tilesetRef = nil
	local tilesetEmbedded = nil
	if tj.tileset then
		if tj.tileset.source then
			-- External .tsj: hand off to the map's allocator by path.
			tilesetRef = {
				firstgid = tj.tileset.firstgid,
				path = tj.tileset.source,
			}
			-- Resolve relative to template directory
			if not tilesetRef.path:match('^/') then
				tilesetRef.path = templateDir .. tilesetRef.path
			end
		else
			-- Embedded tileset (no source): carry the raw tileset table so the
			-- map parser can match/register it by identity, mirroring how the
			-- .tj's own tileset is self-contained.
			tilesetEmbedded = tj.tileset
		end
	end

	local obj = tj.object
	return {
		tilesetRef = tilesetRef,
		tilesetEmbedded = tilesetEmbedded,
		dir = templateDir,
		object = {
			name = obj.name or '',
			type = obj.type or '',
			gid = obj.gid,
			width = obj.width,
			height = obj.height,
			properties = obj.properties or {},
		},
	}
end

--- Resolve and cache a template by its project-root-relative path.
function TjTemplate.resolve(templatePath, deps)
	local cached = cache[templatePath]
	if not cached then
		cached = parseTj(templatePath, deps)
		cache[templatePath] = cached
	end
	return cached
end

return TjTemplate
