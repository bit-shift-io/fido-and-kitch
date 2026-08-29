-- Object templates: the TMJ parser must read template data from the .tj
-- files so template-referencing objects resolve their type (which is the
-- entity filename EntityFactory loads), plus inherit their gid/size and
-- merge properties. See CONTEXT.md's "Object template" glossary entry /
-- NOTES.md for the resolution contract; sandbox.tmj references res/entities/*.tj templates.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')

local function objectsByLayer(name)
	local stiMap = map and map.map
	if not stiMap then return nil end
	for _, layer in ipairs(stiMap.layers) do
		if layer.type == 'objectgroup' and layer.name == name then
			return layer.objects
		end
	end
	return nil
end

test('sandbox template objects in the game layer resolve type, gid and merged properties from their .tj', function()
	local game = GameHarness.startGame('res/map/sandbox.tmj')

	local objects = objectsByLayer('game')
	assertTrue(objects ~= nil, 'expected a game object layer')

	local byId = {}
	for _, obj in ipairs(objects) do byId[obj.id] = obj end

	-- Template-derived objects carry their template's `type` (the entity
	-- lua filename), which was previously empty.
	assertEqual('coin', byId[117].type, 'object 117 should resolve type from coin.tj')
	-- Entity tilesets are not part of the map (the map declares only the
	-- tilesets its TILE layers use), so a template tile object whose tileset
	-- is not declared gets an inert negative marker gid: truthy for
	-- bottom-anchor semantics, invisible to STI's decorative batching.
	assertTrue(byId[117].gid ~= nil and byId[117].gid < 0, 'object 117 should carry the inert marker gid')
	assertEqual(32, byId[117].width, 'object 117 should inherit width from coin.tj')

	assertEqual('key', byId[118].type, 'object 118 should resolve type from key.tj')
	assertEqual('blue', byId[118].properties.color, 'object 118 should keep its blue color override')

	assertEqual('switch', byId[44].type, 'object 44 should resolve type from switch.tj')
	assertEqual('drawbridge', byId[86].type, 'object 86 should resolve type from drawbridge.tj')
	assertEqual('replicator', byId[109].type, 'object 109 should resolve type from replicator.tj')
	assertEqual('spawn', byId[38].type, 'object 38 should resolve type from spawn.tj')

	FrameStepper.step(game, 5)
end)

test('sandbox ladder-layer template objects resolve their type from ladder.tj', function()
	GameHarness.startGame('res/map/sandbox.tmj')

	local objects = objectsByLayer('ladder')
	assertTrue(objects ~= nil, 'expected a ladder object layer')

	for _, obj in ipairs(objects) do
		assertEqual('ladder', obj.type, string.format('object %d should resolve type from ladder.tj', obj.id))
		-- ladder.tj's tileset is not part of sandbox's declared tilesets, so
		-- the template tile object carries the inert negative marker gid.
		assertTrue(obj.gid ~= nil and obj.gid < 0, string.format('object %d should carry the inert marker gid', obj.id))
	end
end)

test('template-derived entities are constructed in the real world', function()
	local game = GameHarness.startGame('res/map/sandbox.tmj')

	FrameStepper.step(game, 5)

	local total = 0
	for _, layer in ipairs(map.layers) do
		if layer.type == 'objectgroup' and layer.entities then
			total = total + #layer.entities
		end
	end
	assertTrue(total > 0, 'expected template-derived entities to be constructed')
end)
