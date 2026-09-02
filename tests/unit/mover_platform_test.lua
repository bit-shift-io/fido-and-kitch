-- Pure linear-path stepper tests for src/entities/mover_platform.lua,
-- reached via its MoverPlatform._internal white-box seam (the Drawbridge /
-- PressureSwitch convention): fast, construction-free coverage of the path
-- math -- absolute waypoint resolution from a Tiled polyline object,
-- per-segment lengths, constant-speed advance, pause at every node
-- (including both endpoints), pingpong reversal, and loop wrap-around --
-- plus entity-level prop-default tests against a real constructed
-- MoverPlatform via tests/support/headless_bootstrap.
local HeadlessBootstrap = require("tests.support.headless_bootstrap")

local MoverPlatform = require("src.entities.mover_platform")
local MP = MoverPlatform._internal

-- A Tiled polyline object as the map produces it after STI re-anchors the
-- points: STI adds the object's x/y onto each vertex in place, so the points
-- are already absolute (jump_pad relies on this same contract).
local function polylineObject(x, y, points)
	return {
		x = x,
		y = y,
		polyline = points,
	}
end

local function vectorXY(v)
	return math.floor(v.x * 100 + 0.5) / 100, math.floor(v.y * 100 + 0.5) / 100
end

local function near(v, x, y)
	local vx, vy = vectorXY(v)
	assertNear(x, vx, 0.01, ("expected pos (%s,%s), got (%s,%s)"):format(x, y, vx, vy))
	assertNear(y, vy, 0.01)
end

-- single-segment path: (0,0) -> (100,0)
local function singleSegmentPath()
	return polylineObject(0, 0, { { x = 0, y = 0 }, { x = 100, y = 0 } })
end

-- two-segment path: (0,0) -> (100,0) -> (200,0)
local function twoSegmentPath()
	return polylineObject(0, 0, {
		{ x = 0, y = 0 },
		{ x = 100, y = 0 },
		{ x = 200, y = 0 },
	})
end

--
-- absolute waypoints
--

test("absolute waypoints are the polyline points as STI resolved them", function()
	-- STI re-anchors points in place, so the object's own x/y origin is NOT
	-- re-added -- the points are already absolute.
	local object = polylineObject(10, 20, {
		{ x = 10, y = 20 },
		{ x = 60, y = -10 },
		{ x = 90, y = 25 },
	})
	local w = MP.polylineWaypoints(object)

	assertEqual(3, #w)
	near(w[1], 10, 20)
	near(w[2], 60, -10)
	near(w[3], 90, 25)
end)

test("applyDeckOffset shifts every waypoint down by exactly half the height", function()
	local w = MP.polylineWaypoints(twoSegmentPath()) -- (0,0) (100,0) (200,0)
	local shifted = MP.applyDeckOffset(w, 16)

	assertEqual(3, #shifted)
	near(shifted[1], 0, 16)
	near(shifted[2], 100, 16)
	near(shifted[3], 200, 16)
end)

test("applyDeckOffset is a pure vertical shift: x and leg lengths are untouched", function()
	local w = MP.polylineWaypoints(polylineObject(0, 0, {
		{ x = 0, y = 0 },
		{ x = 30, y = 40 },
	}))
	local shifted = MP.applyDeckOffset(w, 8)

	near(shifted[1], 0, 8)
	near(shifted[2], 30, 48)
	assertNear(50, shifted[1]:dist(shifted[2]), 0.001, "3-4-5 leg keeps its 50px length")
	assertNear(50, MP.buildLegs(shifted, "pingpong")[1].length, 0.001)
end)

test("applyDeckOffset does not mutate its input waypoints", function()
	local w = MP.polylineWaypoints(singleSegmentPath())
	MP.applyDeckOffset(w, 16)
	near(w[1], 0, 0)
	near(w[2], 100, 0)
end)

--
-- legs / per-segment lengths
--

test("pingpong builds a reflected leg list: forward then backward", function()
	local w = MP.polylineWaypoints(twoSegmentPath())
	local legs = MP.buildLegs(w, "pingpong")

	assertEqual(4, #legs)
	assertNear(100, legs[1].length)
	assertNear(100, legs[2].length)
	assertNear(100, legs[3].length)
	assertNear(100, legs[4].length)
	near(legs[1].from, 0, 0)
	near(legs[1].to, 100, 0)
	near(legs[3].from, 200, 0)
	near(legs[3].to, 100, 0)
	near(legs[4].from, 100, 0)
	near(legs[4].to, 0, 0)
end)

test("loop builds a closed ring: last waypoint wraps back to the first", function()
	local w = MP.polylineWaypoints(twoSegmentPath())
	local legs = MP.buildLegs(w, "loop")

	assertEqual(3, #legs)
	assertNear(100, legs[1].length)
	assertNear(100, legs[2].length)
	assertNear(200, legs[3].length) -- (200,0) -> (0,0)
	near(legs[3].to, 0, 0)
end)

test("a single-segment path is a single forward+return pair of legs (both behaviours)", function()
	local w = MP.polylineWaypoints(singleSegmentPath())

	assertEqual(2, #MP.buildLegs(w, "pingpong")) -- forward leg + reflected leg
	assertEqual(2, #MP.buildLegs(w, "loop")) -- forward leg + wrap-back leg

	local legs = MP.buildLegs(w, "pingpong")
	near(legs[1].from, 0, 0)
	near(legs[1].to, 100, 0)
	near(legs[2].from, 100, 0)
	near(legs[2].to, 0, 0)
end)

test("a zero-length (duplicate-point) leg is dropped, not infinite", function()
	local object = polylineObject(0, 0, {
		{ x = 0, y = 0 },
		{ x = 0, y = 0 },
		{ x = 100, y = 0 },
	})
	local w = MP.polylineWaypoints(object)
	local legs = MP.buildLegs(w, "pingpong")

	assertTrue(#legs > 0, "should still traverse the surviving non-duplicate span")
	for _, leg in ipairs(legs) do
		assertTrue(leg.length > 0, "no zero-length leg should survive")
	end
end)

-- a path object with no polyline / a single point produces no legs
test("a degenerate path (one waypoint) has no legs", function()
	local object = polylineObject(0, 0, { { x = 5, y = 5 } })
	local w = MP.polylineWaypoints(object)
	assertEqual(0, #MP.buildLegs(w, "pingpong"))
	assertEqual(0, #MP.buildLegs(w, "loop"))
end)

--
-- constant-speed linear advance
--

test("advance moves at constant speed along a straight path", function()
	local s = MP.newStepper(MP.polylineWaypoints(singleSegmentPath()), "pingpong", 0, 100)

	near(MP.advance(s, 25), 25, 0)
	near(MP.advance(s, 25), 50, 0)
	near(MP.advance(s, 25), 75, 0)
	near(s.pos, 75, 0)
end)

test("advance interpolates along a non-axis-aligned path", function()
	local object = polylineObject(0, 0, { { x = 0, y = 0 }, { x = 30, y = 40 } })
	local s = MP.newStepper(MP.polylineWaypoints(object), "pingpong", 0, 100)

	-- 25px along a 50px 3-4-5 hypotenuse: halfway -> (15,20)
	near(MP.advance(s, 25), 15, 20)
	near(MP.advance(s, 25), 30, 40) -- the remaining 25 completes the single leg
end)

test("an advance that spans a whole leg lands exactly on the node", function()
	local s = MP.newStepper(MP.polylineWaypoints(twoSegmentPath()), "pingpong", 0, 100)

	near(MP.advance(s, 100), 100, 0)
	near(MP.advance(s, 100), 200, 0)
end)

--
-- pause at every node, including both endpoints
--

test("a nonzero pause holds the platform at every node, ending with the endpoint", function()
	-- pause=1s at speed 100 -> 100px of lost travel, consumed before moving on
	local s = MP.newStepper(MP.polylineWaypoints(twoSegmentPath()), "pingpong", 1, 100)

	near(MP.advance(s, 100), 100, 0) -- arrive at first node
	near(MP.advance(s, 30), 100, 0) -- holding (pause not exhausted)
	near(MP.advance(s, 70), 100, 0) -- holding done exactly as 100 total consumed
	near(MP.advance(s, 100), 200, 0) -- now travels to the endpoint
	near(MP.advance(s, 50), 200, 0) -- holding at the endpoint
	near(MP.advance(s, 50), 200, 0) -- holding done
	near(MP.advance(s, 100), 100, 0) -- pingpong: travels back, arrives at the node, holds
	near(MP.advance(s, 20), 100, 0) -- still holding mid-node
end)

test("pause=0 never holds, even at the endpoint", function()
	local s = MP.newStepper(MP.polylineWaypoints(singleSegmentPath()), "pingpong", 0, 100)

	near(MP.advance(s, 100), 100, 0)
	near(MP.advance(s, 100), 0, 0) -- reversed immediately, no hold
end)

--
-- pingpong reversal
--

test("pingpong reverses at the endpoint and heads back the same way it came", function()
	local s = MP.newStepper(MP.polylineWaypoints(singleSegmentPath()), "pingpong", 0, 100)

	near(MP.advance(s, 100), 100, 0)
	near(MP.advance(s, 25), 75, 0)
	near(MP.advance(s, 25), 50, 0)
	near(MP.advance(s, 100), 50, 0) -- back through the start, onward: 100px = 50 back + 50 forward
	near(s.pos, 50, 0)
end)

test("pingpong on a multi-segment path reverses only at the true ends", function()
	local s = MP.newStepper(MP.polylineWaypoints(twoSegmentPath()), "pingpong", 0, 100)

	near(MP.advance(s, 100), 100, 0) -- middle node, passes straight through
	near(MP.advance(s, 100), 200, 0) -- endpoint
	near(MP.advance(s, 50), 150, 0) -- heading back
	near(MP.advance(s, 50), 100, 0) -- middle node again
	near(MP.advance(s, 100), 0, 0) -- back through the middle to the start
	near(MP.advance(s, 100), 100, 0) -- forward again: 100px = 100 back-to-start + 100 forward-to-middle
end)

--
-- loop wrap-around
--

test("loop wraps past the last waypoint back to the first", function()
	local s = MP.newStepper(MP.polylineWaypoints(twoSegmentPath()), "loop", 0, 100)

	near(MP.advance(s, 100), 100, 0)
	near(MP.advance(s, 100), 200, 0)
	-- wrap-back leg: (200,0) -> (0,0), length 200
	near(MP.advance(s, 50), 150, 0)
	near(MP.advance(s, 150), 0, 0)
	near(MP.advance(s, 50), 50, 0) -- back onto the forward leg
end)

test("loop holds pause at the last waypoint like any other node", function()
	local s = MP.newStepper(MP.polylineWaypoints(twoSegmentPath()), "loop", 1, 100)
	local hold = 100 -- pause=1s at speed 100px/s

	near(MP.advance(s, 100), 100, 0) -- arrival: node 1, hold queued
	near(MP.advance(s, hold), 100, 0)
	near(MP.advance(s, 100), 200, 0) -- endpoint, hold queued
	near(MP.advance(s, 40), 200, 0) -- holding
	near(MP.advance(s, 60), 200, 0) -- holding done
	near(MP.advance(s, 50), 150, 0) -- moving down the wrap-back leg
end)

--
-- prop defaults via a real constructed MoverPlatform
--

local stubMap = {
	getObjectById = function()
		return nil
	end,
}

local function makePlatform(props)
	HeadlessBootstrap.resetWorld()
	return MoverPlatform({
		x = 0,
		y = 0,
		width = 128,
		height = 32,
		properties = props or {},
	}, stubMap)
end

test("defaults: speed 50, pingpong, pause 0.5, enabled true, running true", function()
	local p = makePlatform({})

	assertEqual(50, p.speed)
	assertEqual("pingpong", p.endBehavior)
	assertEqual(0.5, p.pause)
	assertTrue(p.enabled, "enabled should default to true")
	assertTrue(p.running, "running should start true (always-on until switched)")
	assertTrue(p.collider.walkable, "the static deck collider must be walkable ground")
	assertEqual(false, p.collider:isSensor(), "the deck is solid, not a sensor")
end)

test("props override the defaults when present", function()
	local p = makePlatform({
		speed = 250,
		endBehavior = "loop",
		pause = 2,
		enabled = false,
	})

	assertEqual(250, p.speed)
	assertEqual("loop", p.endBehavior)
	assertEqual(2, p.pause)
	assertFalse(p.enabled)
	assertFalse(p.running)
end)

test("a path property referencing an unresolved id still lets the entity construct", function()
	local p = makePlatform({ path = { id = 999 } })
	assertTrue(p.pathObject == nil)
end)
