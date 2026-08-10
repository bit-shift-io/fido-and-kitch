-- Exports a map's terrain as ASCII art with a legend, for pasting into an
-- AI agent (e.g. to generate an image). Terrain only: gameplay objects
-- (ladders, keys, doors, cages, coins, spawns, NPCs, ...) are authored in
-- the editor and deliberately excluded from the export.
--
-- Invoked via the `export=<map>` run flag, e.g. `love . export=sandbox`:
-- prints the export to stdout, writes `export_<map>.txt` into the LÖVE save
-- dir, then quits. Mirrors the `e2e=<file>` detour in src/main.lua.
--
-- Symbols:
--   #  solid ground (layers with a `collision` property, per
--      src/map/init.lua -- tile layers and objectgroup rects both count)
--   w  water        f  fire        l  lava        s  spikes
--      (kill_zone objects, symbol by `properties.deathType`; unset/unknown
--       deathType defaults to water)
--   .  nothing
local Tmx = require('src.map.tmx')

local ExportAscii = {}

local SYMBOL_SOLID = '#'
local SYMBOL_EMPTY = '.'

-- kill_zone deathType -> symbol. kill_zone.lua defaults an unset
-- deathType to 'unknown'; unknown falls through to water (`w`).
local DEATHTYPE_SYMBOLS = {
	water = 'w',
	fire = 'f',
	lava = 'l',
	spikes = 's',
}

-- Tiled packs gids as little-endian u32 with flip flags in the high bits;
-- mask them off (mod 2^28 == gid & 0x0FFFFFFF, without bit-op libraries).
local GID_MASK = 0x10000000

local function resolveMapFile(basePath)
	if basePath:match('%.tmx$') or basePath:match('%.lua$') then
		return basePath
	end
	if love and love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(basePath .. '.tmx') then
		return basePath .. '.tmx'
	end
	return basePath .. '.lua'
end

local function fileStem(path)
	local base = path:match('[^/\\]+$') or path
	return (base:gsub('%.%w+$', ''))
end

-- Decode a base64 (optionally zlib/gzip-compressed) tile layer into a
-- [y][x] grid of gids. Requires love.data -- the running game only.
function ExportAscii.decodeTileGrid(layer, mapWidth, mapHeight)
	local data = love.data.decode('string', 'base64', layer.data)
	if layer.compression == 'zlib' or layer.compression == 'gzip' then
		data = love.data.decompress('string', layer.compression, data)
	end

	local grid = {}
	for y = 0, mapHeight - 1 do
		local row = {}
		for x = 0, mapWidth - 1 do
			local offset = (y * mapWidth + x) * 4 + 1
			local b1, b2, b3, b4 = data:byte(offset, offset + 3)
			local gid = (b1 or 0) + (b2 or 0) * 0x100 + (b3 or 0) * 0x10000 + (b4 or 0) * 0x1000000
			row[x + 1] = gid % GID_MASK
		end
		grid[y + 1] = row
	end
	return grid
end

-- Paint every grid cell that a pixel rect overlaps. Tile layers use
-- row-major [y][x] grids; rects are in pixels, top-left anchored.
local function paintRect(grid, rectX, rectY, rectWidth, rectHeight, tileWidth, tileHeight, symbol)
	local x0 = math.max(1, math.floor(rectX / tileWidth) + 1)
	local y0 = math.max(1, math.floor(rectY / tileHeight) + 1)
	local x1 = math.min(#grid[1], math.floor((rectX + rectWidth - 1) / tileWidth) + 1)
	local y1 = math.min(#grid, math.floor((rectY + rectHeight - 1) / tileHeight) + 1)
	for y = y0, y1 do
		for x = x0, x1 do
			grid[y][x] = symbol
		end
	end
end

-- Build the symbol grid for a parsed map. Tile layers' `data` must already
-- be decoded into [y][x] gid grids (see decodeTileGrid). Pure — no love
-- dependency, so it is unit-testable headlessly.
function ExportAscii.buildSymbolGrid(map)
	local width, height = map.width, map.height
	local grid = {}
	for y = 1, height do
		grid[y] = {}
		for x = 1, width do
			grid[y][x] = SYMBOL_EMPTY
		end
	end

	for _, layer in ipairs(map.layers) do
		if layer.properties.collision then
			if layer.type == 'tilelayer' and layer.data then
				for y = 1, height do
					local row = layer.data[y]
					if row then
						for x = 1, width do
							if row[x] and row[x] ~= 0 then
								grid[y][x] = SYMBOL_SOLID
							end
						end
					end
				end
			elseif layer.type == 'objectgroup' then
				for _, obj in ipairs(layer.objects or {}) do
					if obj.shape == 'rectangle' then
						paintRect(grid, obj.x, obj.y, obj.width, obj.height, map.tilewidth, map.tileheight, SYMBOL_SOLID)
					end
				end
			end
		end
	end

	-- Hazards (kill zones) paint over ground: a lethal cell is not solid.
	for _, layer in ipairs(map.layers) do
		if layer.type == 'objectgroup' then
			for _, obj in ipairs(layer.objects or {}) do
				if obj.type == 'kill_zone' then
					local deathType = obj.properties and obj.properties.deathType
					local symbol = DEATHTYPE_SYMBOLS[deathType] or 'w'
					paintRect(grid, obj.x, obj.y, obj.width, obj.height, map.tilewidth, map.tileheight, symbol)
				end
			end
		end
	end

	return grid
end

-- Render header + grid + legend. Pure — unit-testable headlessly.
function ExportAscii.renderText(map, grid)
	local lines = {}

	local height = map.height or #grid
	local width = map.width or (#grid[1] or 0)

	table.insert(lines, string.format('Export of %s (%dx%d, tile %dx%dpx)',
		map._exportName or 'map', width, height, map.tilewidth, map.tileheight))
	table.insert(lines, '')

	for y = 1, height do
		table.insert(lines, table.concat(grid[y], ''))
	end

	table.insert(lines, '')
	table.insert(lines, 'Legend:')
	local legend = {
		{ SYMBOL_SOLID, 'solid ground' },
		{ 'w', 'water' },
		{ 'f', 'fire' },
		{ 'l', 'lava' },
		{ 's', 'spikes' },
		{ SYMBOL_EMPTY, 'nothing' },
	}
	for i, entry in ipairs(legend) do
		table.insert(lines, entry[1] .. '  ' .. entry[2])
	end

	return table.concat(lines, '\n')
end

-- Full export pipeline: parse, decode, build, print, write to the save dir.
-- Designed to run from the love.load detour before a Game is constructed.
function ExportAscii.run(mapName)
	local path = resolveMapFile('res/map/' .. mapName)
	local map = Tmx.parse(path)
	map._exportName = fileStem(path)

	for _, layer in ipairs(map.layers) do
		if layer.type == 'tilelayer' and layer.data then
			layer.data = ExportAscii.decodeTileGrid(layer, map.width, map.height)
		end
	end

	local grid = ExportAscii.buildSymbolGrid(map)
	local text = ExportAscii.renderText(map, grid)

	print(text)

	local filename = 'export_' .. mapName .. '.txt'
	local ok, err = love.filesystem.write(filename, text .. '\n')
	if not ok then
		print('ERROR: could not write ' .. filename .. ': ' .. tostring(err))
		return
	end
	print('')
	print('Wrote ' .. love.filesystem.getSaveDirectory() .. '/' .. filename)
end

return ExportAscii