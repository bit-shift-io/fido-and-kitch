-- Entity helpers behind Map:drawEntities' multi-sprite render-order split
-- (src/entity.lua): detecting when an entity's own Sprite components carry
-- 2+ distinct renderOrder values, and drawing everything else (non-Sprite
-- components) as one grouped unit when that happens.
local function bootGlobals()
	tbl = require("src.utils.tbl")
	str = require("src.utils.str")
	utils = require("src.utils.utils")

	Vector = require("lib.hump.vector")
	Class = require("lib.hump.class")
	Signal = require("src.utils.signal")
end

bootGlobals()

local Entity = require("src.entity")

local function fakeSprite(renderOrder)
	return { type = "sprite", renderOrder = renderOrder, draw = function() end }
end

local function fakeComponent(type, log, id)
	return {
		type = type,
		draw = function()
			table.insert(log, "draw:" .. id)
		end,
		postDraw = function()
			table.insert(log, "postDraw:" .. id)
		end,
	}
end

test("hasSplitRenderOrder is false with fewer than two Sprite components", function()
	local entity = Entity()
	entity:addComponent(fakeSprite(5))
	assertFalse(entity:hasSplitRenderOrder())
end)

test("hasSplitRenderOrder is false when all Sprites share the same renderOrder", function()
	local entity = Entity()
	entity:addComponent(fakeSprite(2))
	entity:addComponent(fakeSprite(2))
	assertFalse(entity:hasSplitRenderOrder())
end)

test("hasSplitRenderOrder is false when unset Sprites are compared to an explicit 0", function()
	local entity = Entity()
	entity:addComponent(fakeSprite(nil))
	entity:addComponent(fakeSprite(0))
	assertFalse(entity:hasSplitRenderOrder())
end)

test("hasSplitRenderOrder is true when 2+ Sprites carry different renderOrder values", function()
	local entity = Entity()
	entity:addComponent(fakeSprite(-1))
	entity:addComponent(fakeSprite(1))
	assertTrue(entity:hasSplitRenderOrder())
end)

test("getSprites returns only Sprite-type components, in add order", function()
	local entity = Entity()
	local sprite1 = fakeSprite(1)
	local other = fakeComponent("collider", {}, "x")
	local sprite2 = fakeSprite(2)
	entity:addComponent(sprite1)
	entity:addComponent(other)
	entity:addComponent(sprite2)

	local sprites = entity:getSprites()
	assertEqual(2, #sprites)
	assertTrue(sprites[1] == sprite1)
	assertTrue(sprites[2] == sprite2)
end)

test("hasColorStateComponent detects Tint and FlashEffect, ignores everything else", function()
	local plain = Entity()
	plain:addComponent(fakeSprite(1))
	assertFalse(plain:hasColorStateComponent())

	local tinted = Entity()
	tinted:addComponent(fakeComponent("tint", {}, "tint"))
	assertTrue(tinted:hasColorStateComponent())

	local flashed = Entity()
	flashed:addComponent(fakeComponent("flash_effect", {}, "flash"))
	assertTrue(flashed:hasColorStateComponent())
end)

test("drawNonSpriteComponents draws and postDraws every non-Sprite component, skipping Sprites", function()
	local entity = Entity()
	local log = {}
	local sprite = fakeSprite(1)
	sprite.draw = function()
		table.insert(log, "sprite-draw")
	end
	entity:addComponent(sprite)
	entity:addComponent(fakeComponent("tint", log, "tint"))

	entity:drawNonSpriteComponents()

	assertEqual("draw:tint,postDraw:tint", table.concat(log, ","))
end)
