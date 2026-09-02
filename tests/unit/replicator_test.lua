-- Unit tests for src/entities/replicator.lua: prop defaults, the switch-pulse
-- contract (every linked-switch press spawns once, on/off state irrelevant),
-- the maxSpawns budget, the rotation/polyline emit-point math (via the
-- Replicator._internal white-box seam), and the spawned mock-object contract
-- against a stub map that records loadEntity calls.
local HeadlessBootstrap = require("tests.support.headless_bootstrap")

local Replicator = require("src.entities.replicator")
local REP = Replicator._internal

-- table.count helper (tbl.length was removed as unused; this test needs it)
local function count(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

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
		rotation = 0,
		properties = props or {},
		layer = "game",
	}
	if objectOverrides then
		for k, v in pairs(objectOverrides) do
			object[k] = v
		end
	end
	return Replicator(object, map or stubMap())
end

local function switchable(replicator)
	return replicator:getComponent(Switchable)
end

--
-- prop defaults
--

test("defaults: spawnType push_box, maxSpawns 1", function()
	local r = makeReplicator({})

	assertEqual(REP.DEFAULT_SPAWN_TYPE, r.spawnType)
	assertEqual(REP.DEFAULT_MAX_SPAWNS, r.maxSpawns)
	assertEqual(0, r.spawned)
end)

test("props override the defaults when present", function()
	local r = makeReplicator({
		spawnType = "boulder",
		maxSpawns = 4,
	})

	assertEqual("boulder", r.spawnType)
	assertEqual(4, r.maxSpawns)
	assertEqual(0, r.spawned)
end)

test("maxSpawns is clamped to >= 0", function()
	local r = makeReplicator({ maxSpawns = -3 })
	assertEqual(0, r.maxSpawns)
end)

--
-- switch-pulse contract
--

test("every press spawns once regardless of the switch on/off state", function()
	local map = stubMap()
	local r = makeReplicator({ maxSpawns = 2 }, map)

	-- a press with the switch going ON spawns once
	switchable(r):switch({ state = "on" }, {})
	assertEqual(1, #map.calls)
	assertEqual("push_box", map.calls[1].entityType)
	assertEqual("game", map.calls[1].layer)

	-- a press with the switch going OFF spawns once too -- the state is
	-- irrelevant, only the press pulse matters
	switchable(r):switch({ state = "off" }, {})
	assertEqual(2, #map.calls)
	assertEqual("push_box", map.calls[2].entityType)
end)

test("budget is capped at maxSpawns and further presses are inert", function()
	local map = stubMap()
	local r = makeReplicator({}, map) -- default maxSpawns 1

	switchable(r):switch({ state = "on" }, {})
	assertEqual(1, #map.calls)
	assertEqual(1, r.spawned)

	-- budget spent: the next two presses spawn nothing
	switchable(r):switch({ state = "off" }, {})
	switchable(r):switch({ state = "on" }, {})
	assertEqual(1, #map.calls)
	assertEqual(1, r.spawned)
end)

test("an explicit maxSpawns of 4 allows four presses then goes inert", function()
	local map = stubMap()
	local r = makeReplicator({ maxSpawns = 4 }, map)

	for i = 1, 6 do
		switchable(r):switch({ state = "on" }, {})
	end

	assertEqual(4, #map.calls)
	assertEqual(4, r.spawned)
end)

test("maxSpawns 0 spawns on no press at all", function()
	local map = stubMap()
	local r = makeReplicator({ maxSpawns = 0 }, map)

	switchable(r):switch({ state = "on" }, {})
	assertEqual(0, #map.calls)
	assertEqual(0, r.spawned)
end)

--
-- emit point: rotation 0 / 180, polyline override
--

test("emitY rotation 0 (ceiling) is one tile below the surface", function()
	-- bottom-anchored tile object: object.y is the bottom edge; a ceiling
	-- mount emits the box top edge one tile below the machine underside
	local object = { y = 128, height = 32, rotation = 0 }
	assertEqual(128 + 32, REP.emitY(object))
end)

test("emitY rotation 180 (floor) is two tiles above the top face", function()
	-- bottom-anchored: object.y - height is the machine's top face; the box
	-- top edge sits two tiles off that face (one tile of machine + one of gap)
	local object = { y = 128, height = 32, rotation = 180 }
	assertEqual(128 - 64, REP.emitY(object))
end)

test("emitY treats an unknown rotation/absent rotation as the ceiling rule", function()
	assertEqual(100 + 32, REP.emitY({ y = 100, height = 32 }))
	assertEqual(100 + 32, REP.emitY({ y = 100, height = 32, rotation = 90 }))
end)

test("emitY polyline override uses polyline[1] verbatim as absolute", function()
	-- points are absolute post-STI -- never add the object origin again
	local object = {
		x = 100,
		y = 100,
		height = 32,
		rotation = 0,
		polyline = { { x = 204, y = 156 } },
	}
	assertEqual(156, REP.emitY(object))
end)

--
-- spawn contract
--

test("spawn builds a top-anchored mock object at the ceiling emit point", function()
	local map = stubMap()
	local r = makeReplicator({ spawnType = "push_box" }, map) -- rotation 0

	switchable(r):switch({ state = "on" }, {})

	local call = map.calls[1]
	assertEqual("push_box", call.object.type)
	assertEqual("push_box", call.object.name)
	assertEqual(100, call.object.x)
	-- rotation 0 ceiling: mock y is one tile below the bottom edge
	assertEqual(100 + 32, call.object.y)
	assertEqual(32, call.object.width)
	assertEqual(32, call.object.height)
	assertEqual("game", call.object.layer)
	assertEqual(true, call.object.gid == nil, "mock object must be top-anchored (no gid)")
	assertEqual(0, count(call.object.properties), "mock properties must be empty")
end)

test("rotation 180 spawns the mock object two tiles above the top face", function()
	local map = stubMap()
	local r = makeReplicator({ maxSpawns = 2 }, map, { rotation = 180 })

	switchable(r):switch({ state = "on" }, {})

	local object = map.calls[1].object
	assertEqual(100 - 64, object.y)
end)

test("a polyline override drives both mock x and y verbatim", function()
	local map = stubMap()
	local polyline = { { x = 204, y = 156 } }
	local r = makeReplicator({}, map, { polyline = polyline })

	switchable(r):switch({ state = "on" }, {})

	local object = map.calls[1].object
	assertEqual(204, object.x)
	assertEqual(156, object.y)
end)

test("spriteOffsetY shifts the sprite art only (spawn point unchanged)", function()
	local map = stubMap()
	local r = makeReplicator({ spriteOffsetY = 16 }, map) -- rotation 0 ceiling

	-- the spawned box still emits at the ceiling point (no offset applied)
	switchable(r):switch({ state = "on" }, {})
	assertEqual(100 + 32, map.calls[1].object.y)

	-- the machine's own sprite art is nudged down by 16px; base centre is
	-- (x+w/2, y-h/2) = (116, 84) for the bottom-anchored 32x32 object
	local sprite = r:getComponent(Sprite)
	assertEqual(Vector(116, 84 + 16), sprite.position)
end)

test("spriteOffsetY defaults to 0 when absent", function()
	local r = makeReplicator({}, stubMap())
	local sprite = r:getComponent(Sprite)
	assertEqual(Rect.centreOfMapObject(r.object), sprite.position)
end)

test("spawned mock object carries the replicator authored dims", function()
	local map = stubMap()
	local r = makeReplicator({ spawnType = "boulder" }, map, { width = 64, height = 48 })

	switchable(r):switch({ state = "on" }, {})

	local object = map.calls[1].object
	assertEqual("boulder", object.type)
	assertEqual("boulder", object.name)
	assertEqual(64, object.width)
	assertEqual(48, object.height)
	assertEqual("game", object.layer)
end)
