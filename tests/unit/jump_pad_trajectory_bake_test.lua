local Bake = require('tools.jump_pad_trajectory.bake')

local function findProperty(object, name)
	for _, prop in ipairs(object.properties or {}) do
		if prop.name == name then
			return prop
		end
	end
	return nil
end

local function findLayerByName(map, name)
	for _, layer in ipairs(map.layers) do
		if layer.name == name then
			return layer
		end
	end
	return nil
end

local function findObjectById(objects, id)
	for _, object in ipairs(objects) do
		if object.id == id then
			return object
		end
	end
	return nil
end

local function padTargetMap()
	return {
		nextobjectid = 10,
		layers = {
			{
				id = 1,
				type = 'objectgroup',
				name = 'game',
				objects = {
					{
						id = 1,
						type = 'jump_pad',
						name = 'jump_pad1',
						x = 100,
						y = 100,
						width = 32,
						height = 32,
						properties = {
							{type = 'object', name = 'target', value = 2},
						},
					},
					{
						id = 2,
						type = '',
						name = 'jump_pad1_target',
						x = 300,
						y = 50,
						width = 0,
						height = 0,
						properties = {},
					},
				},
			},
		},
	}
end

test('pad with target and no path gains a polyline object and a path property', function()
	local map = padTargetMap()

	local baked = Bake.bakeMap(map, 'test.tmj')

	assertEqual(1, baked)

	local pad = map.layers[1].objects[1]
	local pathProp = findProperty(pad, 'path')
	assertTrue(pathProp ~= nil, 'pad should have gained a path property')
	assertEqual('object', pathProp.type)

	local waypointsLayer = findLayerByName(map, 'waypoints')
	assertTrue(waypointsLayer ~= nil, 'a waypoints layer should have been created')

	local pathObject = findObjectById(waypointsLayer.objects, pathProp.value)
	assertTrue(pathObject ~= nil, 'the referenced path object should exist in the waypoints layer')
	assertTrue(pathObject.polyline ~= nil, 'path object should have a polyline')
	assertTrue(#pathObject.polyline > 0, 'polyline should have points')

	-- First stored point is always {x=0, y=0} relative to the object's own
	-- x/y (Tiled on-disk convention -- see bake.lua's header).
	assertNear(0, pathObject.polyline[1].x, 0.001)
	assertNear(0, pathObject.polyline[1].y, 0.001)

	-- Object x/y is the arc's first point, i.e. the pad's launch origin --
	-- the pad's visual CENTRE (matching Rect.centreOfMapObject), not its raw
	-- bottom-left x/y, since that's where JumpPad:init actually positions
	-- the collider.
	assertNear(pad.x + pad.width * 0.5, pathObject.x, 0.001)
	assertNear(pad.y - pad.height * 0.5, pathObject.y, 0.001)
end)

test('pad with target and existing path is left untouched', function()
	local map = padTargetMap()
	local pad = map.layers[1].objects[1]
	table.insert(pad.properties, {type = 'object', name = 'path', value = 99})

	local baked = Bake.bakeMap(map, 'test.tmj')

	assertEqual(0, baked)
	assertEqual(1, #map.layers, 'no waypoints layer should have been created')
	assertEqual(2, #pad.properties, 'pad properties should be unchanged')
	assertEqual(99, findProperty(pad, 'path').value)
end)

test('pad with no target and no path is left untouched', function()
	local map = {
		nextobjectid = 10,
		layers = {
			{
				id = 1,
				type = 'objectgroup',
				name = 'game',
				objects = {
					{
						id = 1,
						type = 'jump_pad',
						name = 'jump_pad1',
						x = 100,
						y = 100,
						width = 32,
						height = 32,
						properties = {},
					},
				},
			},
		},
	}
	local pad = map.layers[1].objects[1]

	local baked = Bake.bakeMap(map, 'test.tmj')

	assertEqual(0, baked)
	assertEqual(1, #map.layers, 'no waypoints layer should have been created')
	assertEqual(0, #pad.properties, 'pad properties should be unchanged')
end)

test('missing target reference fails loudly, naming the file and object id', function()
	local map = padTargetMap()
	-- Point the target property at an id that doesn't exist in the map.
	local pad = map.layers[1].objects[1]
	findProperty(pad, 'target').value = 999

	local ok, err = pcall(Bake.bakeMap, map, 'broken.tmj')

	assertFalse(ok, 'baking a missing target reference should error')
	assertTrue(tostring(err):find('broken.tmj', 1, true) ~= nil, 'error should name the file')
	assertTrue(tostring(err):find('id=1', 1, true) ~= nil, 'error should name the jump_pad object id')
	assertTrue(tostring(err):find('id=999', 1, true) ~= nil, 'error should name the missing target id')
end)

test('a jump_pad nested inside a group layer is found and baked', function()
	local map = {
		nextobjectid = 10,
		layers = {
			{
				id = 1,
				type = 'group',
				name = 'nested',
				layers = {
					{
						id = 2,
						type = 'objectgroup',
						name = 'game',
						objects = {
							{
								id = 1,
								type = 'jump_pad',
								x = 100,
								y = 100,
								width = 32,
								height = 32,
								properties = {
									{type = 'object', name = 'target', value = 2},
								},
							},
							{
								id = 2,
								type = '',
								x = 300,
								y = 50,
								width = 0,
								height = 0,
								properties = {},
							},
						},
					},
				},
			},
		},
	}

	local baked = Bake.bakeMap(map, 'test.tmj')

	assertEqual(1, baked)
	assertEqual(2, #map.layers, 'a top-level waypoints layer should have been appended alongside the group layer')
end)
