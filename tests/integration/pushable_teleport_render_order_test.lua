-- Pushables previously always drew last (an accident of entity-add order),
-- covering teleporters they rest near. Now they always draw in front of a
-- teleporter they overlap, deliberately: src/entities/pushable_prop.lua
-- gives push_box/boulder a higher renderOrder than teleport.lua's sprite,
-- so Map:drawEntities' global sort (slice 01) puts them on top -- even
-- though teleport_clear_room.tmj's own object order has push_box (id 4)
-- added to the layer BEFORE teleport_b (id 6), which under the old fixed
-- add-order draw would have put the teleporter on top instead.
local GameHarness = require("tests.support.game_harness")

local MAP = "tests/fixtures/teleport_clear_room.tmj"

local function findEntityByName(name)
	for _, layer in ipairs(map.map.layers) do
		if layer.type == "objectgroup" and layer.entities then
			for _, entity in ipairs(layer.entities) do
				if entity.name == name then
					return entity
				end
			end
		end
	end
end

test("a pushable renders in front of a teleporter it overlaps, regardless of layer add order", function()
	local game = GameHarness.startGame(MAP)

	local teleportB = findEntityByName("teleport_b")
	local pushBox = findEntityByName("push_box")
	assertTrue(teleportB ~= nil, "fixture check: teleport_b should exist")
	assertTrue(pushBox ~= nil, "fixture check: push_box should exist")

	assertTrue(
		pushBox.sprite.renderOrder > teleportB.sprite.renderOrder,
		"push_box renderOrder must be higher than teleport renderOrder"
	)

	local log = {}
	local layer = map.map.layers["game"]
	for _, entity in ipairs(layer.entities) do
		if entity == teleportB then
			local original = entity.draw
			entity.draw = function(self)
				table.insert(log, "teleport")
				original(self)
			end
		elseif entity == pushBox then
			local original = entity.draw
			entity.draw = function(self)
				table.insert(log, "push_box")
				original(self)
			end
		end
	end

	map:drawEntities({ tx = 0, ty = 0, sx = 1, sy = 1 })

	local order = {}
	for i, id in ipairs(log) do
		order[id] = i
	end
	assertTrue(order.push_box ~= nil and order.teleport ~= nil, "both entities should have drawn")
	assertTrue(order.teleport < order.push_box, "push_box must draw after (in front of) the teleporter it overlaps")
end)
