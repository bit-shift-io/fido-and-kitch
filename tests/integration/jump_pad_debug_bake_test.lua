-- In-game debug-only bake on level load: when conf.debug is true, Map's
-- loadSti seam (src/map/init.lua) re-bakes the raw parsed-JSON map (via
-- tools/jump_pad_trajectory/bake.lua) before Tmj.parse/entity construction
-- ever run, so a target-linked, path-less jump_pad ends up with a working
-- `path` at entity-init time -- see src/map/init.lua's bakeIfDebug.
--
-- Fixtures are built from tests/fixtures/jump_pad_room.tmj (never mutated in
-- place) and written to res/map/generated/ -- gitignored scratch space, same
-- precedent as level_generator_end_to_end_test.lua's GENERATED_PATH.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')
local json = require('src.utils.json')

local SOURCE_FIXTURE = 'tests/fixtures/jump_pad_room.tmj'
local SCRATCH_PATH = 'res/map/generated/_test_jump_pad_debug_bake.tmj'

-- GameHarness.bootGlobals wires up love.conf(t) and assigns the global
-- `conf = require('conf')` exactly once per process, the first time
-- GameHarness.startGame runs -- and only that first call's LoveMock instance
-- ever has love.conf actually invoked against it. Toggling conf.debug BEFORE
-- that first boot (as this test needs to, for its very first case) would
-- either crash (conf.lua indexes the `love` global at require time) or
-- leave a later fresh LoveMock without love.conf attached. Simplest correct
-- fix: force that one-time boot here, with an already-baked fixture that
-- triggers no bake either way, so every test below can freely toggle the
-- resulting singleton `conf` table's `.debug` field.
GameHarness.startGame(SOURCE_FIXTURE)
local Conf = conf

local function readFile(path)
	local file = io.open(path, 'r')
	if not file then return nil end
	local contents = file:read('*a')
	file:close()
	return contents
end

local function writeFile(path, contents)
	local file = io.open(path, 'w')
	file:write(contents)
	file:close()
end

local function removeScratchFixture()
	os.remove(SCRATCH_PATH)
end

local function findProperty(object, name)
	for _, prop in ipairs(object.properties or {}) do
		if prop.name == name then
			return prop
		end
	end
	return nil
end

local function findObjectByType(map, objectType)
	for _, layer in ipairs(map.layers or {}) do
		if layer.type == 'objectgroup' then
			for _, object in ipairs(layer.objects or {}) do
				if object.type == objectType then
					return object
				end
			end
		end
	end
	return nil
end

-- Builds an "unbaked" variant of the fixture: the jump_pad loses its `path`
-- property and gains a `target` property pointing at a freshly-added point
-- object, so Bake.bakeMap has something eligible to bake.
local function buildUnbakedFixtureText()
	local rawMap = json.decode(readFile(SOURCE_FIXTURE))

	local pad = findObjectByType(rawMap, 'jump_pad')
	local newProperties = {}
	for _, prop in ipairs(pad.properties or {}) do
		if prop.name ~= 'path' then
			table.insert(newProperties, prop)
		end
	end

	local targetId = rawMap.nextobjectid or 100
	table.insert(newProperties, {type = 'object', name = 'target', value = targetId})
	pad.properties = newProperties

	for _, layer in ipairs(rawMap.layers) do
		if layer.type == 'objectgroup' and layer.name == 'game' then
			table.insert(layer.objects, {
				id = targetId,
				type = '',
				name = 'jump_pad1_target',
				x = pad.x + 300,
				y = pad.y - 50,
				width = 0,
				height = 0,
				rotation = 0,
				visible = true,
				properties = {},
			})
		end
	end
	rawMap.nextobjectid = targetId + 1

	return json.encode(rawMap)
end

-- Runs `fn` with conf.debug forced to `value` for its duration, restoring
-- the previous value afterwards even if fn errors -- conf.debug is a bare
-- global (src/main.lua), so leaving it mutated would leak into every test
-- that runs after this one in the same process.
local function withDebug(value, fn)
	local previous = Conf.debug
	Conf.debug = value
	local ok, err = pcall(fn)
	Conf.debug = previous
	if not ok then
		error(err)
	end
end

test('conf.debug true: a target-linked, path-less jump pad gets a working path at entity-init time', function()
	writeFile(SCRATCH_PATH, buildUnbakedFixtureText())

	withDebug(true, function()
		local game = GameHarness.startGame(SCRATCH_PATH)
		FrameStepper.step(game, 5)

		local pad = Queries.findEntityByName(map, 'jump_pad1')
		assertTrue(pad ~= nil, 'fixture check: jump pad should be present')
		assertTrue(pad.pathObject ~= nil, 'pad should have resolved a pathObject from the newly baked path')
		assertTrue(pad.pathObject.polyline ~= nil and #pad.pathObject.polyline > 0, 'baked path should carry a non-empty polyline')
	end)

	local onDiskMap = json.decode(readFile(SCRATCH_PATH))
	local bakedPad = findObjectByType(onDiskMap, 'jump_pad')
	assertTrue(findProperty(bakedPad, 'path') ~= nil, 'the bake should have written a path property back to the file on disk')

	removeScratchFixture()
end)

test('conf.debug true: a pad that already has a path is left untouched on disk', function()
	local originalContents = readFile(SOURCE_FIXTURE)
	writeFile(SCRATCH_PATH, originalContents)

	withDebug(true, function()
		local game = GameHarness.startGame(SCRATCH_PATH)
		FrameStepper.step(game, 5)
	end)

	local afterContents = readFile(SCRATCH_PATH)
	assertEqual(originalContents, afterContents, 'a pad that already has a path should never cause a disk write')

	removeScratchFixture()
end)

test('conf.debug false (the default): bake never runs and never touches disk', function()
	writeFile(SCRATCH_PATH, buildUnbakedFixtureText())
	local beforeContents = readFile(SCRATCH_PATH)

	assertFalse(Conf.debug, 'this test only proves anything if conf.debug defaults to false')

	-- The pad has no path yet, and bake must not run to give it one, so
	-- entity construction (JumpPad:init) is expected to fail when it indexes
	-- the missing `properties.path` -- that failure is itself evidence the
	-- bake never ran.
	local ok = pcall(function()
		local game = GameHarness.startGame(SCRATCH_PATH)
		FrameStepper.step(game, 5)
	end)
	assertFalse(ok, 'a path-less jump pad should fail entity construction when debug bake never ran')

	local afterContents = readFile(SCRATCH_PATH)
	assertEqual(beforeContents, afterContents, 'bake must never write to disk when conf.debug is false')

	removeScratchFixture()
end)
