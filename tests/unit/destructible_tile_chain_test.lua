-- Coverage for the optional `chainBreak` cascade on src/entities/
-- destructible_tile.lua, added alongside tests/unit/destructible_tile_test.lua
-- (which stays untouched -- that file covers plain destroy-on-beam-hit,
-- this one covers the chain).
--
-- Two tiers, mirroring pressure_switch's own pure-helper + entity split:
--
-- 1. Pure logic via DestructibleTile._internal: grid-position conversion,
--    orthogonal-neighbor matching, the delay accumulator -- no World, no
--    Map, no entity construction needed.
-- 2. Entity-level: a real DestructibleTile (real Sprite/Collider/World
--    stack, via HeadlessBootstrap) wired to a stub map (a real FxManager +
--    a stubbed getEntitiesByType), proving destroy() actually schedules and
--    fires the cascade through the public destroy()/queueDestroy() surface,
--    not by reaching into the timer directly.
--
-- Multi-hop propagation (a force-destroyed chainBreak neighbor cascading to
-- its OWN neighbors) needs the real map's entity-removal pipeline calling
-- destroy() again, which only a full Map/Game stack provides -- that's
-- tests/integration/laser_destructible_chain_test.lua's job, not this file's.
local HeadlessBootstrap = require("tests.support.headless_bootstrap")
local FxManager = require("src.fx.manager")

-- destroy() now always spawns a TileShatter burst (see below), which loads
-- an fx image via AssetManager -- needs a love.filesystem/love.graphics mock
-- to resolve headless, same as tests/unit/particles_test.lua's own setup.
local LoveMock = require("tests.support.love_mock")
love = love or LoveMock.new()

local DestructibleTile = require("src.entities.destructible_tile")
local internal = DestructibleTile._internal

--
-- Part 1: pure neighbor-resolution + delay-timer logic
--

test("gridPosition converts a pixel position to its tile-grid cell using the map tile size", function()
	assertEqual(1, internal.gridPosition(48, 48, 32, 32).x)
	assertEqual(1, internal.gridPosition(48, 48, 32, 32).y)
	assertEqual(3, internal.gridPosition(100, 48, 32, 32).x)
end)

test("isOrthogonalNeighbor is true for each of the four cardinal directions, one tile away", function()
	local origin = { x = 5, y = 5 }
	assertTrue(internal.isOrthogonalNeighbor(origin, { x = 6, y = 5 }), "east")
	assertTrue(internal.isOrthogonalNeighbor(origin, { x = 4, y = 5 }), "west")
	assertTrue(internal.isOrthogonalNeighbor(origin, { x = 5, y = 6 }), "south")
	assertTrue(internal.isOrthogonalNeighbor(origin, { x = 5, y = 4 }), "north")
end)

test("isOrthogonalNeighbor is false for a diagonal cell", function()
	local origin = { x = 5, y = 5 }
	assertFalse(internal.isOrthogonalNeighbor(origin, { x = 6, y = 6 }))
	assertFalse(internal.isOrthogonalNeighbor(origin, { x = 4, y = 4 }))
end)

test("isOrthogonalNeighbor is false for the same cell and for two-or-more tiles away", function()
	local origin = { x = 5, y = 5 }
	assertFalse(internal.isOrthogonalNeighbor(origin, { x = 5, y = 5 }), "same cell")
	assertFalse(internal.isOrthogonalNeighbor(origin, { x = 7, y = 5 }), "two tiles away")
end)

test(
	"resolveChainNeighbors returns only the entities orthogonally touching the origin, regardless of their own chainBreak flag",
	function()
		local origin = { x = 1, y = 1 }
		local east = { id = "east" }
		local diagonal = { id = "diagonal" }
		local twoAway = { id = "twoAway" }
		local nonChainNeighbor = { id = "plainNorth" }

		local tiles = {
			{ gridPosition = { x = 2, y = 1 }, entity = east }, -- east, chainBreak or not doesn't matter here
			{ gridPosition = { x = 2, y = 2 }, entity = diagonal },
			{ gridPosition = { x = 4, y = 1 }, entity = twoAway },
			{ gridPosition = { x = 1, y = 0 }, entity = nonChainNeighbor }, -- north, no chainBreak of its own
		}

		local neighbors = internal.resolveChainNeighbors(origin, tiles)

		local found = {}
		for _, entity in ipairs(neighbors) do
			found[entity.id] = true
		end

		assertTrue(found.east, "expected the orthogonal east neighbor to be included")
		assertTrue(
			found.plainNorth,
			"expected a non-chainBreak orthogonal neighbor to be included too -- force-destroy ignores their own setting"
		)
		assertTrue(not found.diagonal, "expected the diagonal neighbor to be excluded")
		assertTrue(not found.twoAway, "expected a tile two cells away to be excluded")
	end
)

test("advanceTimer does not report done before ~0.5s of dt has accumulated", function()
	local elapsed = 0
	local dt = 1 / 60
	local done
	for _ = 1, 15 do -- 15/60s = 0.25s, comfortably under CHAIN_DELAY
		elapsed, done = internal.advanceTimer(elapsed, dt)
	end

	assertFalse(done, "expected the timer to still be running short of the delay")
end)

test("advanceTimer reports done once ~0.5s of dt has accumulated", function()
	local elapsed = 0
	local dt = 1 / 60
	local done
	for _ = 1, 35 do -- 35/60s =~ 0.583s, comfortably over CHAIN_DELAY
		elapsed, done = internal.advanceTimer(elapsed, dt)
	end

	assertTrue(done, "expected the timer to be done past the delay")
end)

--
-- Part 2: entity-level -- destroy() actually schedules/fires the cascade
--

local function makeStubMap(neighborEntities)
	return {
		map = { tilewidth = 32, tileheight = 32 },
		fx = FxManager:new(),
		getEntitiesByType = function(_, entityType)
			assertEqual("destructible_tile", entityType)
			return neighborEntities
		end,
	}
end

local function makeStubNeighbor(gridX, gridY)
	local neighbor = { type = "destructible_tile", gridPosition = { x = gridX, y = gridY }, destroyed = false }
	function neighbor:queueDestroy()
		self.destroyed = true
	end
	return neighbor
end

test("a destroyed tile without chainBreak registers a shatter burst but never a cascade timer", function()
	HeadlessBootstrap.resetWorld()
	local stubMap = makeStubMap({})
	local tile = DestructibleTile({
		x = 32,
		y = 32,
		width = 32,
		height = 32,
		properties = {},
	}, stubMap)

	tile:destroy()

	-- Every destroy spawns exactly one fx effect (the shatter burst); a
	-- plain (non-chainBreak) tile spawns no second one (the cascade timer).
	local active = stubMap.fx:getActive()
	assertEqual(1, #active)
	assertTrue(
		active[1].emitter ~= nil and #active[1].emitter.particles > 0,
		"expected the registered effect to be a live TileShatter burst, not the cascade timer"
	)
end)

test(
	"a destroyed chainBreak tile force-destroys its orthogonal neighbors after ~0.5s, sparing diagonal and far tiles",
	function()
		HeadlessBootstrap.resetWorld()

		-- tile itself is a bottom-anchored 32x32 object at object.y=32 -> rect
		-- top 0..32 -> centre (48, 16) -> grid (1, 0), same bottom-anchoring
		-- convention DestructibleTile:init always applies (see its own comment).
		local east = makeStubNeighbor(2, 0)
		local diagonal = makeStubNeighbor(2, 1)
		local twoAway = makeStubNeighbor(4, 0)
		local stubMap = makeStubMap({ east, diagonal, twoAway })

		local tile = DestructibleTile({
			x = 32,
			y = 32,
			width = 32,
			height = 32,
			properties = { chainBreak = true },
		}, stubMap)

		tile:destroy()
		-- Two effects: the shatter burst (every destroy) plus the cascade timer
		-- (chainBreak only).
		assertEqual(
			2,
			#stubMap.fx:getActive(),
			"expected destroy() to register the shatter burst and exactly one cascade timer"
		)

		stubMap.fx:update(15 / 60) -- 0.25s, short of the ~0.5s delay
		assertFalse(east.destroyed, "expected the neighbor to still be intact before the delay elapses")

		stubMap.fx:update(15 / 60) -- total ~0.5s, comfortably past the delay
		assertTrue(east.destroyed, "expected the orthogonal neighbor to be force-destroyed once the delay elapses")
		assertFalse(diagonal.destroyed, "expected the diagonal tile to never be affected")
		assertFalse(twoAway.destroyed, "expected a tile two cells away to never be affected")
	end
)
