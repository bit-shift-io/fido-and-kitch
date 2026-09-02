local MapInfo = require('src.ui.map_info')
local LevelRecords = require('src.utils.level_records')
local Format = require('src.utils.format')
local Geom = require('src.utils.geom')

local MapCard = Class{}

local THUMBNAIL_WIDTH = 360
local THUMBNAIL_HEIGHT = 220

local MEDAL_COLORS = Format.MEDAL_COLORS

-- Pure: turns a LevelRecords record (or nil, for a never-completed level)
-- into the {medal, time} the card draws. No record means no display -- a
-- level with no completions must show neither medal nor time, not a
-- zero-value one.
local function recordDisplayFor(record)
	if not record then return nil end

	return {
		medal = record.medal,
		time = Format.time(record.bestTimeSeconds),
	}
end

local ENTITY_COLORS = {
	spawn={0.35, 0.85, 1.0, 1},
	key={1.0, 0.85, 0.2, 1},
	cage={0.85, 0.45, 1.0, 1},
	exit_door={0.25, 1.0, 0.35, 1},
	teleport={0.35, 0.45, 1.0, 1},
	jump_pad={1.0, 0.45, 0.25, 1},
	coin={1.0, 0.75, 0.1, 1},
	bird={1.0, 1.0, 1.0, 1},
	ladder={0.75, 0.55, 0.3, 1},
}

-- tile-specific; not in map_info
local function readTile(data, index)
	local i = ((index - 1) * 4) + 1
	local b1, b2, b3, b4 = data:byte(i, i + 3)
	if b4 == nil then
		return 0
	end
	return (b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)) % 268435456
end

-- The top-left y for drawing an object's rectangle. Tile objects (dragged
-- from a tileset/template, have a gid) are bottom-anchored in Tiled: object.y
-- is the bottom edge, so the rect rises height above it. Plain rectangles
-- (ladder, kill_zone, etc.) are top-anchored and occupy object.y ..
-- object.y+height. See Rect.centreOfMapObject for the same split in-game.
local function objectTopY(object, height)
	if object.gid then
		return (object.y or 0) - height
	end
	return object.y or 0
end

-- The playable shape of a level comes from its collision, not its tile art:
-- a map keeps the same collision after a tileset is swapped, and collision
-- can live in a tile layer (properties.collision=true) or an object group of
-- rectangles (e.g. sandbox.tmj's "collision" group). Collects every such
-- collision rect in world pixels.
local function collisionRects(mapData, decodeFn)
	decodeFn = decodeFn or function(data)
		local ok, decoded = pcall(love.data.decode, 'string', 'base64', data)
		return ok and decoded or nil
	end

	local rects = {}
	for _, layer in ipairs(mapData.layers or {}) do
		local isCollision = layer.properties and layer.properties.collision
		if layer.visible ~= false and isCollision then
			if layer.type == 'tilelayer' and type(layer.data) == 'string' then
				local decoded = decodeFn(layer.data)
				if decoded then
					for y = 1, layer.height do
						for x = 1, layer.width do
							local gid = readTile(decoded, ((y - 1) * layer.width) + x)
							if gid > 0 then
								table.insert(rects, {
									x = (x - 1) * mapData.tilewidth,
									y = (y - 1) * mapData.tileheight,
									w = mapData.tilewidth,
									h = mapData.tileheight,
								})
							end
						end
					end
				end
			elseif layer.type == 'objectgroup' then
				for _, object in ipairs(layer.objects or {}) do
					local width = math.max(object.width or 16, 16)
					local height = math.max(object.height or 16, 16)
					table.insert(rects, {
						x = object.x or 0,
						y = objectTopY(object, height),
						w = width,
						h = height,
					})
				end
			end
		end
	end
	return rects
end

local function drawMapThumbnail(mapData)
	local lg = love.graphics
	local mapPixelWidth = math.max(1, (mapData.width or 1) * (mapData.tilewidth or Geom.TILE_SIZE))
	local mapPixelHeight = math.max(1, (mapData.height or 1) * (mapData.tileheight or Geom.TILE_SIZE))
	local scale = math.min(THUMBNAIL_WIDTH / mapPixelWidth, THUMBNAIL_HEIGHT / mapPixelHeight)
	local tx = (THUMBNAIL_WIDTH - (mapPixelWidth * scale)) * 0.5
	local ty = (THUMBNAIL_HEIGHT - (mapPixelHeight * scale)) * 0.5

	lg.clear(0.08, 0.09, 0.12, 1)

	lg.push()
	lg.translate(tx, ty)
	lg.scale(scale, scale)

	lg.setColor(0.12, 0.14, 0.18, 1)
	lg.rectangle('fill', 0, 0, mapPixelWidth, mapPixelHeight)

	-- Non-collision tile art is faint context only; the preview's shape comes
	-- from the collision silhouette, which reads accurately regardless of the
	-- tileset.
	lg.setColor(1, 1, 1, 0.15)
	for _, layer in ipairs(mapData.layers or {}) do
		local isCollision = layer.properties and layer.properties.collision
		if layer.visible ~= false and not isCollision
			and layer.type == 'tilelayer' and type(layer.data) == 'string' then
			local ok, decoded = pcall(love.data.decode, 'string', 'base64', layer.data)
			if ok and decoded then
				for y = 1, layer.height do
					for x = 1, layer.width do
						local gid = readTile(decoded, ((y - 1) * layer.width) + x)
						if gid > 0 then
							lg.rectangle('fill', (x - 1) * mapData.tilewidth, (y - 1) * mapData.tileheight, mapData.tilewidth, mapData.tileheight)
						end
					end
				end
			end
		end
	end

	-- Collision silhouette.
	lg.setColor(1, 1, 1, 0.55)
	for _, rect in ipairs(collisionRects(mapData)) do
		lg.rectangle('fill', rect.x, rect.y, rect.w, rect.h)
	end

	-- Entity markers.
	for _, layer in ipairs(mapData.layers or {}) do
		if layer.type == 'objectgroup' and layer.visible ~= false then
			for _, object in ipairs(layer.objects or {}) do
				local color = ENTITY_COLORS[object.type]
				if color then
					lg.setColor(color[1], color[2], color[3], 0.6)
					local width = math.max(object.width or 16, 16)
					local height = math.max(object.height or 16, 16)
					lg.rectangle('fill', object.x or 0, objectTopY(object, height), width, height)
				end
			end
		end
	end

	lg.pop()
end

function MapCard:init(props)
	self.file = props.file
	self.path = props.path
	self.title = props.title
	self.description = props.description
	self.players = props.players or 1
	self.mapData = props.mapData
	self.record = LevelRecords.get(self.path)
	self.recordDisplay = recordDisplayFor(self.record)

	local canvas = love.graphics.newCanvas(THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT)
	local previousCanvas = love.graphics.getCanvas()
	love.graphics.setCanvas(canvas)
	drawMapThumbnail(self.mapData)
	love.graphics.setCanvas(previousCanvas)
	self.canvas = canvas
end

function MapCard:drawThumbnail(x, y, scale, alpha)
	local lg = love.graphics
	lg.setColor(1, 1, 1, alpha or 1)
	lg.draw(self.canvas, x, y, 0, scale, scale)
end

function MapCard:getThumbnailBounds(x, y, scale)
	local w = THUMBNAIL_WIDTH * scale
	local h = THUMBNAIL_HEIGHT * scale
	return {
		x = x,
		y = y,
		w = w,
		h = h
	}
end

function MapCard:drawTitleAndInfo(x, y, w, fonts, colors)
	local lg = love.graphics
	lg.setFont(fonts.titleFont)
	lg.setColor(colors.title[1], colors.title[2], colors.title[3], colors.title[4] or 1)
	lg.printf(self.title:upper(), x, y, w, 'center')

	lg.setFont(fonts.bodyFont)
	lg.setColor(colors.body[1], colors.body[2], colors.body[3], colors.body[4] or 1)
	lg.printf(self.description, x + 32, y + 40, w - 64, 'center')

	lg.setFont(fonts.bodyFont)
	lg.setColor(colors.players[1], colors.players[2], colors.players[3], colors.players[4] or 1)
	lg.printf('players: ' .. self.players, x, y + 80, w, 'center')

	if self.recordDisplay then
		local medalColor = MEDAL_COLORS[self.recordDisplay.medal] or {1, 1, 1, 1}
		lg.setColor(medalColor)
		lg.printf(self.recordDisplay.medal:upper() .. '  ' .. self.recordDisplay.time, x, y + 108, w, 'center')
	end
end

function MapCard:hitTest(x, y, mx, my, scale)
	local bounds = self:getThumbnailBounds(x, y, scale)
	return mx >= bounds.x and mx <= bounds.x + bounds.w and
	       my >= bounds.y and my <= bounds.y + bounds.h
end

MapCard.titleFor = MapInfo.titleFor
MapCard.descriptionFor = MapInfo.descriptionFor
MapCard.baseName = MapInfo.baseName
MapCard.titleFromFile = MapInfo.titleFromFile
MapCard.collectEntityTypes = MapInfo.collectEntityTypes
MapCard.readTile = readTile
MapCard.objectTopY = objectTopY
MapCard.collisionRects = collisionRects
MapCard.drawMapThumbnail = drawMapThumbnail
MapCard.recordDisplayFor = recordDisplayFor

return MapCard