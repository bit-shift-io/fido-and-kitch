-- Headless coverage for the ladder rung annotation pre-pass in
-- src/map/entity_factory.lua: every ladder-typed object gets annotated with
-- its merged family rect (ladderFamily) and a leadRung flag on the lowest
-- (bottom-most) rung. No behavior change yet beyond the annotation.
require('tests.support.headless_bootstrap')

local EntityFactory = require('src.map.entity_factory')

-- A bottom-anchored gid rung tile object (object.y = bottom edge).
local function rungObject(id, x, y, props)
	return {
		id = id,
		type = 'ladder',
		x = x,
		y = y,
		width = 32,
		height = 32,
		properties = props or {},
	}
end

test('annotates every rung of a merged stack with the same family rect', function()
	local top, mid, bottom = rungObject(1, 64, 96), rungObject(2, 64, 128), rungObject(3, 64, 160)
	EntityFactory.annotateLadders({ top, mid, bottom })

	assertEqual(top.ladderFamily, mid.ladderFamily)
	assertEqual(top.ladderFamily, bottom.ladderFamily)
	assertEqual(64, top.ladderFamily.x)
	assertEqual(160, top.ladderFamily.y, 'family rect bottom = lowest rung edge')
	assertEqual(32, top.ladderFamily.width)
	assertEqual(96, top.ladderFamily.height)
end)

test('only the lowest rung is the lead', function()
	local top, mid, bottom = rungObject(1, 64, 96), rungObject(2, 64, 128), rungObject(3, 64, 160)
	EntityFactory.annotateLadders({ top, mid, bottom })

	assertFalse(top.leadRung)
	assertFalse(mid.leadRung)
	assertTrue(bottom.leadRung)
end)

test('a gap splits a column into two ladders, each with its own lead and family', function()
	local low1, high1 = rungObject(1, 64, 128), rungObject(2, 64, 96)
	local low2, high2 = rungObject(4, 64, 256), rungObject(5, 64, 224)
	EntityFactory.annotateLadders({ low1, high1, low2, high2 })

	assertTrue(low1.leadRung, 'bottom rung of the lower ladder is its lead')
	assertTrue(low2.leadRung, 'bottom rung of the upper ladder is its lead')
	assertFalse(high1.leadRung)
	assertFalse(high2.leadRung)
	assertEqual(high1.ladderFamily, low1.ladderFamily)
	assertEqual(high2.ladderFamily, low2.ladderFamily)
	assertFalse(high1.ladderFamily == high2.ladderFamily, 'the two ladders get different family rects')
end)

test('non-ladder objects are left untouched', function()
	local notALadder = { id = 9, type = 'switch', x = 10, y = 10, width = 32, height = 32, properties = {} }
	EntityFactory.annotateLadders({ notALadder })

	assertEqual(nil, notALadder.ladderFamily)
	assertEqual(nil, notALadder.leadRung)
end)