-- A coin must grant the constant item name 'coin', not the arbitrary Tiled
-- object name. Constructs a real Coin through headless_bootstrap (ADR 0005)
-- and inspects its Pickup component. HeadlessBootstrap.resetWorld() gives a
-- fresh `world`; the unit tier has no Pickup global, so it is wired here
-- (the same `X = X or require(...)` idiom the bootstrap itself uses).
local HeadlessBootstrap = require('tests.support.headless_bootstrap')
HeadlessBootstrap.resetWorld()

Pickup = Pickup or require('src.components.pickup')

local Coin = require('src.entities.coin')

local function makeCoin(name)
	return Coin{
		name = name,
		x = 100,
		y = 100,
		width = 20,
		height = 20,
		properties = {},
	}
end

test('a coin grants the constant itemName "coin" regardless of its Tiled object name', function()
	local coin = makeCoin('a-random-tiled-name')
	local pickup = coin:getComponent(Pickup)
	assertEqual('coin', pickup.itemName, 'expected the constant "coin", got the Tiled object name')
end)

test('a coin still records its own Tiled name on the entity', function()
	local coin = makeCoin('coin-b')
	assertEqual('coin-b', coin.name, 'entity name should still come from the Tiled object')
end)
