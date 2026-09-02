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
local json = require("src.utils.json")
local stiUtils = require("lib.sti.utils")

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
				local file = io.open(path, "r")
				if not file then
					return nil
				end
				local contents = file:read("*a")
				file:close()
				return contents
			end
		end
	end

	local contents = readFile(templatePath)
	if not contents then
		error("File not found: " .. templatePath, 2)
	end

	local tj = json.decode(contents)
	if not tj or tj.type ~= "template" then
		error('Malformed template "' .. templatePath .. '": not a template', 2)
	end

	local templateDir = templatePath:match("^(.*)/[^/]+$")
	templateDir = templateDir and (templateDir .. "/") or ""

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
			if not tilesetRef.path:match("^/") then
				tilesetRef.path = templateDir .. tilesetRef.path
			end
		else
			-- Embedded tileset (no source): carry the raw tileset table so the
			-- map parser can match/register it by identity, mirroring how the
			-- .tj's own tileset is self-contained.
			tilesetEmbedded = tj.tileset
		end
	end

	-- The art the editor previews comes from the template's own tileset tile,
	-- not a duplicated `image` file property (the two used to drift). Expose
	-- the tile image as `tilesetImage`, normalized to a project-root-relative
	-- runtime path, so instancing code can fall back to it.
	local tilesetImage = nil
	if tilesetEmbedded then
		local tile = tilesetEmbedded.tiles and tilesetEmbedded.tiles[1]
		local image = tile and tile.image or tilesetEmbedded.image
		if type(image) == "string" and image ~= "" then
			tilesetImage = stiUtils.format_path(templateDir .. image)
		end
	end

	local obj = tj.object

	-- File-typed props carry asset paths authored relative to the template's
	-- own directory (../img/...). Convert them to project-root-relative runtime
	-- paths up front (cached per path below), mirroring what tj_tileset.lua
	-- does for tileset images, so instancing maps get ready-to-use paths.
	local properties = obj.properties or {}
	if #properties > 0 and properties[1].name then
		local converted = {}
		for i, prop in ipairs(properties) do
			converted[i] = { name = prop.name, type = prop.type, value = prop.value }
			if prop.type == "file" and type(prop.value) == "string" and prop.value ~= "" then
				converted[i].value = stiUtils.format_path(templateDir .. prop.value)
			end
		end
		properties = converted
	end

	return {
		tilesetRef = tilesetRef,
		tilesetEmbedded = tilesetEmbedded,
		tilesetImage = tilesetImage,
		dir = templateDir,
		object = {
			name = obj.name or "",
			type = obj.type or "",
			gid = obj.gid,
			width = obj.width,
			height = obj.height,
			properties = properties,
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

-- Same lookup, but for callers where "no template here" is an expected,
-- routine outcome (e.g. entity_factory.lua probing every entity type for an
-- optional res/entities/<type>.tj) rather than an authoring mistake: a
-- missing file returns nil instead of raising, so nothing needs to run
-- through pcall/error() just to express "not found" -- error() (via resolve
-- above) still fires for a template that exists but is malformed, since
-- that IS worth surfacing loudly. A Lua debugger attached to the process
-- (e.g. lldebugger via VS Code's launch.json) breaks on every raised error
-- regardless of an enclosing pcall, so routing the expected-miss case
-- through error()+pcall made every non-templated entity type look like a
-- crash under the debugger even though the game handled it fine unattached.
function TjTemplate.tryResolve(templatePath, deps)
	local cached = cache[templatePath]
	if cached then
		return cached
	end

	local readFile
	if deps and deps.readFile then
		readFile = deps.readFile
	elseif love and love.filesystem and love.filesystem.read then
		readFile = love.filesystem.read
	else
		readFile = function(path)
			local file = io.open(path, "r")
			if not file then
				return nil
			end
			local contents = file:read("*a")
			file:close()
			return contents
		end
	end

	if not readFile(templatePath) then
		return nil
	end

	return TjTemplate.resolve(templatePath, deps)
end

return TjTemplate
