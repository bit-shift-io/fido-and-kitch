-- Pure helpers for reading map metadata (title, description, entity types)
-- shared by map_card.lua and map_list.lua.

local MapInfo = {}

function MapInfo.baseName(file)
	return file:gsub('%.tmj$', '')
end

function MapInfo.titleFromFile(file)
	local title = MapInfo.baseName(file):gsub('_', ' '):gsub('-', ' ')
	return (title:gsub('(%a)([%w_\']*)', function(first, rest)
		return first:upper() .. rest:lower()
	end))
end

function MapInfo.collectEntityTypes(mapData)
	local types = {}
	for _, layer in ipairs(mapData.layers or {}) do
		if layer.type == 'objectgroup' then
			for _, object in ipairs(layer.objects or {}) do
				if object.type and object.type ~= '' and object.type ~= 'spawn' then
					types[object.type] = true
				end
			end
		end
	end
	return types
end

function MapInfo.descriptionFor(file, mapData)
	if mapData.properties and mapData.properties.description then
		return mapData.properties.description
	end

	local labels = {}
	local entityTypes = MapInfo.collectEntityTypes(mapData)
	local ordered = {
		{'key', 'keys'},
		{'cage', 'cages'},
		{'teleport', 'teleporters'},
		{'jump_pad', 'jump pads'},
		{'coin', 'coins'},
		{'exit_door', 'an exit door'},
	}
	for _, item in ipairs(ordered) do
		if entityTypes[item[1]] then
			table.insert(labels, item[2])
		end
	end

	if #labels == 0 then
		return 'A bite-sized Fido and Kitch puzzle map.'
	end

	return 'A bite-sized puzzle featuring ' .. table.concat(labels, ', ') .. '.'
end

function MapInfo.titleFor(file, mapData)
	if mapData.properties and mapData.properties.name then
		return mapData.properties.name
	end

	if mapData.properties and mapData.properties.title then
		return mapData.properties.title
	end

	return MapInfo.titleFromFile(file)
end

return MapInfo
