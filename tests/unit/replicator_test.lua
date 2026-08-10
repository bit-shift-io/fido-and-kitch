-- Unit tests for src/entities/replicator.lua: prop defaults, cadence math
-- (via the Replicator._internal white-box seam), and the entity-level spawn
-- contract against a stub map that records loadEntity calls -- verifying the
-- spawned mockObject carries the right type/position/dims/layer and that the
-- timer pauses while disabled and resumes at the same phase.
local HeadlessBootstrap = require('tests.support.headless_bootstrap')

local Replicator = require('src.entities.replicator')
local REP = Replicator._internal

-- A stub map whose loadEntity only records the call, never constructs a real
-- entity (construction needs the full Map/World stack, which the integration
-- tier owns).
local function stubMap()
	return {
		calls = {},
		loadEntity = function(self, entityType, layer, object)
			table.insert(self.calls, {
				entityType = entityType,
				layer = layer,
				object = object,
			})
			return { type = entityType } -- stand-in spawned entity
		end,
	}
end

local function makeReplicator(props, map, objectOverrides)
	HeadlessBootstrap.resetWorld()
	local object = {
		x = 100,
		y = 100,
		width = 32,
		height = 32,
		properties = props or {},
		layer = 'game',
	}
	if objectOverrides then
		for k, v in pairs(objectOverrides) do
			object[k] = v
		end
	end
	return Replicator(object, map or stubMap())
end

--
-- pure cadence math
--

test('dueSpawns is floor division: nothing before the interval, one at it, two across it', function()
	assertEqual(0, REP.dueSpawns(0, 3))
	assertEqual(0, REP.dueSpawns(2.9, 3))
	assertEqual(1, REP.dueSpawns(3, 3))
	assertEqual(2, REP.dueSpawns(6.4, 3))
end)

test('dueSpawns clamps a zero interval so it can never loop forever', function()
	-- an authored interval of 0 is degenerate; clamping to MIN_INTERVAL keeps
	-- floor division finite (never NaN/inf) so update can't hang on one frame
	assertEqual(1, REP.dueSpawns(0.0001, 0))
	assertEqual(math.floor(1 / 0.0001), REP.dueSpawns(1, 0))
end)

--
-- prop defaults
--

test('defaults: interval 3.0, spawnType push_box, no cap, enabled true', function()
	local r = makeReplicator({})

	assertEqual(REP.DEFAULT_INTERVAL, r.interval)
	assertEqual(REP.DEFAULT_SPAWN_TYPE, r.spawnType)
	assertTrue(r.maxTotal == nil, 'maxTotal should default to nil (unlimited)')
	assertTrue(r.enabled, 'enabled should default to true')
	assertEqual(0, r.spawned)
end)

test('props override the defaults when present', function()
	local r = makeReplicator({
		interval = 1.5,
		spawnType = 'boulder',
		maxTotal = 4,
		enabled = false,
	})

	assertEqual(1.5, r.interval)
	assertEqual('boulder', r.spawnType)
	assertEqual(4, r.maxTotal)
	assertFalse(r.enabled)
end)

--
-- timer cadence via a real constructed Replicator
--

test('first spawn fires exactly at the interval', function()
	local map = stubMap()
	local r = makeReplicator({ interval = 3 }, map)

	-- just shy of the interval: nothing yet
	r:update(2.9)
	assertEqual(0, #map.calls)

	-- crossing the boundary fires exactly one spawn
	r:update(0.2) -- 3.1 accumulated
	assertEqual(1, #map.calls)
	assertEqual('push_box', map.calls[1].entityType)
	assertEqual('game', map.calls[1].layer)
end)

test('cadence stays at the interval with no drift over long frames', function()
	local map = stubMap()
	local r = makeReplicator({ interval = 3 }, map)

	-- 6.4s in one frame -> two spawns, phase preserved (2 * 3 = 6 consumed,
	-- 0.4 remains -- so the next spawn is due 2.6s later, not 3s)
	r:update(6.4)
	assertEqual(2, #map.calls)

	r:update(2.5) -- 2.9 accumulated: still no third spawn
	assertEqual(2, #map.calls)

	r:update(0.2) -- 3.1 accumulated: third spawn
	assertEqual(3, #map.calls)
end)

test('disabled (switched off) does not fire and resumes at the saved phase', function()
	local map = stubMap()
	local r = makeReplicator({ interval = 3 }, map)

	r:update(3)  -- fires once, phase 0
	assertEqual(1, #map.calls)

	r:update(1)
	local savedElapsed = r.elapsed

	-- switch off: the timer freezes in place (elapsed preserved, not reset)
	local switchable = r:getComponent(Switchable)
	switchable:switch({ state = 'off' })
	assertFalse(r.enabled)
	assertEqual(savedElapsed, r.elapsed)

	r:update(10) -- a whole interval passes while disabled: nothing spawns
	assertEqual(1, #map.calls)

	-- switch back on: resumes from the saved phase, so the next spawn happens
	-- interval - savedElapsed later
	switchable:switch({ state = 'on' })
	assertTrue(r.enabled)
	r:update(r.interval - savedElapsed) -- exactly the remaining time
	assertEqual(2, #map.calls)
end)

--
-- spawn contract
--

test('spawn builds a top-anchored mock object at the replicator position', function()
	local map = stubMap()
	local r = makeReplicator({ spawnType = 'push_box' }, map)

	r:update(3)

	local call = map.calls[1]
	assertEqual('push_box', call.object.type)
	assertEqual('push_box', call.object.name)
	assertEqual(100, call.object.x)
	-- bottom-anchored replicator (tile object): box top-left is a full height
	-- above the replicator's anchor, so the box centre lands on the machine
	assertEqual(100 - 32, call.object.y)
	assertEqual(32, call.object.width)
	assertEqual(32, call.object.height)
	assertEqual('game', call.object.layer)
	assertEqual(true, call.object.gid == nil, 'mock object must be top-anchored (no gid)')
end)

test('maxTotal caps total spawns then stops forever', function()
	local map = stubMap()
	local r = makeReplicator({ interval = 3, maxTotal = 4 }, map)

	for _ = 1, 5 do
		r:update(3)
	end

	assertEqual(4, #map.calls)
	assertEqual(4, r.spawned)

	-- further updates (even long ones) never exceed the cap
	r:update(30)
	assertEqual(4, #map.calls)
end)