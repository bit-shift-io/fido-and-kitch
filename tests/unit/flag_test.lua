require("tests.support.headless_bootstrap")

local KeyColors = require("src.entities.key_colors")
local Flag = require("src.entities.flag")

local function makeFlag(colorName, extraProps)
	local props = { color = colorName, image = "res/img/entity_flag.png" }
	for k, v in pairs(extraProps or {}) do
		props[k] = v
	end
	local object = {
		name = "flag",
		x = 0,
		y = 0,
		width = 117,
		height = 175,
		properties = props,
	}
	return Flag(object)
end

test("flag: tints its sprite to the palette color named by object.color", function()
	local flag = makeFlag("purple")
	local tint = flag.componentsByType["tint"]
	assertTrue(tint ~= nil, "flag should carry a Tint component")
	assertEqual(KeyColors.colors.purple, tint.color)
end)

test("flag: unknown color name falls back to red", function()
	local flag = makeFlag("turquoise")
	local tint = flag.componentsByType["tint"]
	assertEqual(KeyColors.colors.red, tint.color)
end)

test("flag: missing color property defaults to red", function()
	local object = {
		name = "flag",
		x = 0,
		y = 0,
		width = 117,
		height = 175,
		properties = { image = "res/img/entity_flag.png" },
	}
	local flag = Flag(object)
	assertEqual(KeyColors.colors.red, flag.componentsByType["tint"].color)
end)

test("flag: useful only tint + sprite, no collider (purely decorative)", function()
	local flag = makeFlag("blue")
	assertTrue(flag.componentsByType["sprite"] ~= nil, "flag should carry a Sprite")
	assertEqual(nil, flag.componentsByType["collider"], "flag must not block or collide")
end)

test("flag: shares the exact key palette -- same color name, same RGBA", function()
	local flag = makeFlag("green")
	local keyColor = KeyColors.color("green")
	assertEqual(keyColor, flag.componentsByType["tint"].color)
end)

test("flag: spriteOffsetY shifts the sprite art down when positive", function()
	local base = makeFlag("red")
	local offset = makeFlag("red", { spriteOffsetY = 16 })

	local anchor = Rect.centreOfMapObject({ x = 0, y = 0, width = 117, height = 175 })
	assertNear(anchor.x + 0, offset.componentsByType["sprite"].position.x, 0.001)
	assertNear(anchor.y + 16, offset.componentsByType["sprite"].position.y, 0.001)
	assertNear(anchor.y + 0, base.componentsByType["sprite"].position.y, 0.001)
end)
