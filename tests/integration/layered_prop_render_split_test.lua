-- Multi-sprite renderOrder split (Entity:hasSplitRenderOrder,
-- Map:drawEntities in src/map/init.lua): an entity whose own Sprite
-- components carry 2+ distinct renderOrder values splits into one draw unit
-- per Sprite, so part of it can render behind another prop while the rest
-- renders in front. `layered_prop` (src/entities/layered_prop.lua) exists
-- specifically to exercise this.
local GameHarness = require('tests.support.game_harness')

local MAP = 'tests/fixtures/coin_room.tmj'

local function spawnEntity(entityName, x, y, extraProps)
	local layer = map.map.layers['game']
	local object = {x = x, y = y, width = 32, height = 32, properties = extraProps or {}}
	return map:loadEntity(entityName, layer, object)
end

local function spySprite(sprite, log, id)
	local original = sprite.draw
	sprite.draw = function(self) table.insert(log, id); original(self) end
end

test('a layered_prop with two differently-ordered Sprites splits into two draw units straddling a third entity', function()
	local game = GameHarness.startGame(MAP)
	local log = {}

	local prop = spawnEntity('layered_prop', 100, 100, {backRenderOrder = -5, frontRenderOrder = 5})
	local middle = spawnEntity('coin', 200, 100)

	spySprite(prop.backSprite, log, 'back')
	spySprite(middle.sprite, log, 'middle')
	spySprite(prop.frontSprite, log, 'front')

	map:drawEntities({tx = 0, ty = 0, sx = 1, sy = 1})

	assertEqual('back,middle,front', table.concat(log, ','),
		'the back layer (-5) must draw before the middle entity (0), which must draw before the front layer (5)')
end)

test('a layered_prop with same-order (or unset) Sprites still draws as one atomic unit', function()
	local game = GameHarness.startGame(MAP)

	local prop = spawnEntity('layered_prop', 100, 100, {backRenderOrder = 3, frontRenderOrder = 3})
	assertFalse(prop:hasSplitRenderOrder(), 'equal renderOrder values must not trigger a split')

	local log = {}
	local layer = map.map.layers['game']
	for _, entity in ipairs(layer.entities) do
		if entity == prop then
			local original = entity.draw
			entity.draw = function(self) table.insert(log, 'atomic'); original(self) end
		end
	end

	map:drawEntities({tx = 0, ty = 0, sx = 1, sy = 1})

	assertEqual('atomic', table.concat(log, ','), 'equal-order entity must draw via a single entity:draw() call')
end)
