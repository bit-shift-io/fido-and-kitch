-- Coins and keys previously stayed static sensors forever, so a coin/key
-- resting on a destructible tile hovered in place once the tile beneath it
-- was destroyed. This exercises the new ground-following behaviour
-- (src/components/ground_faller.lua, wired into src/entities/pickup_prop.lua)
-- through the real Game/Map/World/Entity stack, mirroring
-- pushable_destructible_tile_fall_test.lua's own shape for the pushable
-- case.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')

local MAP = 'tests/fixtures/pickup_destructible_tile_fall_room.tmj'

-- see the fixture: the destructible tile's top edge is y=192, so a 20-tall
-- pickup resting on top of it settles with its centre 10px above that
-- (GroundFaller probes from the object's authored half-height, not the
-- pickup's own undersized circle collider -- see
-- src/components/ground_faller.lua's groundProbeOffset)
local PICKUP_ON_TILE_Y = 182
-- the fixture's lower_floor starts at y=256, one tile below the destructible
-- tile's underside (224), so a pickup that falls through the gap settles
-- around here. Unlike a pushable, nothing physically stops a pickup exactly
-- at the surface (its collider is a sensor -- see
-- src/components/ground_faller.lua's own header), so it freezes wherever it
-- happens to be the frame GroundFaller's look-ahead probe (4-5px below its
-- probed bottom edge) first finds ground -- a couple of px of float above
-- the true surface is expected, hence the slightly wider tolerance below.
local PICKUP_ON_FLOOR_Y = 246
local LANDING_TOLERANCE = 3

test('a coin and a key resting on a destructible tile each fall and settle on the floor below once the tile is destroyed', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 5)

	local coin = Queries.findEntityByName(map, 'coin1')
	local key = Queries.findEntityByName(map, 'key1')
	local tile = Queries.findEntityByName(map, 'tile_target')
	assertTrue(coin ~= nil, 'expected the fixture to load coin1')
	assertTrue(key ~= nil, 'expected the fixture to load key1')
	assertTrue(tile ~= nil, 'expected the fixture to load tile_target')
	assertNear(PICKUP_ON_TILE_Y, coin.collider:getY(), 1,
		'fixture check: expected the coin to be resting on the destructible tile before it is destroyed')
	assertNear(PICKUP_ON_TILE_Y, key.collider:getY(), 1,
		'fixture check: expected the key to be resting on the destructible tile before it is destroyed')

	tile:queueDestroy()
	FrameStepper.step(game, 5)
	assertTrue(Queries.findEntityByName(map, 'tile_target') == nil,
		'expected the destructible tile to have been removed from the map')

	FrameStepper.step(game, 60)

	assertNear(PICKUP_ON_FLOOR_Y, coin.collider:getY(), LANDING_TOLERANCE,
		'expected the coin to have fallen through the gap and landed on the floor below')
	assertEqual('static', coin.collider.bodyType,
		'expected the coin to be back to a static body once it has landed')
	assertNear(PICKUP_ON_FLOOR_Y, key.collider:getY(), LANDING_TOLERANCE,
		'expected the key to have fallen through the gap and landed on the floor below, independently of the coin')
	assertEqual('static', key.collider.bodyType,
		'expected the key to be back to a static body once it has landed')
end)

test('a coin stays collectible mid-fall', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 5)

	local coin = Queries.findEntityByName(map, 'coin1')
	local tile = Queries.findEntityByName(map, 'tile_target')

	tile:queueDestroy()
	FrameStepper.step(game, 5)

	-- a couple of frames into the fall, still well above the lower floor
	FrameStepper.step(game, 5)
	assertTrue(math.abs(coin.collider:getY() - PICKUP_ON_FLOOR_Y) > 5,
		'fixture check: expected the coin to still be mid-fall, not already landed')

	local player = game.fsm.currentState.players[1]
	local coinPosition = coin.collider:getPositionV()
	player.collider:setPosition(coinPosition.x, coinPosition.y)
	FrameStepper.step(game, 1)

	assertTrue(player.inventory:hasItems('coin', 1),
		'expected the player to pick up a coin that is still mid-fall, same as any other sensor pickup')
end)
