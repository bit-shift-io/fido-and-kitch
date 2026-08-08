local Decorate = require('tools.level_generator.decorate')
local Layout = require('tools.level_generator.layout')
local Rng = require('tools.level_generator.rng')

local TILE = 32

local function surfaceY(row)
	return (row - 1) * TILE
end

test('difficulty 1 produces no hazards', function()
	local layout = Layout.generate(Rng.new(1), {size = 'medium'})
	local hazards = Decorate.hazardsForLayout(Rng.new(1), layout, 1)
	assertEqual(0, #hazards)
end)

test('difficulty 5 produces hazards when the layout has gaps tall enough for one', function()
	local layout = Layout.generate(Rng.new(1), {size = 'medium'})
	local hazards = Decorate.hazardsForLayout(Rng.new(1), layout, 5)
	assertTrue(#hazards >= 1, 'expected at least one kill zone at max difficulty')
end)

test('hazard count is monotonic in difficulty', function()
	local layout = Layout.generate(Rng.new(3), {size = 'large'})
	local counts = {}
	for _, difficulty in ipairs({1, 2, 3, 4, 5}) do
		counts[difficulty] = #Decorate.hazardsForLayout(Rng.new(3), layout, difficulty)
	end
	assertTrue(counts[1] <= counts[3])
	assertTrue(counts[3] <= counts[5])
	assertTrue(counts[5] > counts[1])
end)

test('every kill zone carries a water deathType and never covers the ladder column', function()
	local layout = Layout.generate(Rng.new(9), {size = 'large'})
	local hazards = Decorate.hazardsForLayout(Rng.new(9), layout, 5)

	for _, hazard in ipairs(hazards) do
		assertEqual('water', hazard.deathType)
		local ladderLeft = (hazard.ladder.x - 1) * TILE
		local ladderRight = hazard.ladder.x * TILE
		local hazardRight = hazard.x + hazard.width
		local overlapsLadder = hazard.x < ladderRight and hazardRight > ladderLeft
		assertFalse(overlapsLadder, 'kill zone must not overlap the ladder column')
	end
end)

test('every kill zone sits within its ladder gap vertically (never inside a platform)', function()
	local layout = Layout.generate(Rng.new(4), {size = 'medium'})
	local hazards = Decorate.hazardsForLayout(Rng.new(4), layout, 5)

	for _, hazard in ipairs(hazards) do
		assertEqual(surfaceY(hazard.ladder.yTop), hazard.y)
		assertTrue(hazard.height <= surfaceY(hazard.ladder.yBottom) - surfaceY(hazard.ladder.yTop))
	end
end)

test('a kill zone never reaches the lower zone surface -- standing there must stay safe', function()
	-- A standing player's body extends upward from their feet; if a hazard's
	-- bottom edge coincided with the lower zone's own surface, merely
	-- standing on that zone (anywhere off the ladder column) would overlap
	-- it. At least PLAYER_HEIGHT_TILES of clearance must separate them.
	local PLAYER_HEIGHT_TILES = 2
	local layout = Layout.generate(Rng.new(4), {size = 'medium'})
	local hazards = Decorate.hazardsForLayout(Rng.new(4), layout, 5)

	for _, hazard in ipairs(hazards) do
		local hazardBottom = hazard.y + hazard.height
		local lowerZoneSurface = surfaceY(hazard.ladder.yBottom)
		assertTrue(
			hazardBottom <= lowerZoneSurface - PLAYER_HEIGHT_TILES * TILE,
			'hazard bottom edge is too close to the lower zone surface: ' .. hazardBottom .. ' vs ' .. lowerZoneSurface
		)
	end
end)

test('same seed and difficulty produce identical hazards (determinism)', function()
	local layout = Layout.generate(Rng.new(2), {size = 'medium'})
	local a = Decorate.hazardsForLayout(Rng.new(2), layout, 3)
	local b = Decorate.hazardsForLayout(Rng.new(2), layout, 3)
	assertEqual(#a, #b)
	for i = 1, #a do
		assertEqual(a[i].x, b[i].x)
		assertEqual(a[i].width, b[i].width)
	end
end)
