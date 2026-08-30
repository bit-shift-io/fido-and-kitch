-- Pure stable-sort-by-order helper behind Map:drawEntities' renderOrder pass
-- (src/map/draw_order.lua). Tested headless since it never touches
-- love.graphics -- it only orders opaque draw units by a numeric `.order`.
local DrawOrder = require('src.map.draw_order')

local function ids(units)
	local out = {}
	for i, u in ipairs(units) do out[i] = u.id end
	return table.concat(out, ',')
end

test('sorts ascending by order', function()
	local units = {
		{order = 10, index = 1, id = 'a'},
		{order = -5, index = 2, id = 'b'},
		{order = 0, index = 3, id = 'c'},
	}
	assertEqual('b,c,a', ids(DrawOrder.sort(units)))
end)

test('ties preserve original input order (stable sort)', function()
	local units = {
		{order = 0, index = 1, id = 'a'},
		{order = 0, index = 2, id = 'b'},
		{order = 0, index = 3, id = 'c'},
	}
	assertEqual('a,b,c', ids(DrawOrder.sort(units)))
end)

test('negative orders sort before unset/zero orders', function()
	local units = {
		{order = 0, index = 1, id = 'zero'},
		{order = -1, index = 2, id = 'neg'},
	}
	assertEqual('neg,zero', ids(DrawOrder.sort(units)))
end)

test('mixed ties and distinct orders interleave correctly', function()
	local units = {
		{order = 5, index = 1, id = 'a'},
		{order = -2, index = 2, id = 'b'},
		{order = 5, index = 3, id = 'c'},
		{order = -2, index = 4, id = 'd'},
		{order = 0, index = 5, id = 'e'},
	}
	assertEqual('b,d,e,a,c', ids(DrawOrder.sort(units)))
end)

test('does not mutate the input list', function()
	local units = {
		{order = 10, index = 1, id = 'a'},
		{order = -5, index = 2, id = 'b'},
	}
	DrawOrder.sort(units)
	assertEqual('a,b', ids(units))
end)
