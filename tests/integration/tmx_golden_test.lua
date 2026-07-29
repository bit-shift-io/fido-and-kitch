-- Differential tests: the .tmx parser's output compared field-by-field
-- against real Tiled Lua exports, preserved under tests/fixtures/golden/
-- before their .tmx-sourced originals are deleted in issue 06. See
-- .scratch/tmx-direct-loading/DECISIONS.md Q9 for why this tier exists
-- alongside the unit tier: it pins default-materialisation details against
-- genuine Tiled output rather than fixtures invented to match the parser.
--
-- Every field normalised below is normalised because the *golden* is
-- stale relative to its current .tmx/.tx source, in a specific, verified
-- way -- never to paper over a parser defect:
--
-- 1. `tilesets`, on ll1/ll2 only: those two golden exports predate the
--    prior external-tileset migration and still embed each tileset's full
--    geometry; sandbox's and all three backgrounds' committed exports
--    already reflect the {name, firstgid, filename} external-reference
--    shape this parser also produces.
-- 2. Tileset `filename` and image-layer `image` paths: the golden holds
--    the path exactly as Tiled wrote it (relative to the map's own
--    directory), but the parser must resolve it project-root-relative,
--    because STI's pre-built-table constructor is given no directory of
--    its own to resolve against (see HANDOFF.md's path-resolution
--    gotcha). Checked for a matching suffix, then normalised.
-- 3. `class`/`opacity` on ll2 only: ll2.lua's export predates Tiled's
--    Lua exporter emitting these fields at all (ll1's and sandbox's
--    exports already have them), consistent with it being the oldest of
--    the six preserved exports.
-- 4. `night_forest`'s `nextlayerid`/`nextobjectid`: the map has been
--    edited (layers/objects added or removed) since this golden was
--    captured; these two counters are Tiled bookkeeping, not map content.
-- 5. `ll2`'s "switch" object and `sandbox`'s "drawbridge" object: both
--    templates were edited (switch.tx given real properties; drawbridge.tx
--    given a tile image) after these particular golden exports were
--    captured, so their gid/properties fields are stale on the golden
--    side specifically for these two objects. Every other template
--    instance in sandbox (all ten of them) matches the golden exactly,
--    which is what confirms this is a stale-golden artifact on these two
--    objects, not a parser defect -- see DECISIONS.md Q5's verified
--    remap table.
local Tmx = require('src.map.tmx')
local DeepEqual = require('tests.support.deep_equal')

local IGNORED = 'IGNORED (see tmx_golden_test.lua header)'

local function loadGolden(name)
	return loadfile('tests/fixtures/golden/' .. name .. '.lua')()
end

local function findObjectByName(map, name)
	for _, layer in ipairs(map.layers) do
		if layer.type == 'objectgroup' then
			for _, object in ipairs(layer.objects) do
				if object.name == name then
					return object
				end
			end
		end
	end
	return nil
end

--- Recursively deletes every occurrence of `fieldName` (at any depth) from
-- both sides, so the diff ignores it wherever it appears without needing
-- an exact path. Deletes rather than replacing with a placeholder because
-- the golden is missing the field entirely (an older exporter that never
-- wrote it), not holding a different value for it.
local function stripFieldEverywhere(golden, parsed, fieldName, seen)
	if type(golden) ~= 'table' or type(parsed) ~= 'table' then
		return
	end
	seen = seen or {}
	if seen[golden] then
		return
	end
	seen[golden] = true

	golden[fieldName] = nil
	parsed[fieldName] = nil

	for key, childGolden in pairs(golden) do
		stripFieldEverywhere(childGolden, parsed[key], fieldName, seen)
	end
end

local function stripTilesets(map)
	map.tilesets = IGNORED
end

-- Verifies `parsedPath` is the project-root-resolved form of `goldenPath`
-- (golden paths are relative to the referencing file's own directory;
-- parsed paths are always project-root-relative -- see header note 2),
-- then returns the shared placeholder so callers can normalise both sides.
local function assertAndIgnorePath(goldenPath, parsedPath)
	local suffix = goldenPath:gsub('^%.%./', '')
	assertTrue(parsedPath:sub(-#suffix) == suffix,
		string.format('expected "%s" to end with "%s"', parsedPath, suffix))
	return IGNORED
end

local function normaliseTilesetFilenames(golden, parsed)
	for i, goldenTileset in ipairs(golden.tilesets) do
		local parsedTileset = parsed.tilesets[i]
		goldenTileset.filename = assertAndIgnorePath(goldenTileset.filename, parsedTileset.filename)
		parsedTileset.filename = IGNORED
	end
end

local function normaliseImageLayerPaths(golden, parsed)
	for i, goldenLayer in ipairs(golden.layers) do
		local parsedLayer = parsed.layers[i]
		if goldenLayer.type == 'imagelayer' then
			goldenLayer.image = assertAndIgnorePath(goldenLayer.image, parsedLayer.image)
			parsedLayer.image = IGNORED
		end
	end
end

test('ll1.tmx (template-free) matches its preserved golden export exactly, modulo the tileset-shape migration', function()
	local golden = loadGolden('ll1')
	local parsed = Tmx.parse('res/map/ll1.tmx')

	stripTilesets(golden)
	stripTilesets(parsed)

	DeepEqual.assertEqual(golden, parsed, 'll1.tmx parse does not match its golden export')
end)

test('ll2.tmx matches its preserved golden export, modulo the tileset-shape/field-set migration and the re-authored switch object', function()
	local golden = loadGolden('ll2')
	local parsed = Tmx.parse('res/map/ll2.tmx')

	stripTilesets(golden)
	stripTilesets(parsed)
	stripFieldEverywhere(golden, parsed, 'class')
	stripFieldEverywhere(golden, parsed, 'opacity')

	local goldenSwitch = findObjectByName(golden, 'switch')
	local parsedSwitch = findObjectByName(parsed, 'switch')
	assertTrue(goldenSwitch ~= nil and parsedSwitch ~= nil, 'expected both maps to have a "switch" object')
	-- Confirm the parser resolves it via the *current* template correctly
	-- (see DECISIONS.md Q5's formula), independent of the stale golden.
	assertEqual('switch', parsedSwitch.type)
	assertEqual(148, parsedSwitch.gid) -- switch.tx gid 4, props auto-registered at 145 -> 4-1+145
	assertEqual(9, parsedSwitch.properties.target.id)
	goldenSwitch.gid, parsedSwitch.gid = IGNORED, IGNORED
	goldenSwitch.properties, parsedSwitch.properties = IGNORED, IGNORED

	DeepEqual.assertEqual(golden, parsed, 'll2.tmx parse does not match its golden export')
end)

test('sandbox.tmx matches its preserved golden export exactly, modulo tileset path resolution and the re-authored drawbridge tile reference', function()
	local golden = loadGolden('sandbox')
	local parsed = Tmx.parse('res/map/sandbox.tmx')

	normaliseTilesetFilenames(golden, parsed)

	local goldenDrawbridge = findObjectByName(golden, 'drawbridge')
	local parsedDrawbridge = findObjectByName(parsed, 'drawbridge')
	assertTrue(goldenDrawbridge ~= nil and parsedDrawbridge ~= nil, 'expected both maps to have a "drawbridge" object')
	-- drawbridge.tx now carries gid="12" (a real tile image), which
	-- resolves to 156 in sandbox's numbering (12 - 1 + 145); the golden
	-- predates that template edit and still shows the old gid of 0.
	assertEqual(156, parsedDrawbridge.gid)
	goldenDrawbridge.gid, parsedDrawbridge.gid = IGNORED, IGNORED

	DeepEqual.assertEqual(golden, parsed, 'sandbox.tmx parse does not match its golden export')
end)

for _, name in ipairs({ 'night_forest', 'mushroom_cave', 'sky' }) do
	test(name .. '.tmx (image layers, zero tilesets) matches its preserved golden export modulo image path resolution', function()
		local golden = loadGolden(name)
		local parsed = Tmx.parse('res/backgrounds/' .. name .. '.tmx')

		normaliseImageLayerPaths(golden, parsed)

		if name == 'night_forest' then
			-- The map has gained a layer and two objects since this golden
			-- was captured; these counters are Tiled bookkeeping, not
			-- content this parser is responsible for reproducing.
			golden.nextlayerid, parsed.nextlayerid = IGNORED, IGNORED
			golden.nextobjectid, parsed.nextobjectid = IGNORED, IGNORED
		end

		DeepEqual.assertEqual(golden, parsed, name .. '.tmx parse does not match its golden export')
	end)
end
