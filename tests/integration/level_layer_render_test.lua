-- Regression guard for ParallaxRenderer:drawMainLayers -- the sandbox map's
-- decorative `level` object layer carries tile-gid imagery (an image placed as
-- a tile object in Tiled) that STI compiles into a sprite batch. The renderer
-- must draw that batch, but must NOT draw the gid batches of object layers
-- that spawned runtime entities (cages/keys authored as gid objects), or their
-- art would be double-drawn.
local GameHarness = require('tests.support.game_harness')

test('drawMainLayers renders decorative object-layer gid art, skips entity layers', function()
	local game = GameHarness.startGame('res/map/sandbox.tmj')
	-- require after startGame installs the love mock (ParallaxRenderer grabs
	-- love.graphics at module load)
	local ParallaxRenderer = require('src.map.parallax_renderer')
	local level = map.map.layers['level']
	local gameLayer = map.map.layers['game']

	assertTrue(level ~= nil, 'level layer should exist')
	assertEqual('objectgroup', level.type, 'level layer should be an objectgroup')
	assertTrue(level.batches ~= nil and next(level.batches) ~= nil, 'level layer should build a gid sprite batch')
	assertEqual(0, #level.entities, 'level layer should spawn no runtime entities')
	assertTrue(#gameLayer.entities > 0, 'game layer should spawn runtime entities')

	local drawn = {}
	local originalDraw = love.graphics.draw
	love.graphics.draw = function(...) drawn[#drawn + 1] = {...} end

	ParallaxRenderer:new():drawMainLayers(map, 0, 0, 1, 1)

	love.graphics.draw = originalDraw

	local _, levelBatch = next(level.batches)
	local levelDrawn, gameBatchDrawn = false, false
	for _, args in ipairs(drawn) do
		local obj = args[1]
		if obj == levelBatch then
			levelDrawn = true
		end
		for _, batch in pairs(gameLayer.batches) do
			if obj == batch then
				gameBatchDrawn = true
			end
		end
	end

	assertTrue(levelDrawn, 'decorative object-layer tile-gid art should be drawn')
	assertTrue(not gameBatchDrawn, 'entity-bearing object-layer gid art should not be double-drawn')
end)