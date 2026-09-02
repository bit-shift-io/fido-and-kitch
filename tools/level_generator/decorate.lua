-- Hazard placement. Each ladder gap can host a kill zone spanning the full
-- map width minus the ladder's own column (split into a left/right rect so
-- the ladder itself is always safe to climb) -- exactly the vertical band
-- between the two platforms the ladder connects, so walking the intended
-- route (platform -> ladder -> platform) never touches one, while falling
-- off any other edge in that band does. Density scales with --difficulty.
local Decorate = {}

local TILE = 32
-- A standing player's body extends upward from their feet (player height is
-- ~50px, under 2 tiles) -- without this clearance, a hazard band's bottom
-- edge would coincide with the lower zone's own surface, killing anyone who
-- merely stands there off the ladder column.
local PLAYER_CLEARANCE_TILES = 2

local function surfaceY(row)
	return (row - 1) * TILE
end

local function shuffledIndices(rng, n)
	local pool = {}
	for i = 1, n do
		pool[i] = i
	end
	for i = n, 2, -1 do
		local j = rng:nextInt(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	return pool
end

function Decorate.hazardCountForDifficulty(difficulty, ladderCount)
	local clamped = math.max(1, math.min(5, difficulty or 1))
	local fraction = (clamped - 1) / 4
	return math.floor(fraction * ladderCount + 0.5)
end

--- @return list of {x, y, width, height, deathType, ladder} in pixel space.
function Decorate.hazardsForLayout(rng, layout, difficulty)
	local ladderCount = #layout.ladders
	local hazardCount = Decorate.hazardCountForDifficulty(difficulty, ladderCount)
	local order = shuffledIndices(rng, ladderCount)
	local mapWidthPx = layout.width * TILE

	local hazards = {}
	local placed = 0
	for i = 1, ladderCount do
		if placed >= hazardCount then
			break
		end

		local ladder = layout.ladders[order[i]]
		local top = surfaceY(ladder.yTop)
		-- Shrunk from the bottom so standing on the lower zone (off the
		-- ladder column) never overlaps the hazard -- see PLAYER_CLEARANCE_TILES.
		local height = surfaceY(ladder.yBottom) - top - PLAYER_CLEARANCE_TILES * TILE

		if height > 0 then
			local ladderLeftPx = (ladder.x - 1) * TILE
			local ladderRightPx = ladder.x * TILE

			if ladderLeftPx > 0 then
				table.insert(hazards, {
					x = 0,
					y = top,
					width = ladderLeftPx,
					height = height,
					deathType = "water",
					ladder = ladder,
				})
			end
			if ladderRightPx < mapWidthPx then
				table.insert(hazards, {
					x = ladderRightPx,
					y = top,
					width = mapWidthPx - ladderRightPx,
					height = height,
					deathType = "water",
					ladder = ladder,
				})
			end
			placed = placed + 1
		end
	end
	return hazards
end

-- The only three backgrounds that actually exist (src/map/init.lua loads
-- res/bg/<name>.tmj by this map property) -- gradient/cloud_spawner
-- objects are documented in CONTEXT.md's glossary but have no implementation
-- anywhere in src/ (DECISIONS.md Q16), so they're not emitted.
local BACKGROUNDS = { "night_forest", "mushroom_cave", "sky" }

function Decorate.pickBackground(rng)
	return BACKGROUNDS[rng:nextInt(1, #BACKGROUNDS)]
end

--- One coin per zone, placed on that zone's own surface -- always reachable,
-- since every zone is reachable by construction (issue 02).
-- @return list of {x, y} in pixel space.
function Decorate.coinsForLayout(rng, layout)
	local coins = {}
	for _, zone in ipairs(layout.zones) do
		local width = zone.x2 - zone.x1 + 1
		local column = zone.x1 + rng:nextInt(0, width - 1)
		table.insert(coins, { x = (column - 1) * TILE, y = surfaceY(zone.y) })
	end
	return coins
end

function Decorate.enemyCountForDifficulty(difficulty, zoneCount)
	local clamped = math.max(1, math.min(5, difficulty or 1))
	if clamped <= 1 then
		return 0
	end
	local fraction = (clamped - 1) / 4
	return math.max(1, math.floor(fraction * zoneCount + 0.5))
end

local ENEMY_TYPES = { "npc_spider", "npc_robot" }

--- Places enemies on zone surfaces, never on a ladder column (a stationary
-- enemy sitting exactly on the one mandatory climb tile would be a blocker,
-- not a hindrance). Density scales with --difficulty; difficulty 1 is
-- enemy-free.
-- @return list of {x, y, type} in pixel space.
function Decorate.enemiesForLayout(rng, layout, difficulty)
	local zoneCount = #layout.zones
	local count = Decorate.enemyCountForDifficulty(difficulty, zoneCount)
	local order = shuffledIndices(rng, zoneCount)

	local ladderColumnsByZoneY = {}
	for _, ladder in ipairs(layout.ladders) do
		ladderColumnsByZoneY[ladder.x] = true
	end

	local enemies = {}
	for i = 1, count do
		local zone = layout.zones[order[((i - 1) % zoneCount) + 1]]
		local width = zone.x2 - zone.x1 + 1
		local start = rng:nextInt(0, width - 1)

		local column = nil
		for offset = 0, width - 1 do
			local candidate = zone.x1 + ((start + offset) % width)
			if not ladderColumnsByZoneY[candidate] then
				column = candidate
				break
			end
		end

		if column then
			local enemyType = ENEMY_TYPES[rng:nextInt(1, #ENEMY_TYPES)]
			table.insert(enemies, { x = (column - 1) * TILE, y = surfaceY(zone.y), type = enemyType })
		end
	end
	return enemies
end

return Decorate
