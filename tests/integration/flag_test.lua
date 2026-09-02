-- The flag entity through the real loader stack: a Tiled object of type
-- 'flag' is a decorative, no-collider prop whose Sprite is tinted from the
-- shared key palette. Its single Sprite never splits renderOrder, so it must
-- draw as one atomic unit without tripping the unsupported tint/split
-- warning in Map:drawEntities.
local GameHarness = require("tests.support.game_harness")
local Log = require("src.utils.log")

local MAP = "tests/fixtures/coin_room.tmj"

local function spawnFlag(x, y, colorName)
	local layer = map.map.layers["game"]
	local object = {
		x = x,
		y = y,
		width = 117,
		height = 175,
		properties = { color = colorName, image = "res/img/entity_flag.png" },
	}
	return map:loadEntity("flag", layer, object)
end

test("a flag placed in a map draws tinted and atomic without the split warning", function()
	local game = GameHarness.startGame(MAP)
	local KeyColors = require("src.entities.key_colors")

	local flag = spawnFlag(200, 200, "purple")
	assertEqual("flag", flag.type, "the entity type should be flag")
	assertEqual(KeyColors.colors.purple, flag.componentsByType["tint"].color)
	assertEqual(nil, flag.componentsByType["collider"], "a flag must not block or collide")

	local errors = {}
	local originalError = Log.error
	Log.error = function(...)
		table.insert(errors, table.concat({ ... }, " "))
	end

	local drawn = false
	local originalDraw = flag.componentsByType["sprite"].draw
	flag.componentsByType["sprite"].draw = function(self)
		drawn = true
		originalDraw(self)
	end

	map:drawEntities({ tx = 0, ty = 0, sx = 1, sy = 1 })

	Log.error = originalError

	assertTrue(drawn, "the flag sprite should draw")
	assertEqual(0, #errors, "single-sprite flag must not trigger the unsupported tint/split Log.error")
end)
