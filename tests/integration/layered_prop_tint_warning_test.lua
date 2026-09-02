-- Combining a renderOrder split with Tint/FlashEffect is unsupported (see
-- docs/memory/entity-atomic-draw-and-tint.md): the split still happens
-- (wrong color output stays visible/reproducible) but Map:drawEntities logs
-- a Log.error naming the entity, rather than silently falling back to an
-- atomic draw that would mask the misuse.
local GameHarness = require("tests.support.game_harness")
local Log = require("src.utils.log")

local MAP = "tests/fixtures/coin_room.tmj"

local function spawnEntity(entityName, x, y, extraProps)
	local layer = map.map.layers["game"]
	local object = { x = x, y = y, width = 32, height = 32, properties = extraProps or {} }
	return map:loadEntity(entityName, layer, object)
end

test("a split entity with a Tint component still splits, but logs an error naming it", function()
	local game = GameHarness.startGame(MAP)
	-- Class is booted by GameHarness.startGame -- Tint can't be required
	-- (Class{} at module scope) before that runs.
	local Tint = require("src.components.tint")

	local prop = spawnEntity("layered_prop", 100, 100, { backRenderOrder = -5, frontRenderOrder = 5 })
	prop:addComponent(Tint({ color = { 1, 0, 0, 1 } }))

	local errors = {}
	local originalError = Log.error
	Log.error = function(...)
		table.insert(errors, table.concat({ ... }, " "))
	end

	local backDrawn, frontDrawn = false, false
	local originalBackDraw = prop.backSprite.draw
	prop.backSprite.draw = function(self)
		backDrawn = true
		originalBackDraw(self)
	end
	local originalFrontDraw = prop.frontSprite.draw
	prop.frontSprite.draw = function(self)
		frontDrawn = true
		originalFrontDraw(self)
	end

	map:drawEntities({ tx = 0, ty = 0, sx = 1, sy = 1 })

	Log.error = originalError

	assertTrue(backDrawn and frontDrawn, "the split must still happen -- both Sprite layers must still draw")
	assertEqual(1, #errors, "exactly one Log.error should fire for this entity")
	assertTrue(errors[1]:find("layered_prop", 1, true) ~= nil, "the logged error should name the entity type")
end)
