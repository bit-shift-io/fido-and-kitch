-- Shared XML-tree helpers for the .tmx/.tx parsers (src/map/tmx.lua,
-- src/map/tmx_template.lua). Built on xml2lua's DOM handler rather than its
-- tree handler (the one external_tileset.lua uses): a Tiled <map> or <group>
-- mixes different sibling tag names in an order that is load-bearing for
-- draw order (a tile layer interleaved with object groups), and the tree
-- handler collapses same-name siblings into arrays keyed by tag name,
-- destroying order between *different* tag names. The DOM handler keeps a
-- single ordered `_children` list per node, which preserves it.
local xml2lua = require('lib.xml2lua.xml2lua')
local domHandler = require('lib.xml2lua.xmlhandler.dom')
local stiUtils = require('lib.sti.utils')

local TmxXml = {}

function TmxXml.defaultReadFile(path)
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

function TmxXml.dirname(path)
	local dir = path:match('^(.*)/[^/]+$')
	return dir and (dir .. '/') or ''
end

--- Parses `contents` and returns the single root element node (e.g. the
-- <map> or <template> tag), skipping the DOM handler's synthetic ROOT and
-- any decl/comment siblings.
-- @param path Used only to name the file in error messages.
function TmxXml.parse(path, contents)
	local handler = domHandler:new()
	local parser = xml2lua.parser(handler)

	local ok, err = pcall(function() parser:parse(contents) end)
	if not ok then
		error('Malformed "' .. path .. '": ' .. tostring(err), 3)
	end

	-- xml2lua's DOM handler sets `root` to the document's single top-level
	-- element directly (not wrapped in a synthetic container) whenever
	-- there's exactly one, which is always true for a well-formed .tmx/.tx.
	if handler.root and handler.root._type == 'ELEMENT' then
		return handler.root
	end

	if handler.root and handler.root._children then
		for _, child in ipairs(handler.root._children) do
			if child._type == 'ELEMENT' then
				return child
			end
		end
	end

	error('Malformed "' .. path .. '": no root element', 3)
end

--- Reads and parses an XML file, raising a clear error naming `path` if it
-- can't be read or parsed.
function TmxXml.parseFile(path, deps)
	deps = deps or {}
	local readFile = deps.readFile or TmxXml.defaultReadFile

	local contents = readFile(path)
	if not contents then
		error('File not found: ' .. path, 3)
	end

	return TmxXml.parse(path, contents)
end

function TmxXml.attrs(node)
	return (node and node._attr) or {}
end

--- All direct-child elements of `node` named `name`, in document order.
function TmxXml.children(node, name)
	local list = {}
	if not node then
		return list
	end
	for _, child in ipairs(node._children) do
		if child._type == 'ELEMENT' and child._name == name then
			table.insert(list, child)
		end
	end
	return list
end

--- The first direct-child element of `node` named `name`, or nil.
function TmxXml.child(node, name)
	return TmxXml.children(node, name)[1]
end

--- Concatenated text content of `node` (its own text/CDATA children only).
function TmxXml.textContent(node)
	local parts = {}
	for _, child in ipairs(node._children) do
		if child._type == 'TEXT' then
			table.insert(parts, child._text)
		end
	end
	return table.concat(parts):match('^%s*(.-)%s*$')
end

function TmxXml.toNumber(value, default)
	if value == nil then
		return default
	end
	return tonumber(value)
end

function TmxXml.toBool(value, default)
	if value == nil then
		return default
	end
	return value == 'true' or value == '1'
end

--- Both spellings of Tiled's class/type concept are accepted: 1.9 renamed
-- object "type" to "class", and the affected map/template content here
-- predates that rename, so either may appear (see DECISIONS.md Q5).
function TmxXml.typeOrClass(attrs, default)
	if attrs.type ~= nil then
		return attrs.type
	end
	if attrs.class ~= nil then
		return attrs.class
	end
	return default or ''
end

function TmxXml.coercePropertyValue(propType, value)
	if propType == nil or propType == 'string' or propType == 'file' or propType == 'color' then
		return value
	elseif propType == 'bool' then
		return value == 'true'
	elseif propType == 'int' or propType == 'float' then
		return tonumber(value)
	elseif propType == 'object' then
		return { id = tonumber(value) }
	end

	error('Unsupported property type "' .. tostring(propType) .. '"', 3)
end

--- Parses `node`'s direct <properties><property .../></properties> child,
-- if any, into a name -> coerced-value table. Returns {} when absent, since
-- the exporter always materialises an (empty) properties table.
function TmxXml.parseProperties(node)
	local properties = {}
	local propertiesNode = TmxXml.child(node, 'properties')

	if propertiesNode then
		for _, propertyNode in ipairs(TmxXml.children(propertiesNode, 'property')) do
			local a = TmxXml.attrs(propertyNode)
			properties[a.name] = TmxXml.coercePropertyValue(a.type, a.value)
		end
	end

	return properties
end

--- Merges `overridingProperties` onto a copy of `baseProperties`, with the
-- overriding value winning on a name collision (Tiled template inheritance).
function TmxXml.mergeProperties(baseProperties, overridingProperties)
	local merged = {}
	for name, value in pairs(baseProperties) do
		merged[name] = value
	end
	for name, value in pairs(overridingProperties) do
		merged[name] = value
	end
	return merged
end

--- Resolves `relativePath` (as written in an XML attribute, relative to the
-- directory of the file that declared it) into a project-root-relative
-- path, matching how external_tileset.lua already resolves image paths.
function TmxXml.resolvePath(baseDir, relativePath)
	return stiUtils.format_path(baseDir .. relativePath)
end

return TmxXml
