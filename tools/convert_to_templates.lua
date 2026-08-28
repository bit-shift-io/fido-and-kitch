#!/usr/bin/env lua

-- Tool to convert map objects to use templates
-- Usage: lua tools/convert_to_templates.lua res/map/sandbox.tmj

local json = require('src.utils.json')
local lfs = require('lfs')

local function readFile(path)
	local file = io.open(path, 'r')
	if not file then return nil end
	local contents = file:read('*a')
	file:close()
	return contents
end

local function writeFile(path, contents)
	local file = io.open(path, 'w')
	if not file then error('Cannot write to ' .. path) end
	file:write(contents)
	file:close()
end

-- Load all templates from res/editor/
local function loadTemplates()
	local templates = {}
	for file in lfs.dir('res/editor') do
		if file:match('%.tj$') then
			local name = file:gsub('%.tj$', '')
			local contents = readFile('res/editor/' .. file)
			if contents then
				local tmpl = json.decode(contents)
				if tmpl and tmpl.object then
					templates[name] = tmpl
				end
			end
		end
	end
	return templates
end

-- Find matching template for an object
local function findTemplate(obj, templates)
	-- Try matching by type first
	for name, tmpl in pairs(templates) do
		if tmpl.object.type == obj.type then
			return name, tmpl
		end
	end
	-- Fallback: match by gid (if template has gid and object has gid)
	for name, tmpl in pairs(templates) do
		if tmpl.object.gid and obj.gid and tmpl.object.gid == obj.gid then
			return name, tmpl
		end
	end
	return nil, nil
end

-- Check if two property tables are equivalent
local function propsEqual(templateProps, objectProps)
	if not templateProps and not objectProps then return true end
	if not templateProps or not objectProps then return false end
	if #templateProps ~= #objectProps then return false end
	
	-- Build lookup from template props
	local tmplLookup = {}
	for _, p in ipairs(templateProps) do
		tmplLookup[p.name] = p
	end
	
	for _, p in ipairs(objectProps) do
		local tmplProp = tmplLookup[p.name]
		if not tmplProp then return false end
		if tmplProp.type ~= p.type then return false end
		if tmplProp.value ~= p.value then return false end
	end
	return true
end

-- Get properties that differ from template
local function getDiffProps(templateProps, objectProps)
	if not objectProps then return nil end
	if not templateProps then return objectProps end
	
	local tmplLookup = {}
	for _, p in ipairs(templateProps) do
		tmplLookup[p.name] = p
	end
	
	local diff = {}
	for _, p in ipairs(objectProps) do
		local tmplProp = tmplLookup[p.name]
		if not tmplProp or tmplProp.type ~= p.type or tmplProp.value ~= p.value then
			table.insert(diff, p)
		end
	end
	
	if #diff == 0 then return nil end
	return diff
end

-- Convert a map file
local function convertMap(mapPath)
	local contents = readFile(mapPath)
	if not contents then
		error('Map file not found: ' .. mapPath)
	end
	
	local map = json.decode(contents)
	if not map then
		error('Invalid JSON in map file')
	end
	
	local templates = loadTemplates()
	print('Loaded ' .. #templates .. ' templates')
	
	local converted = 0
	for _, layer in ipairs(map.layers) do
		if layer.type == 'objectgroup' and layer.objects then
			for _, obj in ipairs(layer.objects) do
				local tmplName, tmpl = findTemplate(obj, templates)
				if tmpl then
					local diffProps = getDiffProps(tmpl.object.properties, obj.properties)
					
					-- Build new object with template reference
					local newObj = {
						id = obj.id,
						template = '../editor/' .. tmplName .. '.tj',
						x = obj.x,
						y = obj.y
					}
					
					-- Only include properties that differ from template
					if diffProps then
						newObj.properties = diffProps
					end
					
					-- Preserve rotation if non-zero
					if obj.rotation and obj.rotation ~= 0 then
						newObj.rotation = obj.rotation
					end
					
					-- Preserve visible if false
					if obj.visible == false then
						newObj.visible = false
					end
					
					-- Preserve name if different from template
					if obj.name and obj.name ~= '' and obj.name ~= tmpl.object.name then
						newObj.name = obj.name
					end
					
					-- Replace object
					for k, v in pairs(newObj) do
						obj[k] = v
					end
					-- Remove keys not in newObj
					for k in pairs(obj) do
						if newObj[k] == nil then
							obj[k] = nil
						end
					end
					
					converted = converted + 1
					print('  Converted object ' .. obj.id .. ' (' .. obj.type .. ') -> ' .. tmplName)
				else
					print('  No template for object ' .. obj.id .. ' (' .. (obj.type or 'no type') .. ')')
				end
			end
		end
	end
	
	-- Write back
	writeFile(mapPath, json.encode(map))
	print('Converted ' .. converted .. ' objects. Saved to ' .. mapPath)
end

-- Main
local mapPath = arg[1]
if not mapPath then
	print('Usage: lua tools/convert_to_templates.lua <map_file.tmj>')
	os.exit(1)
end

convertMap(mapPath)