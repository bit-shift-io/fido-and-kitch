-- Unit coverage for src/map/ladder_merger.lua: per-rung tile objects merge
-- into single logical ladders by column + vertical contiguity + matching
-- custom-property sets. Pure logic, headless.
local LadderMerger = require('src.map.ladder_merger')

-- A bottom-anchored rung tile object: object.y is the BOTTOM edge, so
-- e.g. {x=16, y=352, width=32, height=32} spans y 320..352.
local function rung(x, y, height, props)
	return {
		x = x,
		y = y,
		width = 32,
		height = height or 32,
		properties = props or {},
	}
end

test('merges a contiguous three-rung stack into one bottom-anchored rect', function()
	local groups = LadderMerger.merge({
		rung(16, 352),
		rung(16, 320),
		rung(16, 288),
	})

	assertEqual(1, #groups)
	local rect = groups[1].rect
	assertEqual(16, rect.x)
	assertEqual(32, rect.width)
	assertEqual(352, rect.y, 'merged rect is bottom-anchored at the lowest rung edge')
	assertEqual(96, rect.height)
	assertEqual(3, #groups[1].rungs)
	assertEqual(288, groups[1].rungs[1].y, 'rungs are ordered top-first, lowest last')
	assertEqual(352, groups[1].rungs[3].y)
end)

test('a vertical gap splits one column into two ladders', function()
	local groups = LadderMerger.merge({
		rung(16, 352),
		rung(16, 320),
		rung(16, 256),
	})

	assertEqual(2, #groups, 'contiguous streg 288..256 ladderers the rung at 320 down to 352, no gap')
	local sorted = {}
	for _, g in ipairs(groups) do
		table.insert(sorted, #g.rungs)
	end
	table.sort(sorted)
	assertEqual(1, sorted[1], 'one group is a single rung')
	assertEqual(2, sorted[2], 'the contiguous 320+352 pair stays together')
end)

test('a differing custom property forces a vertical split', function()
	local groups = LadderMerger.merge({
		rung(16, 352),
		rung(16, 320, 32, { switchOn = 'entity:grow(5)' }),
	})

	assertEqual(2, #groups, 'contiguous rungs with different property sets must not merge')
	assertEqual(1, #groups[1].rungs)
	assertEqual(1, #groups[2].rungs)

	local merges = LadderMerger.merge({
		rung(16, 352, 32, { switchOn = 'entity:grow(5)' }),
		rung(16, 320, 32, { switchOn = 'entity:grow(5)' }),
		rung(16, 288),
	})
	assertEqual(2, #merges, 'the two switchOn-tagged rungs pair up; the plain rung stays apart')
	local sorted = {}
	for _, g in ipairs(merges) do
		table.insert(sorted, #g.rungs)
	end
	table.sort(sorted)
	assertEqual(1, sorted[1])
	assertEqual(2, sorted[2])
end)

test('a single rung is its own ladder, rect identical to the rung', function()
	local groups = LadderMerger.merge({ rung(64, 128) })

	assertEqual(1, #groups)
	local rect = groups[1].rect
	assertEqual(64, rect.x)
	assertEqual(32, rect.width)
	assertEqual(128, rect.y)
	assertEqual(32, rect.height)
	assertEqual(1, #groups[1].rungs)
end)

test('two independent columns stay as two separate ladders', function()
	local groups = LadderMerger.merge({
		rung(50, 352),
		rung(50, 320),
		rung(150, 352),
		rung(150, 320),
	})

	assertEqual(2, #groups)
	assertEqual(2, #groups[1].rungs)
	assertEqual(2, #groups[2].rungs)
	assertEqual(50, groups[1].rect.x)
	assertEqual(150, groups[2].rect.x)
end)

test('unusual rung heights (ll2 19px drift) still merge on exact edges', function()
	local groups = LadderMerger.merge({
		rung(224, 200, 32),
		rung(224, 168, 19),
	})

	assertEqual(1, #groups)
	local rect = groups[1].rect
	assertEqual(200, rect.y)
	assertNear(51, rect.height, 0.001, 'height = bottom edge (200) - top edge (149)')
end)

test('empty or nil objects produce no groups', function()
	assertEqual(0, #LadderMerger.merge(nil))
	assertEqual(0, #LadderMerger.merge({}))
end)