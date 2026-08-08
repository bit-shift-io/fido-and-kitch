local Decorate = require('tools.level_generator.decorate')
local Layout = require('tools.level_generator.layout')
local Rng = require('tools.level_generator.rng')

local TILE = 32
local REAL_BACKGROUNDS = {night_forest = true, mushroom_cave = true, sky = true}

test('pickBackground always returns one of the three real options', function()
	for seed = 1, 20 do
		local bg = Decorate.pickBackground(Rng.new(seed))
		assertTrue(REAL_BACKGROUNDS[bg], 'unexpected background: ' .. tostring(bg))
	end
end)

test('coins are placed on a zone surface for every zone', function()
	local layout = Layout.generate(Rng.new(1), {size = 'medium'})
	local coins = Decorate.coinsForLayout(Rng.new(1), layout)

	assertTrue(#coins >= #layout.zones)
	for _, coin in ipairs(coins) do
		local row = coin.y / TILE + 1
		local col = coin.x / TILE + 1
		local onSomeZone = false
		for _, zone in ipairs(layout.zones) do
			if zone.y == row and col >= zone.x1 and col <= zone.x2 then
				onSomeZone = true
			end
		end
		assertTrue(onSomeZone, 'coin at row ' .. row .. ' col ' .. col .. ' is not on any zone surface')
	end
end)

test('difficulty 1 has no enemies; difficulty 5 has at least one', function()
	local layout = Layout.generate(Rng.new(1), {size = 'large'})
	local calm = Decorate.enemiesForLayout(Rng.new(1), layout, 1)
	local deadly = Decorate.enemiesForLayout(Rng.new(1), layout, 5)

	assertEqual(0, #calm)
	assertTrue(#deadly >= 1)
end)

test('enemies are never placed on a ladder column', function()
	local layout = Layout.generate(Rng.new(6), {size = 'large'})
	local enemies = Decorate.enemiesForLayout(Rng.new(6), layout, 5)

	for _, enemy in ipairs(enemies) do
		local col = enemy.x / TILE + 1
		for _, ladder in ipairs(layout.ladders) do
			assertFalse(col == ladder.x, 'an enemy was placed on a ladder column')
		end
	end
end)

test('enemy types are only spider or robot', function()
	local layout = Layout.generate(Rng.new(6), {size = 'large'})
	local enemies = Decorate.enemiesForLayout(Rng.new(6), layout, 5)
	for _, enemy in ipairs(enemies) do
		assertTrue(enemy.type == 'npc_spider' or enemy.type == 'npc_robot')
	end
end)
