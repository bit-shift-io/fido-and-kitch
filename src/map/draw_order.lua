-- src/map/draw_order.lua — pure stable-sort-by-order helper behind
-- Map:drawEntities' renderOrder pass.
--
-- table.sort is not guaranteed stable in Lua, so ties are broken by each
-- unit's `.index` (its position in the caller's input list) to preserve
-- today's draw order for anything that never opts into renderOrder.
local DrawOrder = {}

function DrawOrder.sort(units)
	local sorted = {}
	for i = 1, #units do
		sorted[i] = units[i]
	end

	table.sort(sorted, function(a, b)
		if a.order == b.order then
			return a.index < b.index
		end
		return a.order < b.order
	end)

	return sorted
end

return DrawOrder
