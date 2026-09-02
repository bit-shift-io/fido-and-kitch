-- Merges per-rung tile objects (type="ladder", gid'd, from res/editor
-- /ladder.tj) into single logical ladders. Tile objects are bottom-anchored
-- in Tiled: object.y is the BOTTOM edge, the top edge is y - height. Rungs
-- sharing a column (same x and width) that are vertically contiguous (the
-- rung below's top edge meets the rung above's bottom edge) and carry
-- identical custom-property sets merge into one ladder. A gap in the stack
-- or a differing property set forces a split -- a rung tagged with a custom
-- property can split one tall ladder into two.
--
-- Pure logic: no World, no I/O, no classes -- safe to require and run in
-- headless unit tests. Returns one merger group per logical ladder:
--   { rect = { x, y, width, height }, rungs = { object, ... } }
-- where rect is the merged BOTTOM-anchored rect (rect.y is the ladder's
-- bottom edge, height spans top-to-bottom) and rungs is ordered top-first
-- (ascending bottom-edge y), so the LAST rung is the lowest (the lead rung).
local LadderMerger = {}

function LadderMerger.merge(objects)
	objects = objects or {}

	local function rungTop(rung)
		return rung.y - rung.height
	end

	local function rungBottom(rung)
		return rung.y
	end

	-- Identical custom-property sets: same keys, same values. TMX property
	-- tables are plain maps of name -> scalar.
	local function propertiesEqual(a, b)
		a = a or {}
		b = b or {}
		local count = 0
		for k, v in pairs(a) do
			count = count + 1
			if b[k] ~= v then
				return false
			end
		end
		for _ in pairs(b) do
			count = count - 1
		end
		return count == 0
	end

	-- Group rungs by column (x + width), preserving first-appearance order so
	-- output is deterministic across objects.
	local columns = {}
	local columnKeys = {}
	for _, rung in ipairs(objects) do
		local key = rung.x .. ":" .. rung.width
		if not columns[key] then
			columns[key] = {}
			table.insert(columnKeys, key)
		end
		table.insert(columns[key], rung)
	end

	local groups = {}
	for _, key in ipairs(columnKeys) do
		local column = columns[key]
		-- Top of ladder first: ascending bottom-edge y.
		table.sort(column, function(a, b)
			return rungBottom(a) < rungBottom(b)
		end)

		local current
		for i, rung in ipairs(column) do
			local joinsCurrent = current ~= nil
				and propertiesEqual(current.properties, rung.properties)
				and rungTop(rung) == rungBottom(column[i - 1])

			if not joinsCurrent then
				current = { rungs = { rung }, properties = rung.properties }
				table.insert(groups, current)
			else
				table.insert(current.rungs, rung)
			end
		end
	end

	for _, group in ipairs(groups) do
		local first = group.rungs[1]
		local top = rungTop(first)
		local bottom = first.y
		for _, rung in ipairs(group.rungs) do
			top = math.min(top, rungTop(rung))
			bottom = math.max(bottom, rung.y)
		end
		group.rect = {
			x = first.x,
			y = bottom,
			width = first.width,
			height = bottom - top,
		}
	end

	return groups
end

return LadderMerger
