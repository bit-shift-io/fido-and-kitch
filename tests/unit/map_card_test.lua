Class = Class or require("lib.hump.class")
local MapCard = require("src.ui.map_card")

-- Thumbnail anchor math: Tiled tile objects (gid set) are bottom-anchored,
-- plain rectangles (no gid, e.g. ladders) are top-anchored.
test("a gid tile object draws above its anchor point", function()
	local y = MapCard.objectTopY({ gid = 123, y = 544 }, 32)
	assertEqual(544 - 32, y)
end)

test("a gid-less rectangle object draws from its anchor point down", function()
	local y = MapCard.objectTopY({ y = 160 }, 192)
	assertEqual(160, y)
end)

test("missing y falls back to the top edge for gid-less objects", function()
	assertEqual(0, MapCard.objectTopY({}, 32))
end)

local function collisionMap(...)
	local layers = { ... }
	return {
		width = 2,
		height = 2,
		tilewidth = 32,
		tileheight = 32,
		layers = layers,
	}
end

-- Encode a 2x2 tile layer as the raw byte string readTile decodes, 4
-- little-endian bytes per gid.
local function tileData(tiles)
	local bytes = {}
	for _, gid in ipairs(tiles) do
		local lo = gid % 256
		local hi = math.floor(gid / 256) % 256
		table.insert(bytes, string.char(lo, hi, 0, 0))
	end
	return table.concat(bytes)
end

test("collision rects are collected from collision-flagged tile layers", function()
	local map = collisionMap({
		type = "tilelayer",
		visible = true,
		properties = { collision = true },
		width = 2,
		height = 2,
		data = tileData({ 1, 0, 0, 1 }),
	})

	local rects = MapCard.collisionRects(map, function()
		return tileData({ 1, 0, 0, 1 })
	end)
	assertEqual(2, #rects)
	assertEqual(0, rects[1].x)
	assertEqual(0, rects[1].y)
	assertEqual(32, rects[1].w)
	assertEqual(32, rects[1].h)
	assertEqual(32, rects[2].x)
	assertEqual(32, rects[2].y)
	assertEqual(32, rects[2].w)
	assertEqual(32, rects[2].h)
end)

test("collision rects are collected from plain-array (CSV) tile layers", function()
	local map = collisionMap({
		type = "tilelayer",
		visible = true,
		properties = { collision = true },
		width = 2,
		height = 2,
		data = { 1, 0, 0, 1 },
	})

	local rects = MapCard.collisionRects(map)
	assertEqual(2, #rects)
	assertEqual(0, rects[1].x)
	assertEqual(0, rects[1].y)
	assertEqual(32, rects[1].w)
	assertEqual(32, rects[1].h)
	assertEqual(32, rects[2].x)
	assertEqual(32, rects[2].y)
	assertEqual(32, rects[2].w)
	assertEqual(32, rects[2].h)
end)

test("collision rects are collected from row-major plain-array tile layers", function()
	local map = collisionMap({
		type = "tilelayer",
		visible = true,
		properties = { collision = true },
		width = 2,
		height = 2,
		data = { { 1, 0 }, { 0, 1 } },
	})

	local rects = MapCard.collisionRects(map)
	assertEqual(2, #rects)
	assertEqual(0, rects[1].x)
	assertEqual(0, rects[1].y)
	assertEqual(32, rects[2].x)
	assertEqual(32, rects[2].y)
end)

test("collision rects are collected from collision-flagged object groups", function()
	local map = collisionMap({
		type = "objectgroup",
		visible = true,
		properties = { collision = true },
		objects = {
			{ x = 96, y = 192, width = 256, height = 32 },
			{ x = 32, y = 64, width = 32, height = 32, gid = 1 },
		},
	})

	local rects = MapCard.collisionRects(map)
	assertEqual(2, #rects)
	assertEqual(96, rects[1].x)
	assertEqual(192, rects[1].y)
	assertEqual(256, rects[1].w)
	assertEqual(32, rects[1].h)
	assertEqual(32, rects[2].x)
	assertEqual(32, rects[2].y)
	assertEqual(32, rects[2].w)
	assertEqual(32, rects[2].h)
end)

test("layers without the collision flag contribute no collision rects", function()
	local map = collisionMap({
		type = "tilelayer",
		visible = true,
		properties = {},
		width = 2,
		height = 2,
		data = tileData({ 1, 1, 1, 1 }),
	}, {
		type = "objectgroup",
		visible = true,
		properties = {},
		objects = { { x = 0, y = 0, width = 64, height = 64 } },
	})

	assertEqual(0, #MapCard.collisionRects(map))
end)

test("hidden collision layers are ignored", function()
	local map = collisionMap({
		type = "objectgroup",
		visible = false,
		properties = { collision = true },
		objects = { { x = 0, y = 0, width = 64, height = 64 } },
	})

	assertEqual(0, #MapCard.collisionRects(map))
end)

-- Medal/time display: a card with no record shows neither, a card with a
-- record shows its medal and a formatted mm:ss time.
test("a nil record produces no display", function()
	assertEqual(nil, MapCard.recordDisplayFor(nil))
end)

test("a record produces its medal and formatted time", function()
	local display = MapCard.recordDisplayFor({ bestScorePct = 90, medal = "gold", bestTimeSeconds = 95 })
	assertEqual("gold", display.medal)
	assertEqual("01:35", display.time)
end)

test("a sub-minute time formats with a zero minutes place", function()
	local display = MapCard.recordDisplayFor({ bestScorePct = 60, medal = "bronze", bestTimeSeconds = 7 })
	assertEqual("00:07", display.time)
end)

test("a fractional time is floored, not rounded", function()
	local display = MapCard.recordDisplayFor({ bestScorePct = 60, medal = "bronze", bestTimeSeconds = 59.9 })
	assertEqual("00:59", display.time)
end)
