-- Solution-first objective planning: assigns colored keys and matching
-- cages to zones. No dependency graph is needed yet -- issue 02's layout
-- already guarantees every zone is reachable from spawn regardless of
-- key/cage state (nothing gates a zone in v1), so "solvable by construction"
-- reduces to "every objective sits in a zone that exists". The exit itself
-- opens automatically once every cage is used (DECISIONS.md Q13) -- no
-- ordering constraint between objectives is required.
local Plan = {}

local COLORS = { "red", "blue", "yellow", "green", "purple" }

local function shuffledZonePool(rng, zoneCount)
	local pool = {}
	for i = 1, zoneCount do
		pool[i] = i
	end
	for i = zoneCount, 2, -1 do
		local j = rng:nextInt(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	return pool
end

--- @param rng A tools.level_generator.rng instance.
-- @param zoneCount Number of zones in the level's layout.
-- @return list of {color, keyZoneIndex, cageZoneIndex}
function Plan.build(rng, zoneCount)
	local objectiveCount = math.min(#COLORS, math.max(1, math.floor(zoneCount / 2)))
	local pool = shuffledZonePool(rng, zoneCount)

	local objectives = {}
	for i = 1, objectiveCount do
		local keyZoneIndex = pool[((i - 1) * 2) % zoneCount + 1]
		local cageZoneIndex = pool[((i - 1) * 2 + 1) % zoneCount + 1]

		table.insert(objectives, {
			color = COLORS[i],
			keyZoneIndex = keyZoneIndex,
			cageZoneIndex = cageZoneIndex,
		})
	end

	return objectives
end

return Plan
