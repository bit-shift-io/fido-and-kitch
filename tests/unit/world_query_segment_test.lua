-- Unit tests for World:querySegment and World:querySegmentWithCoords
Class = Class or require("lib.hump.class")
local World = require("src.physics.bump.world")
Collider = Collider or require("src.physics.bump.collider")

local function makeStaticBox(x, y, width, height, entity)
	local col = Collider({
		shape_type = "rectangle",
		shape_arguments = { width, height },
		body_type = "static",
		position = { x = x, y = y },
	})
	if entity then
		col.entity = entity
	end
	return col
end

test("querySegment returns empty array when segment hits nothing", function()
	world = World:new(0, 0, true)

	-- Create a single box at (100, 100)
	makeStaticBox(100, 100, 50, 50)

	-- Cast a segment that doesn't hit it: from (200, 200) to (250, 250)
	local results = world:querySegment(200, 200, 250, 250)

	assertEqual(0, #results)
end)

test("querySegment returns single item when segment hits one collider", function()
	world = World:new(0, 0, true)

	-- Create a box at (100, 100) with dimensions 50x50, centered
	-- So it spans roughly x: [75, 125], y: [75, 125]
	local box = makeStaticBox(100, 100, 50, 50)

	-- Cast a segment through it: from (50, 100) to (150, 100)
	local results = world:querySegment(50, 100, 150, 100)

	assertEqual(1, #results)
	assertTrue(results[1] == box)
end)

test("querySegment returns items in nearest-first order", function()
	world = World:new(0, 0, true)

	-- Create three boxes in a line along x-axis
	local box1 = makeStaticBox(100, 100, 40, 40) -- spans ~[80, 120]
	local box2 = makeStaticBox(200, 100, 40, 40) -- spans ~[180, 220]
	local box3 = makeStaticBox(300, 100, 40, 40) -- spans ~[280, 320]

	-- Cast a horizontal segment through all three: from (0, 100) to (400, 100)
	local results = world:querySegment(0, 100, 400, 100)

	assertEqual(3, #results)
	-- Verify order is nearest-first (box1 first, then box2, then box3)
	assertTrue(results[1] == box1)
	assertTrue(results[2] == box2)
	assertTrue(results[3] == box3)
end)

test("querySegment respects filter callback", function()
	world = World:new(0, 0, true)

	local box1 = makeStaticBox(100, 100, 40, 40)
	local box2 = makeStaticBox(200, 100, 40, 40)
	local box3 = makeStaticBox(300, 100, 40, 40)

	-- Create a filter that excludes box2
	local function filter(item)
		return item ~= box2
	end

	local results = world:querySegment(0, 100, 400, 100, filter)

	assertEqual(2, #results)
	assertTrue(results[1] == box1)
	assertTrue(results[2] == box3)
end)

test("querySegment attaches .entity to results", function()
	world = World:new(0, 0, true)

	local entity = { type = "test_entity" }
	local box = makeStaticBox(100, 100, 40, 40, entity)

	local results = world:querySegment(50, 100, 150, 100)

	assertEqual(1, #results)
	assertTrue(results[1].entity == entity)
end)

test("querySegment handles items without .entity", function()
	world = World:new(0, 0, true)

	-- Create a box without an entity
	local box = makeStaticBox(100, 100, 40, 40)
	-- box.entity is nil

	local results = world:querySegment(50, 100, 150, 100)

	assertEqual(1, #results)
	assertTrue(results[1].entity == nil)
end)

test("querySegmentWithCoords returns hit coordinates", function()
	world = World:new(0, 0, true)

	-- Create a box at (100, 100) with dimensions 50x50
	-- Spans approximately x: [75, 125], y: [75, 125]
	local box = makeStaticBox(100, 100, 50, 50)

	-- Cast a horizontal segment through it: from (50, 100) to (150, 100)
	local results = world:querySegmentWithCoords(50, 100, 150, 100)

	assertEqual(1, #results)
	local result = results[1]

	-- result should have: item, x1, y1, x2, y2, entity
	assertTrue(result.item == box)
	assertTrue(result.x1 ~= nil)
	assertTrue(result.y1 ~= nil)
	assertTrue(result.x2 ~= nil)
	assertTrue(result.y2 ~= nil)

	-- Entry and exit should be on the horizontal line y=100
	assertNear(100, result.y1, 0.1)
	assertNear(100, result.y2, 0.1)

	-- Entry should be roughly at x=75, exit at x=125 (or vice versa depending on which is entry/exit)
	assertTrue((result.x1 >= 70 and result.x1 <= 80) or (result.x1 >= 120 and result.x1 <= 130))
	assertTrue((result.x2 >= 70 and result.x2 <= 80) or (result.x2 >= 120 and result.x2 <= 130))
end)

test("querySegmentWithCoords returns items in nearest-first order", function()
	world = World:new(0, 0, true)

	local box1 = makeStaticBox(100, 100, 40, 40)
	local box2 = makeStaticBox(200, 100, 40, 40)
	local box3 = makeStaticBox(300, 100, 40, 40)

	local results = world:querySegmentWithCoords(0, 100, 400, 100)

	assertEqual(3, #results)
	assertTrue(results[1].item == box1)
	assertTrue(results[2].item == box2)
	assertTrue(results[3].item == box3)
end)

test("querySegmentWithCoords attaches .entity to results", function()
	world = World:new(0, 0, true)

	local entity1 = { type = "entity_a" }
	local entity2 = { type = "entity_b" }

	local box1 = makeStaticBox(100, 100, 40, 40, entity1)
	local box2 = makeStaticBox(200, 100, 40, 40, entity2)

	local results = world:querySegmentWithCoords(0, 100, 400, 100)

	assertEqual(2, #results)
	assertTrue(results[1].entity == entity1)
	assertTrue(results[2].entity == entity2)
end)

-- Slice 05 (laser beam blocking/destruction) regression: LaserBeamResolver
-- classifies a hit as transparent by reading `hit.sensor` on each
-- querySegmentWithCoords result -- that field has to be copied up from the
-- underlying collider (itemInfo[i].item.sensor) the same way .entity already
-- is, or every hit reads sensor=nil (indistinguishable from a solid hit) and
-- an open/passable sensor collider wrongly blocks a beam.
test("querySegmentWithCoords attaches .sensor to results", function()
	world = World:new(0, 0, true)

	local solidBox = makeStaticBox(100, 100, 40, 40)
	local sensorBox = Collider({
		shape_type = "rectangle",
		shape_arguments = { 40, 40 },
		body_type = "static",
		sensor = true,
		position = { x = 200, y = 100 },
	})

	local results = world:querySegmentWithCoords(0, 100, 400, 100)

	assertEqual(2, #results)
	assertTrue(results[1].item == solidBox)
	assertFalse(results[1].sensor)
	assertTrue(results[2].item == sensorBox)
	assertTrue(results[2].sensor)
end)

test("querySegmentWithCoords respects filter callback", function()
	world = World:new(0, 0, true)

	local box1 = makeStaticBox(100, 100, 40, 40)
	local box2 = makeStaticBox(200, 100, 40, 40)

	local function filter(item)
		return item ~= box1
	end

	local results = world:querySegmentWithCoords(0, 100, 400, 100, filter)

	assertEqual(1, #results)
	assertTrue(results[1].item == box2)
end)

test("querySegment works with diagonal segments", function()
	world = World:new(0, 0, true)

	-- Create boxes along a diagonal
	local box1 = makeStaticBox(100, 100, 30, 30)
	local box2 = makeStaticBox(200, 200, 30, 30)

	-- Cast a diagonal segment: from (50, 50) to (350, 350)
	local results = world:querySegment(50, 50, 350, 350)

	assertEqual(2, #results)
	assertTrue(results[1] == box1)
	assertTrue(results[2] == box2)
end)

test("querySegmentWithCoords handles diagonal segments with coordinates", function()
	world = World:new(0, 0, true)

	local box = makeStaticBox(100, 100, 30, 30)

	-- Cast a diagonal segment through the box
	local results = world:querySegmentWithCoords(50, 50, 150, 150)

	assertEqual(1, #results)
	local result = results[1]

	-- The segment crosses through the box, so coordinates should be set
	assertTrue(result.x1 ~= nil)
	assertTrue(result.y1 ~= nil)
	assertTrue(result.x2 ~= nil)
	assertTrue(result.y2 ~= nil)
end)
