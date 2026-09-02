-- End-to-end proof for jump-pad trajectory baking: a jump_pad carrying a
-- `target` (and no `path`) gets a working, walkable path through BOTH bake
-- routes -- the offline CLI tool (tools/jump_pad_trajectory/main.lua, via
-- Bake.bakeMap directly here, matching jump_pad_debug_bake_test.lua's own
-- precedent of calling Bake.bakeMap rather than shelling out) and the
-- in-game conf.debug bake seam (src/map/init.lua's bakeIfDebug) -- and that
-- the resulting path drives JumpTravelState/PathFollow exactly like a
-- hand-authored path (tests/fixtures/jump_pad_room.tmj) already does.
--
-- Fixture: tests/fixtures/jump_pad_target_room.tmj -- built from
-- jump_pad_room.tmj's layout conventions (10x6-style floor/spawn/jump_pad
-- object placement), widened and with the floor lowered well below the pad
-- so a single flat floor can safely sit under both the pad and the target
-- (see the geometry note below for why the floor's height matters here,
-- not just its horizontal extent).
--
-- Geometry note: Trajectory.computeArc (src/utils/jump_pad_trajectory.lua)
-- biases its parabola's midpoint ABOVE the straight line joining pad and
-- target (a "hop", not a sag -- this engine's y grows downward, so a
-- rising arc means a numerically SMALLER mid-flight y). This fixture still
-- places the target well below the pad, both to match a realistic jump-pad
-- drop and so a single flat floor can sit under both ends without the
-- mid-flight hop needing to clear anything overhead. This fixture's target
-- sits at
-- y=410 (with the floor at y=425 and the player's actual PHYSICS collider
-- 30px tall -- see src/player/player.lua's `physics_arguments = {20, 30}`,
-- not the 50px used for its sprite/position math -- so resting height on
-- this floor is floor_top - 15 = 410, not floor_top - 25).
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Queries = require("tests.support.queries")
local json = require("src.utils.json")
local Bake = require("tools.jump_pad_trajectory.bake")

local SOURCE_FIXTURE = "tests/fixtures/jump_pad_target_room.tmj"
local BOOTSTRAP_FIXTURE = "tests/fixtures/jump_pad_room.tmj"
local OFFLINE_SCRATCH = "res/map/generated/_test_jump_pad_target_offline.tmj"
local DEBUG_SCRATCH = "res/map/generated/_test_jump_pad_target_debug.tmj"

-- GameHarness.bootGlobals/love.conf only ever wire up on the FIRST
-- GameHarness.startGame call in the process (see jump_pad_debug_bake_test.lua
-- for the full explanation) -- force that one-time boot here with an
-- already-baked, already-valid fixture before any test below toggles
-- conf.debug (and before the Vector global used just below exists).
GameHarness.startGame(BOOTSTRAP_FIXTURE)
local Conf = conf

-- The baked path's last point is exactly the target's centre (per
-- Trajectory.computeArc's contract, using centreOfObject/Rect.centreOfMapObject
-- semantics) -- the target here is a point object (width=height=0), so its
-- centre is simply its own x/y: (436, 410).
local TARGET_CENTRE = Vector(436, 410)
local POSITION_TOLERANCE = 24

local function readFile(path)
	local file = io.open(path, "r")
	if not file then
		return nil
	end
	local contents = file:read("*a")
	file:close()
	return contents
end

local function writeFile(path, contents)
	local file = io.open(path, "w")
	file:write(contents)
	file:close()
end

-- Runs `fn` with conf.debug forced to `value` for its duration, restoring
-- the previous value afterwards even if fn errors -- copied verbatim from
-- jump_pad_debug_bake_test.lua's own helper (see there for the full
-- rationale: conf.debug is a bare global that would otherwise leak into
-- every test that runs after this one in the same process).
local function withDebug(value, fn)
	local previous = Conf.debug
	Conf.debug = value
	local ok, err = pcall(fn)
	Conf.debug = previous
	if not ok then
		error(err)
	end
end

local function findProperty(object, name)
	for _, prop in ipairs(object.properties or {}) do
		if prop.name == name then
			return prop
		end
	end
	return nil
end

local function findObjectByType(rawMap, objectType)
	for _, layer in ipairs(rawMap.layers or {}) do
		if layer.type == "objectgroup" then
			for _, object in ipairs(layer.objects or {}) do
				if object.type == objectType then
					return object
				end
			end
		end
	end
	return nil
end

local function findObjectById(rawMap, id)
	for _, layer in ipairs(rawMap.layers or {}) do
		if layer.type == "objectgroup" then
			for _, object in ipairs(layer.objects or {}) do
				if object.id == id then
					return object
				end
			end
		end
	end
	return nil
end

local function player1(game)
	return game.fsm.currentState.players[1]
end

-- Drives the player onto the pad and through the whole jump, stepping one
-- frame at a time (rather than a single big jump) so we can capture the
-- collider's position at the exact moment JumpTravelState hands off to a
-- new state -- WalkIdleState is the clean "landed" exit (see
-- src/player/states/jump_travel_state.lua:65); anything else (e.g.
-- FallState, from the elapsed>=duration branch) is a materially weaker
-- outcome that must not be confused with a real landing.
-- Positions the player exactly on the pad first: JumpPad:use computes its
-- world-space offset from the user's CURRENT position (see
-- src/entities/jump_pad.lua), so starting anywhere off the pad's own centre
-- would shift the whole baked path and the landing point along with it.
local function driveJumpAndLand(game, pad, maxFrames)
	local player = player1(game)
	local padCentre = pad.collider:getPositionV()
	player.collider:setPositionV(padCentre)
	player.collider:setLinearVelocity(0, 0)

	pad:use(player)

	for _ = 1, maxFrames do
		FrameStepper.step(game, 1)
		local stateName = player.fsm.currentState.name
		if stateName ~= "JumpTravelState" then
			return player.collider:getPositionV(), stateName
		end
	end

	return nil, "JumpTravelState (timed out)"
end

test("offline bake tool route: a baked pad carries the player to its target", function()
	assertFalse(Conf.debug, "this route should work with conf.debug at its default (false)")

	local rawMap = json.decode(readFile(SOURCE_FIXTURE))
	local baked = Bake.bakeMap(rawMap, SOURCE_FIXTURE)
	assertEqual(1, baked, "fixture should have exactly one eligible (target-linked, path-less) jump pad")
	writeFile(OFFLINE_SCRATCH, json.encode(rawMap))

	local game = GameHarness.startGame(OFFLINE_SCRATCH)
	FrameStepper.step(game, 5) -- let entities finish initialising

	local pad = Queries.findEntityByName(map, "jump_pad1")
	assertTrue(pad ~= nil, "fixture check: jump pad should be present")
	assertTrue(
		pad.pathObject ~= nil and pad.pathObject.polyline ~= nil and #pad.pathObject.polyline > 0,
		"offline bake should have produced a usable non-empty path"
	)

	local landedPos, stateName = driveJumpAndLand(game, pad, 600)
	assertEqual("WalkIdleState", stateName, "expected a clean grounded landing, got: " .. tostring(stateName))
	assertTrue(landedPos ~= nil, "expected a landing position")
	assertTrue(
		landedPos:dist(TARGET_CENTRE) < POSITION_TOLERANCE,
		string.format(
			"expected to land near (%d, %d), landed at (%.1f, %.1f)",
			TARGET_CENTRE.x,
			TARGET_CENTRE.y,
			landedPos.x,
			landedPos.y
		)
	)

	os.remove(OFFLINE_SCRATCH)
end)

test("in-game debug bake route: a baked pad carries the player to its target", function()
	writeFile(DEBUG_SCRATCH, readFile(SOURCE_FIXTURE))

	withDebug(true, function()
		local game = GameHarness.startGame(DEBUG_SCRATCH)
		FrameStepper.step(game, 5) -- let entities finish initialising (and the debug bake to have already run before Tmj.parse)

		local pad = Queries.findEntityByName(map, "jump_pad1")
		assertTrue(pad ~= nil, "fixture check: jump pad should be present")
		assertTrue(
			pad.pathObject ~= nil and pad.pathObject.polyline ~= nil and #pad.pathObject.polyline > 0,
			"in-game debug bake should have produced a usable non-empty path"
		)

		local landedPos, stateName = driveJumpAndLand(game, pad, 600)
		assertEqual("WalkIdleState", stateName, "expected a clean grounded landing, got: " .. tostring(stateName))
		assertTrue(landedPos ~= nil, "expected a landing position")
		assertTrue(
			landedPos:dist(TARGET_CENTRE) < POSITION_TOLERANCE,
			string.format(
				"expected to land near (%d, %d), landed at (%.1f, %.1f)",
				TARGET_CENTRE.x,
				TARGET_CENTRE.y,
				landedPos.x,
				landedPos.y
			)
		)
	end)

	-- Also confirms this route actually wrote a real `path` back to disk,
	-- same stronger evidence jump_pad_debug_bake_test.lua already checks --
	-- kept here too since this test uses its own independent scratch file.
	local onDiskMap = json.decode(readFile(DEBUG_SCRATCH))
	local bakedPad = findObjectByType(onDiskMap, "jump_pad")
	assertTrue(findProperty(bakedPad, "path") ~= nil, "the debug bake should have written a path property back to disk")

	os.remove(DEBUG_SCRATCH)
end)

test("farther and closer targets produce visibly different (taller/shorter) arcs", function()
	-- Reuses/extends the already-baked map table (see the module header and
	-- the slice notes: preferred over adding a third fixture file) -- both
	-- variants move the SAME target object to a different x before baking,
	-- so they share an identical pad and only differ in distance.
	--
	-- Trajectory.computeArc (src/utils/jump_pad_trajectory.lua) enforces a
	-- minimum-clearance FLOOR (2 tiles above the higher endpoint) beneath
	-- the distance-proportional height, so distances have to be large
	-- enough for the proportional term to exceed that floor -- otherwise
	-- near/far would both just hit the same floor and look identical. This
	-- fixture's target sits dy=298px below the pad, giving a floor of
	-- 298/2 + 64 = 213px; dx=1600 (proportional 240px) and dx=6400
	-- (proportional 960px) both clear it.
	local function bakedMidpointDeviation(targetX)
		local rawMap = json.decode(readFile(SOURCE_FIXTURE))
		local target = findObjectById(rawMap, 4)
		assertTrue(target ~= nil, "fixture check: target object id=4 should be present")
		target.x = targetX

		local baked = Bake.bakeMap(rawMap, SOURCE_FIXTURE)
		assertEqual(1, baked, "expected exactly one pad to bake")

		local pad = findObjectByType(rawMap, "jump_pad")
		local pathId = findProperty(pad, "path").value
		local pathObject = findObjectById(rawMap, pathId)
		local polyline = pathObject.polyline
		assertTrue(#polyline >= 3, "expected a multi-point sampled polyline")

		-- Trajectory.computeArc samples 21 points (0..20); its parabolic term
		-- peaks at t=0.5, i.e. exactly the middle point of that 21-point
		-- table, and every stored point is relative to the first (which is
		-- always {x=0, y=0}) -- so the deviation of the midpoint from a
		-- straight line to the last point is just mid.y - last.y/2.
		local mid = polyline[math.ceil(#polyline / 2)]
		local last = polyline[#polyline]
		return mid.y - last.y * 0.5
	end

	local nearDeviation = bakedMidpointDeviation(1736) -- dx = 1736 - 136 = 1600
	local farDeviation = bakedMidpointDeviation(6536) -- dx = 6536 - 136 = 6400

	-- Deviation is signed and negative (the arc rises ABOVE the straight
	-- line, i.e. smaller y, since this engine's y grows downward -- see
	-- src/utils/jump_pad_trajectory.lua), so "visibly larger" means a
	-- larger magnitude, not a larger signed value.
	assertTrue(
		math.abs(farDeviation) > math.abs(nearDeviation) + 10,
		string.format(
			"expected a farther target to produce a visibly larger arc deviation, got near=%.1f far=%.1f",
			nearDeviation,
			farDeviation
		)
	)
end)
