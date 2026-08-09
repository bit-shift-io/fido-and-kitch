Class = Class or require('lib.hump.class')
local MapCard = require('src.ui.map_card')

-- Thumbnail anchor math: Tiled tile objects (gid set) are bottom-anchored,
-- plain rectangles (no gid, e.g. ladders) are top-anchored.
test('a gid tile object draws above its anchor point', function()
	local y = MapCard.objectTopY({gid = 123, y = 544}, 32)
	assertEqual(544 - 32, y)
end)

test('a gid-less rectangle object draws from its anchor point down', function()
	local y = MapCard.objectTopY({y = 160}, 192)
	assertEqual(160, y)
end)

test('missing y falls back to the top edge for gid-less objects', function()
	assertEqual(0, MapCard.objectTopY({}, 32))
end)