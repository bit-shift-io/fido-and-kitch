-- Unit tests for Usable item requirements: the single-item sugar
-- (requiredItem/requiredItemCount) and the multi-item/count table form
-- (requiredItems = {[itemName]=count}), covering canUse gating and
-- consume-on-use.
local HeadlessBootstrap = require("tests.support.headless_bootstrap")

local Usable = require("src.components.usable")
-- Usable:canUse/use consult the Inventory global (the game boots it in
-- src/main.lua); the unit tier has no bootstrapper for it, so set it here
-- like the other `X = X or require(...)` globals headless_bootstrap wires.
Inventory = Inventory or require("src.components.inventory")

local function makeUser()
	local user = Entity({})
	user:addComponent(Inventory({}))
	return user
end

local function makeUsable(props)
	local entity = Entity({})
	local usable = entity:addComponent(Usable({
		entity = entity,
		use = function()
			entity.used = true
		end,
		sparkles = false,
		requiredItem = props.requiredItem,
		requiredItemCount = props.requiredItemCount,
		requiredItems = props.requiredItems,
	}))
	return usable, entity
end

local function give(user, itemName, count)
	user:getComponent(Inventory):addItems(itemName, count)
end

test("single requiredItem: canUse true only while the item is held", function()
	local usable = makeUsable({ requiredItem = "key_red" })
	local user = makeUser()

	assertFalse(usable:canUse(user), "denied without the key")

	give(user, "key_red", 1)
	assertTrue(usable:canUse(user), "allowed once the key is held")
end)

test("single requiredItem: use consumes exactly the required count", function()
	local usable, entity = makeUsable({ requiredItem = "key_red", requiredItemCount = 2 })
	local user = makeUser()
	give(user, "key_red", 3)

	usable:use(user)

	local inv = user:getComponent(Inventory)
	assertTrue(inv:hasItems("key_red", 1), "one key remains after consuming two")
	assertTrue(not inv:hasItems("key_red", 2), "two keys were consumed")
	assertTrue(entity.used, "useFunc ran after a successful use")
end)

test("requiredItems: all pairs must be held, missing any one denies", function()
	local usable = makeUsable({ requiredItems = { key_red = 1, key_blue = 2 } })
	local user = makeUser()

	give(user, "key_red", 1)
	assertFalse(usable:canUse(user), "denied while key_blue is missing")

	give(user, "key_blue", 2)
	assertTrue(usable:canUse(user), "allowed once every required pair is held")
end)

test("requiredItems: use consumes every required pair", function()
	local usable, entity = makeUsable({ requiredItems = { key_red = 1, key_blue = 2 } })
	local user = makeUser()
	give(user, "key_red", 3)
	give(user, "key_blue", 2)

	usable:use(user)

	local inv = user:getComponent(Inventory)
	assertEqual(2, inv.items["key_red"], "one of three red keys remains")
	assertEqual(0, inv.items["key_blue"], "both blue keys consumed")
	assertTrue(entity.used, "useFunc ran when all requirements were satisfied")
end)
