-- Exports a map's terrain as a pixel map / segmentation map (PNG), one
-- 128x128 block per tile, for feeding an AI agent (e.g. to generate art).
-- Terrain only: gameplay objects (ladders, keys, doors, cages, coins,
-- spawns, NPCs, ...) are authored in the editor and deliberately excluded.
--
-- Colors (fully opaque):
--   (0,0,0)   black  nothing
--   (0,255,0) green  terrain / collision (layers with a `collision` prop,
--                    per src/map/init.lua -- tile layers and objectgroup
--                    rects both count)
--   (0,0,255) blue   killzone / water (kill_zone objects; any deathType
--                    -- water, fire, lava, spikes all collapse to blue)
--
-- Invoked via the `export=<map>` run flag, e.g. `love . export=sandbox`:
-- prints the path + dimensions + color legend to stdout, writes
-- `export_<map>.png` into the project root (working directory), then quits.
-- Mirrors the `e2e=<file>` detour in src/main.lua.
local Tmj = require("src.map.tmj")

local ExportPng = {}

local COLOR_EMPTY = { 0, 0, 0 }
local COLOR_SOLID = { 0, 255, 0 }
local COLOR_KILLZONE = { 0, 0, 255 }

-- Each tile is drawn as a TILE_BLOCK_SIZE x TILE_BLOCK_SIZE block of solid
-- color, so the exported PNG is upscaled for a downstream image tool.
local TILE_BLOCK_SIZE = 128

-- Tiled packs gids as little-endian u32 with flip flags in the high bits;
-- mask them off (mod 2^28 == gid & 0x0FFFFFFF, without bit-op libraries).
local GID_MASK = 0x10000000

local function resolveMapFile(basePath)
	if basePath:match("%.tmj$") then
		return basePath
	end
	if love and love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(basePath .. ".tmj") then
		return basePath .. ".tmj"
	end
	return basePath .. ".tmj"
end

local function fileStem(path)
	local base = path:match("[^/\\]+$") or path
	return (base:gsub("%.%w+$", ""))
end

-- Decode a base64 (optionally zlib/gzip-compressed) tile layer into a
-- [y][x] grid of gids. Requires love.data -- the running game only.
function ExportPng.decodeTileGrid(layer, mapWidth, mapHeight)
	local data = love.data.decode("string", "base64", layer.data)
	if layer.compression == "zlib" or layer.compression == "gzip" then
		data = love.data.decompress("string", layer.compression, data)
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
local function paintRect(grid, rectX, rectY, rectWidth, rectHeight, tileWidth, tileHeight, color)
	local x0 = math.max(1, math.floor(rectX / tileWidth) + 1)
	local y0 = math.max(1, math.floor(rectY / tileHeight) + 1)
	local x1 = math.min(#grid[1], math.floor((rectX + rectWidth - 1) / tileWidth) + 1)
	local y1 = math.min(#grid, math.floor((rectY + rectHeight - 1) / tileHeight) + 1)
	for y = y0, y1 do
		for x = x0, x1 do
			grid[y][x] = color
		end
	end
end

-- Build the color grid for a parsed map. Tile layers' `data` must already
-- be decoded into [y][x] gid grids (see decodeTileGrid). Pure -- no love
-- dependency, so it is unit-testable headlessly.
function ExportPng.buildColorGrid(map)
	local width, height = map.width, map.height
	local grid = {}
	for y = 1, height do
		grid[y] = {}
		for x = 1, width do
			grid[y][x] = COLOR_EMPTY
		end
	end

	for _, layer in ipairs(map.layers) do
		if layer.properties.collision then
			if layer.type == "tilelayer" and layer.data then
				for y = 1, height do
					local row = layer.data[y]
					if row then
						for x = 1, width do
							if row[x] and row[x] ~= 0 then
								grid[y][x] = COLOR_SOLID
							end
						end
					end
				end
			elseif layer.type == "objectgroup" then
				for _, obj in ipairs(layer.objects or {}) do
					if obj.shape == "rectangle" then
						paintRect(grid, obj.x, obj.y, obj.width, obj.height, map.tilewidth, map.tileheight, COLOR_SOLID)
					end
				end
			end
		end
	end

	-- Hazards (kill zones) paint over ground regardless of deathType: a
	-- lethal cell is blue, not solid.
	for _, layer in ipairs(map.layers) do
		if layer.type == "objectgroup" then
			for _, obj in ipairs(layer.objects or {}) do
				if obj.type == "kill_zone" then
					paintRect(grid, obj.x, obj.y, obj.width, obj.height, map.tilewidth, map.tileheight, COLOR_KILLZONE)
				end
			end
		end
	end

	return grid
end

-- Write a [y][x] color grid (entries as {r,g,b}) into a fresh ImageData,
-- rendering each tile as a `scale` x `scale` pixel block. Requires
-- love.image -- the running game only.
function ExportPng.buildImageData(grid, width, height, scale)
	scale = scale or 1
	width = width or (#grid[1] or 0)
	height = height or #grid
	local imageData = love.image.newImageData(width * scale, height * scale)
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			local color = grid[y + 1][x + 1]
			for py = 0, scale - 1 do
				for px = 0, scale - 1 do
					imageData:setPixel(x * scale + px, y * scale + py, color[1], color[2], color[3], 255)
				end
			end
		end
	end
	return imageData
end

-- Full export pipeline: parse, decode, build color grid, encode PNG, print
-- diagnostics, write to the working directory. Designed to run from the love.load
-- detour before a Game is constructed.
function ExportPng.run(mapName)
	local path = resolveMapFile("res/map/" .. mapName)
	local map = Tmj.parse(path)
	map._exportName = fileStem(path)

	for _, layer in ipairs(map.layers) do
		if layer.type == "tilelayer" and layer.data then
			layer.data = ExportPng.decodeTileGrid(layer, map.width, map.height)
		end
	end

	local grid = ExportPng.buildColorGrid(map)
	local imageData = ExportPng.buildImageData(grid, map.width, map.height, TILE_BLOCK_SIZE)
	local png = imageData:encode("png")

	local filename = "export_" .. mapName .. ".png"
	local path = love.filesystem.getWorkingDirectory() .. "/" .. filename
	local file, err = io.open(path, "wb")
	if not file then
		print("ERROR: could not write " .. path .. ": " .. tostring(err))
		return
	end
	file:write(png:getString())
	file:close()
	print(
		string.format(
			"Pixel map of %s (%dx%d tiles = %dx%d px, %dpx per tile)",
			map._exportName or "map",
			map.width,
			map.height,
			map.width * TILE_BLOCK_SIZE,
			map.height * TILE_BLOCK_SIZE,
			TILE_BLOCK_SIZE
		)
	)
	print("Colors: (0,0,0) black nothing, (0,255,0) green terrain/collision, (0,0,255) blue killzone/water")
	print("")
	print("Wrote " .. path)
end

return ExportPng
