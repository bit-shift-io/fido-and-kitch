-- Map:drawEntities' global renderOrder sort (src/map/init.lua). Asserts via
-- a draw-order log rather than pixels, following the existing
-- mesh_ribbon_draw_order_test.lua / level_layer_render_test.lua pattern of
-- spying on draw calls instead of rendering real frames.
local GameHarness = require("tests.support.game_harness")

local MAP = "tests/fixtures/coin_room.tmj"

-- A minimal draw unit: not a real Entity, just the shape Map:drawEntities
-- actually reads off one (a `components` array it scans for `.renderOrder`,
-- and its own `draw()`). Keeps the fixture map untouched -- these are
-- pushed directly into a live object layer's entity list.
local function fakeEntity(renderOrder, id, log)
	local components = {}
	if renderOrder ~= nil then
		components = { { renderOrder = renderOrder } }
	end
	return {
		components = components,
		draw = function()
			table.insert(log, id)
		end,
	}
end

local function fakeFx(renderOrder, id, log)
	return {
		renderOrder = renderOrder,
		draw = function()
			table.insert(log, id)
		end,
		update = function() end,
		done = function()
			return false
		end,
	}
end

test("entities with different renderOrder draw in ascending order regardless of layer/add order", function()
	local game = GameHarness.startGame(MAP)
	local layer = map.map.layers["game"]
	local log = {}

	-- Added highest-order-first, so a passing test proves the sort -- not
	-- coincidental insertion order -- decides the outcome.
	table.insert(layer.entities, fakeEntity(10, "high", log))
	table.insert(layer.entities, fakeEntity(-5, "low", log))

	map:drawEntities({ tx = 0, ty = 0, sx = 1, sy = 1 })

	local lowIndex, highIndex
	for i, id in ipairs(log) do
		if id == "low" then
			lowIndex = i
		end
		if id == "high" then
			highIndex = i
		end
	end
	assertTrue(lowIndex ~= nil and highIndex ~= nil, "both fake entities should have drawn")
	assertTrue(lowIndex < highIndex, "renderOrder -5 must draw before renderOrder 10")
end)

test("a Map.fx effect with an explicit renderOrder draws before some entities and after others", function()
	local game = GameHarness.startGame(MAP)
	local layer = map.map.layers["game"]
	local log = {}

	table.insert(layer.entities, fakeEntity(20, "behind_fx", log))
	table.insert(layer.entities, fakeEntity(0, "in_front_of_fx", log))
	map.fx:add(fakeFx(10, "fx", log))

	map:drawEntities({ tx = 0, ty = 0, sx = 1, sy = 1 })

	local order = {}
	for i, id in ipairs(log) do
		order[id] = i
	end
	assertTrue(order.in_front_of_fx < order.fx, "renderOrder 0 entity should draw before the renderOrder 10 fx")
	assertTrue(order.fx < order.behind_fx, "renderOrder 10 fx should draw before the renderOrder 20 entity")
end)

test("entities/fx with no renderOrder draw in exactly today's order (layer order, then fx last)", function()
	local game = GameHarness.startGame(MAP)
	local layer = map.map.layers["game"]
	local log = {}

	-- Wrap every pre-existing (real) entity's draw so the log captures the
	-- full interleaved sequence, not just the fakes' own draws.
	for i, entity in ipairs(layer.entities) do
		local id = "real" .. i
		local originalDraw = entity.draw
		entity.draw = function(self)
			table.insert(log, id)
			originalDraw(self)
		end
	end

	table.insert(layer.entities, fakeEntity(nil, "first", log))
	table.insert(layer.entities, fakeEntity(nil, "second", log))
	map.fx:add(fakeFx(nil, "fx", log))

	map:drawEntities({ tx = 0, ty = 0, sx = 1, sy = 1 })

	-- Every real entity, then the two unset-order fakes in their relative
	-- add order, then the unset-order fx last -- today's behavior exactly.
	local expected = {}
	for i = 1, #layer.entities - 2 do
		expected[i] = "real" .. i
	end
	expected[#expected + 1] = "first"
	expected[#expected + 1] = "second"
	expected[#expected + 1] = "fx"

	assertEqual(
		table.concat(expected, ","),
		table.concat(log, ","),
		"no regression: unset-order draw order must match today's traversal exactly"
	)
end)
