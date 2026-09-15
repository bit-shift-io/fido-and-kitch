-- Pure unit tests for src/entities/laser.lua's power state machine, driven
-- directly against Laser._internal -- no Sprite/Collider/World construction
-- needed (mirrors tests/unit/blocker_test.lua's Part 1: pure decision
-- helpers). Entity-level (sound-once-per-edge, timeline reverse-in-place)
-- coverage belongs to tests/integration/laser_powerup_safety_test.lua,
-- which constructs a real Laser through the full game stack.
local HeadlessBootstrap = require("tests.support.headless_bootstrap")
HeadlessBootstrap.resetWorld()

local Laser = require("src.entities.laser")
local L = Laser._internal

test("an off laser starts warming once its switch is enabled", function()
	assertEqual("warming", L.nextState("off", true))
end)

test("an off laser with its switch still disabled stays off", function()
	assertEqual("off", L.nextState("off", false))
end)

test("a warming laser stays warming while the switch stays enabled", function()
	assertEqual("warming", L.nextState("warming", true))
end)

test("a fully-on laser stays on while the switch stays enabled", function()
	assertEqual("on", L.nextState("on", true))
end)

-- Switching off mid-warming reverses from wherever it currently is --
-- 'cooling', not an instant snap to 'off'.
test("switching off mid-warming moves to cooling, not straight to off", function()
	assertEqual("cooling", L.nextState("warming", false))
end)

test("switching off a fully-on laser starts cooling", function()
	assertEqual("cooling", L.nextState("on", false))
end)

test("a cooling laser stays cooling while the switch stays disabled", function()
	assertEqual("cooling", L.nextState("cooling", false))
end)

-- Interrupted mid-power-down: switching back on before cooling finishes
-- reverses back to warming rather than finishing the power-down first.
test("switching on mid-cooling reverses back to warming", function()
	assertEqual("warming", L.nextState("cooling", true))
end)

-- Animation-finish transitions: warming completes to the held 'on' frame;
-- cooling completes back to 'off'. Neither 'off' nor 'on' has anything
-- mid-flight for a finish signal to act on.
test("the warm-up animation finishing holds the laser at on", function()
	assertEqual("on", L.nextStateOnAnimationFinish("warming"))
end)

test("the power-down animation finishing returns the laser to off", function()
	assertEqual("off", L.nextStateOnAnimationFinish("cooling"))
end)

test("animation finish has no effect on off or on -- nothing mid-flight", function()
	assertEqual("off", L.nextStateOnAnimationFinish("off"))
	assertEqual("on", L.nextStateOnAnimationFinish("on"))
end)

-- The single gate every interaction (kill/block/destroy/activate) should
-- read: only the held final frame is full power.
test("only the on state is fully on -- off/warming/cooling all gate interactions off", function()
	assertFalse(L.isFullyOn("off"))
	assertFalse(L.isFullyOn("warming"))
	assertTrue(L.isFullyOn("on"))
	assertFalse(L.isFullyOn("cooling"))
end)

-- Frame data is authored directly, thin -> full width, ascending: no
-- procedural width/color computation anywhere in the render path.
test("power frames run from a thin first frame to a wider, brighter last frame", function()
	local frames = L.powerFrames
	assertTrue(#frames >= 2, "expected more than one frame to animate through")
	assertTrue(frames[1].width < frames[#frames].width, "expected the beam to widen from the first frame to the last")
end)

-- segmentLength, pathHash, pathLength are pure geometry helpers
-- exposed via Laser._internal for unit testing.
test("segmentLength returns the world px of a segment", function()
	assertEqual(100, L.segmentLength({ x1 = 0, y1 = 0, x2 = 100, y2 = 0 }))
	assertEqual(50, L.segmentLength({ x1 = 0, y1 = 0, x2 = 0, y2 = 50 }))
	assertEqual(0, L.segmentLength({ x1 = 5, y1 = 5, x2 = 5, y2 = 5 }))
end)

test("pathLength sums all segment lengths", function()
	local path = { { x1 = 0, y1 = 0, x2 = 30, y2 = 0 }, { x1 = 30, y1 = 0, x2 = 30, y2 = 40 } }
	assertEqual(70, L.pathLength(path))
end)

test("pathHash is stable for identical segments and differs for different paths", function()
	local a = { { x1 = 0, y1 = 0, x2 = 100, y2 = 0 } }
	local b = { { x1 = 0, y1 = 0, x2 = 100, y2 = 0 } }
	local c = { { x1 = 0, y1 = 0, x2 = 0, y2 = 100 } }
	assertEqual(L.pathHash(a), L.pathHash(b), "identical paths must hash equal")
	assertTrue(L.pathHash(a) ~= L.pathHash(c), "different paths must hash different")
end)

-- advanceBeamAnimation grows the visible extent toward the full path
-- length at SCROLL_SPEED and starts a retracting tail when the
-- resolved path changes. Tested headlessly by constructing a Laser
-- through the headless bootstrap and stepping it.
local Rect = require("src.utils.rect")

local function makeLaser(pathSegments)
	-- Build a minimal Tiled object the Laser init reaches for: a
	-- floor-mounted laser firing 'up'.
	local obj = {
		x = 64, y = 64, width = 16, height = 16,
		properties = { direction = "up", enabled = true },
	}
	local laser = Laser(obj, { getPixelSize = function() return 800, 600 end })
	laser.beamSegments = pathSegments or {}
	laser.prevPathHash = nil
	laser.baseExtent = 0
	laser.oldReflectedExtent = 0
	laser.newReflectedExtent = 0
	laser.baseSegments = nil
	laser.oldReflectedSegments = nil
	laser.newReflectedSegments = nil
	laser.beamScrollPhase = 0
	laser.powerState = "on"
	laser.powerTimeline = { update = function() end, getFrameIndex = function() return 5 end }
	return laser
end

test("advanceBeamAnimation grows a fresh beam from zero to full", function()
	local laser = makeLaser({ { x1 = 0, y1 = 0, x2 = 100, y2 = 0 } })
	laser.prevPathHash = nil -- first frame: no prior path
	laser:advanceBeamAnimation(1.0, { { x1 = 0, y1 = 0, x2 = 100, y2 = 0 } })
	-- 100px at 64px/s after 1s -> 64px visible (still growing)
	assertEqual(64, laser.baseExtent)
	laser:advanceBeamAnimation(1.0, { { x1 = 0, y1 = 0, x2 = 100, y2 = 0 } })
	-- another 64 -> 128 clamps to 100
	assertEqual(100, laser.baseExtent)
end)

test("advanceBeamAnimation starts a retracting tail when path changes", function()
	local oldPath = { { x1 = 0, y1 = 0, x2 = 100, y2 = 0 } }
	local newPath = { { x1 = 0, y1 = 0, x2 = 0, y2 = 100 } }
	local laser = makeLaser(oldPath)
	laser.prevPathHash = L.pathHash(oldPath)
	laser.baseExtent = 100
	laser:advanceBeamAnimation(0, newPath)
	-- After a path change, the old path becomes a retracting tail
	-- (oldReflectedSegments) and the new path starts growing from 0.
	assertTrue(laser.oldReflectedSegments ~= nil, "old path must become a retracting tail")
	assertEqual(100, laser.oldReflectedExtent)
	assertEqual(0, laser.newReflectedExtent)
	assertEqual(0, laser.baseExtent)
end)

test("retracting tail shrinks to nil at SCROLL_SPEED", function()
	local oldPath = { { x1 = 0, y1 = 0, x2 = 100, y2 = 0 } }
	local laser = makeLaser(oldPath)
	laser.prevPathHash = L.pathHash(oldPath)
	-- Set up a path change scenario: first establish the beam at full length
	laser.baseExtent = 100
	-- Now simulate a path change (mirror flip)
	laser:advanceBeamAnimation(0, { { x1 = 0, y1 = 0, x2 = 0, y2 = 100 } }) -- path changes to vertical
	-- Now we have: baseExtent=0, oldReflectedExtent=100, newReflectedExtent=0
	-- Advance time to retract the tail
	laser:advanceBeamAnimation(1.0, { { x1 = 0, y1 = 0, x2 = 0, y2 = 100 } }) -- same vertical path
	-- 100px retracted at 64px/s after 1s -> 36px remains.
	assertEqual(36, laser.oldReflectedExtent)
	laser:advanceBeamAnimation(1.0, { { x1 = 0, y1 = 0, x2 = 0, y2 = 100 } })
	-- after another second -> 0 -> tail destroyed
	assertEqual(0, laser.oldReflectedExtent)
	assertTrue(laser.oldReflectedSegments == nil, "tail must be destroyed at 0 length")
end)

-- Mirror-flip merge: after the new reflected beam reaches full length,
-- it merges into base. The visible head must NOT jump back to the mirror
-- distance -- baseExtent must match the full resolved path length.
test("the old beam's drain window must not jump when the new beam merges", function()
	local laser = makeLaser({ { x1 = 0, y1 = 0, x2 = 100, y2 = 0 } })
	-- Same geometry as the merge test above: emitter→mirror (50) + old
	-- reflected (50). The OLD beam is LONGER than the NEW beam, so at the
	-- moment the new one reaches its collision and merges into base, the
	-- old beam is STILL DRAINING.
	local oldFull = { { x1 = 0, y1 = 0, x2 = 50, y2 = 0 }, { x1 = 50, y1 = 0, x2 = 50, y2 = 50 } }
	local newFull = { { x1 = 0, y1 = 0, x2 = 50, y2 = 0 }, { x1 = 50, y1 = 0, x2 = 90, y2 = 0 } }
	laser.baseSegments = oldFull
	laser.baseExtent = 50
	laser.prevPathHash = L.pathHash(oldFull)
	-- Flip: mirror at 50, old reflected 50 total, new reflected 40 total.
	laser:advanceBeamAnimation(0, newFull)
	local mirrorDist = L.pathLength(laser.baseSegments)
	-- Drain the old beam a little -- say 15px gone, so 35 of 50 remains.
	laser.oldReflectedExtent = 35
	assertEqual(mirrorDist, laser.splitMirrorDist, "split must capture the mirror distance at the flip")

	-- The old beam's UV window anchor is splitMirrorDist + drained. Capture
	-- the anchor the drain front presently sits at.
	local drained = L.pathLength(laser.oldReflectedSegments) - laser.oldReflectedExtent
	local anchorBefore = laser.splitMirrorDist + drained

	-- Grow the new reflected (0 -> 40 at 64px/s needs 1s) so it merges
	-- into base, replacing baseSegments with the full 90px path.
	laser:advanceBeamAnimation(1.0, newFull)
	assertEqual(0, laser.newReflectedExtent, "new reflected must merge away")
	assertTrue(laser.newReflectedSegments == nil, "new reflected must be nil after merge")
	assertEqual(90, L.pathLength(laser.baseSegments), "merged base is the full 90px path")

	-- THE REGRESSION: splitMirrorDist is geometry fixed at the flip; even
	-- though baseSegments grew from 50 to 90 at the merge, the still
	-- draining old beam's window anchor must not move. If draw() had
	-- re-derived the mirror offset from pathLength(baseSegments) the
	-- anchor would have jumped by 40 world px in one frame -- the visible
	-- old-beam texture skip the moment the new beam hits its collision.
	assertEqual(mirrorDist, laser.splitMirrorDist,
		"splitMirrorDist must stay fixed at the flip geometry through the merge")
	local anchorAfter = laser.splitMirrorDist + drained
	assertNear(anchorBefore, anchorAfter, 1e-6,
		"the old beam's drain anchor must be invariant across the merge")
end)

test("merging a fully-grown new reflected beam snaps baseExtent to the full path", function()
	local laser = makeLaser({ { x1 = 0, y1 = 0, x2 = 100, y2 = 0 } })
	laser.prevPathHash = L.pathHash({ { x1 = 0, y1 = 0, x2 = 100, y2 = 0 } })
	-- First: path change to a mirror-flip: old path + reflected extension.
	-- Simulate emitter→mirror (50) + old-reflected (50 total) → emitter→mirror (50) + new-reflected (50, different angle).
	local oldFull = { { x1 = 0, y1 = 0, x2 = 50, y2 = 0 }, { x1 = 50, y1 = 0, x2 = 50, y2 = 50 } }
	local newFull = { { x1 = 0, y1 = 0, x2 = 50, y2 = 0 }, { x1 = 50, y1 = 0, x2 = 100, y2 = 0 } }
	laser.baseSegments = oldFull
	laser.baseExtent = 50 -- incident (emitter→mirror) already at mirror distance
	laser.prevPathHash = L.pathHash(oldFull)
	-- Trigger the flip
	laser:advanceBeamAnimation(0, newFull)
	assertEqual(0, laser.newReflectedExtent, "new reflected must start at 0")
	assertEqual(50, L.pathLength(laser.newReflectedSegments), "new reflected must be the mirror→wall suffix")
	local mirrorDist = L.pathLength(laser.baseSegments) -- emitter→mirror
	-- Grow the new reflected to full length (50px at 64px/s needs 1s)
	laser:advanceBeamAnimation(1.0, newFull)
	-- 0 + 64 → clamped to 50; merge should have fired
	assertEqual(0, laser.newReflectedExtent, "new reflected must be cleared after merge")
	assertTrue(laser.newReflectedSegments == nil, "new reflected must be nil after merge")
	local fullLen = L.pathLength(newFull)
	assertEqual(fullLen, laser.baseExtent, "baseExtent must match full path after merge, not mirror distance")
	-- Verify the head is at the wall position after merge
	local lastSeg = laser.baseSegments[#laser.baseSegments]
	assertNear(100, lastSeg.x2, 1e-6, "drawn beam head must stay at the wall")
end)
