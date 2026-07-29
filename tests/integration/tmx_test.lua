-- Proves a .tmx loads through the real Map/STI/GameHarness stack -- not
-- just the pure parser in isolation -- and that dispatch by file extension
-- leaves the existing .lua path untouched. See
-- .scratch/tmx-direct-loading/issues/01-tmx-dispatch-and-tile-layers.md.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')

test('a .tmx with map attributes, an external tileset and a base64 tile layer loads through the real stack and renders', function()
	local game = GameHarness.startGame('tests/fixtures/tmx/tmx_room.tmx')

	local stiMap = map.map
	local tileset = stiMap.tilesets[1]

	assertTrue(tileset.image ~= nil, 'expected the external tileset to resolve an image')
	assertEqual(32, tileset.tilewidth)
	assertEqual(32, tileset.tileheight)
	assertEqual(8, tileset.columns)

	FrameStepper.step(game, 5)

	local ingame = game.fsm.currentState
	assertTrue(#ingame.players > 0, 'expected at least one player to have spawned')
end)

test('per-tile custom properties on a .tmx-referenced external tileset are readable via Map:getTileProperties', function()
	GameHarness.startGame('tests/fixtures/tmx/tmx_room.tmx')

	-- Bottom row (y=3, 1-indexed) of the "ground" layer is gid 1 (tile id
	-- 0), which carries a "solid" property in tmx_room.tsx.
	local properties = map:getTileProperties('ground', 1, 3)
	assertEqual(true, properties['solid'])
end)

test('a hand-authored .lua fixture still loads unchanged, proving the dispatch seam left it alone', function()
	local game = GameHarness.startGame('tests/fixtures/external_tileset_room.lua')
	FrameStepper.step(game, 5)

	local ingame = game.fsm.currentState
	assertTrue(#ingame.players > 0, 'expected the existing .lua fixture to still spawn a player')
end)
