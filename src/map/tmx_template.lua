-- Resolves a Tiled object template (.tx file): the reusable object an
-- instance in a map's <object template="..."> inherits from. See
-- CONTEXT.md's "Object template" glossary entry and DECISIONS.md Q5/Q6.
--
-- Deliberately returns only the template's own data (its object's
-- attributes/properties, and which tileset + template-local gid its tile
-- reference names) -- remapping that gid into a specific map's numbering,
-- and auto-registering the tileset if that map doesn't declare it, are
-- map-specific concerns that belong to the caller (src/map/tmx.lua), not
-- to this cache.
local TmxXml = require('src.map.tmx_xml')

local TmxTemplate = {}

-- Keyed by resolved template path, for the process lifetime -- .tx files
-- don't change mid-session. Templates are only ever read during resolution
-- (merging builds fresh object/property tables in the caller), so nothing
-- aliases a cached entry.
local cache = {}

local function parseUncached(templatePath, deps)
	local templateNode = TmxXml.parseFile(templatePath, deps)
	if templateNode._name ~= 'template' then
		error('Malformed template "' .. templatePath .. '": missing <template> root element', 2)
	end

	local templateDir = TmxXml.dirname(templatePath)

	local tilesetRef = nil
	local tilesetNode = TmxXml.child(templateNode, 'tileset')
	if tilesetNode then
		local a = TmxXml.attrs(tilesetNode)
		tilesetRef = {
			firstgid = TmxXml.toNumber(a.firstgid),
			path = TmxXml.resolvePath(templateDir, a.source),
		}
	end

	local objectNode = TmxXml.child(templateNode, 'object')
	if not objectNode then
		error('Malformed template "' .. templatePath .. '": missing <object> element', 2)
	end

	local a = TmxXml.attrs(objectNode)

	return {
		tilesetRef = tilesetRef,
		object = {
			name = a.name or '',
			type = TmxXml.typeOrClass(a, ''),
			-- Template-local: still in the .tx's own tileset numbering
			-- (relative to tilesetRef.firstgid), not any map's.
			gid = TmxXml.toNumber(a.gid),
			width = TmxXml.toNumber(a.width),
			height = TmxXml.toNumber(a.height),
			properties = TmxXml.parseProperties(objectNode),
		},
	}
end

--- Resolve and cache a template by its project-root-relative path.
function TmxTemplate.resolve(templatePath, deps)
	local cached = cache[templatePath]
	if not cached then
		cached = parseUncached(templatePath, deps)
		cache[templatePath] = cached
	end
	return cached
end

return TmxTemplate
