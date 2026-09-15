-- Pure unit tests for src/fx/laser_beam.lua's scrolling-UV math -- the
-- renderer itself needs love.graphics, but scaleX/u0/span/sampledTexel are
-- pure geometry, so it tests cleanly headless (mirrors how
-- laser_state_test.lua drives only the decision helpers).
local LaserBeam = require("src.fx.laser_beam")

local function scaleX()
	return LaserBeam.scaleXFor(546, LaserBeam.TILE_LENGTH) -- real texture width, default tile length
end

-- World position where texture texel T0 appears on the beam, given scroll
-- offset u0: solve (w/sx + u0) ≡ T0 (mod 546) for w, kept inside one tile.
local function worldOfTexel(T0, u0, sx)
	return (T0 - u0) * sx % LaserBeam.TILE_LENGTH
end

test("the world-per-texel scale maps one texture copy to one tile length", function()
	assertNear(LaserBeam.TILE_LENGTH / 546, LaserBeam.scaleXFor(546, LaserBeam.TILE_LENGTH))
	assertNear(1, LaserBeam.scaleXFor(546, 546))
end)

test("degenerate inputs to the scale produce a zero scale", function()
	assertEqual(0, LaserBeam.scaleXFor(0, 128))
	assertEqual(0, LaserBeam.scaleXFor(546, 0))
end)

-- Regression: at 1:1 a copy of the 546px-wide texture spans a whole
-- room-scale beam and reads as a single stretched texture. The default
-- repeat must be short enough that a typical 640px (20-tile) laser still
-- shows several repeats.
test("a room-scale beam spans several texture widths, not one stretched copy", function()
	local span = LaserBeam.texelSpan(640, scaleX())
	assertTrue(span > 3 * 546, "expected a 640px beam to span several repeats, got " .. span)
end)

test("the quads u coordinate is a plain world-to-texel ratio", function()
	-- 90px beam: fewer texels than the image -> a partial single repeat
	assertNear(90 * 546 / LaserBeam.TILE_LENGTH, LaserBeam.texelSpan(90, scaleX()))
	-- exactly one tile long -> exactly one full image width
	assertNear(546, LaserBeam.texelSpan(LaserBeam.TILE_LENGTH, scaleX()))
end)

test("the scroll offset is in texture texels and wraps every image width", function()
	-- 0.4s * 64px/s = 25.6 world px = 25.6 / (TILE_LENGTH/546) texels, negated
	local expected = (-25.6 * 546 / LaserBeam.TILE_LENGTH) % 546
	assertNear(expected, LaserBeam.u0Texel(0.4, 64, scaleX(), 546))
	-- a full tile scroll at 64px/s wraps to 0: TILE_LENGTH px = one full image
	local period = LaserBeam.TILE_LENGTH / 64
	assertNear(0, LaserBeam.u0Texel(period, 64, scaleX(), 546))
	assertTrue(LaserBeam.u0Texel(1000, 64, scaleX(), 546) >= 0)
	assertTrue(LaserBeam.u0Texel(1000, 64, scaleX(), 546) < 546)
end)

test("degenerate inputs to the scroll offset yield zero", function()
	assertEqual(0, LaserBeam.u0Texel(10, 64, 0, 546))
	assertEqual(0, LaserBeam.u0Texel(10, 64, scaleX(), 0))
end)

-- The core promise of the scroll: sampling is periodic with the texture
-- width, so a scroll offset one full period apart is bit-for-bit the same
-- beam. There is no instant where "a whole texture length pops" -- the wrap
-- is invisible by construction, not an event.
test("a full-period scroll offset is identical, never a pop", function()
	local sx = scaleX()
	local offsets = { 0, 37, 546, 546 + 37, 546 * 3 + 17.5 }
	for _, u0 in ipairs(offsets) do
		for w = 0, 640, 16 do
			local a = LaserBeam.sampledTexel(w, u0, sx, 546)
			local b = LaserBeam.sampledTexel(w, (u0 + 546) % 546, sx, 546)
			assertNear(a, b, 0.0001, ("sample at w=%d for u0=%g must be period-identical"):format(w, u0))
		end
	end
end)

-- Within one period the scroll is a slide, not a flip: a fixed point's
-- content advances by exactly the elapsed texels, one at a time. Combined
-- with period-identity above, this is the whole "no texture chunks" story.
test("within a period, content slides texel by texel, never jumping", function()
	local sx = scaleX()
	local u0early = LaserBeam.u0Texel(0.1, 64, sx, 546) -- 0.1s elapsed
	local u0late = LaserBeam.u0Texel(0.3, 64, sx, 546) -- 0.2s later, same period
	local delta = (u0late - u0early)
	-- 0.2s * 64px/s = 12.8 world px = 12.8 / scaleX texels; negated scroll
	-- pulls LATER samples EARLIER in the texture -> negative delta
	assertNear(-12.8 / sx, delta)
	local w = 200
	local expect = LaserBeam.sampledTexel(w, u0early, sx, 546) + delta
	assertNear((w / sx + u0late) % 546, expect)
end)

-- The direction contract: as the phase advances, a texture feature's world
-- position must move TOWARD x2 (away from the emitter) -- the reversed
-- direction. A feature at texel T0 moving with the scroll proves it.
test("the scroll travels toward the far end (x2), reversed from the muzzle", function()
	local sx = scaleX()
	local u0early = LaserBeam.u0Texel(0.2, 64, sx, 546)
	local u0late = LaserBeam.u0Texel(1.0, 64, sx, 546) -- later, same period
	local T0 = 100
	local wEarly = worldOfTexel(T0, u0early, sx)
	local wLate = worldOfTexel(T0, u0late, sx)
	-- u0 late is EARLIER in the texture (negated), so the feature sits
	-- further along the beam (larger w): flow is toward x2
	assertTrue(wLate > wEarly, "feature must move toward the far end as the phase grows")
	-- and it has moved exactly the scrolled distance, texel-faithful
	local travelled = wLate - wEarly
	assertNear(-(u0late - u0early) * sx, travelled)
end)

-- A mirror-bounced beam passes a cumulative world-length offset, so the
-- second segment continues exactly where the first ended -- the pattern
-- carries across the bounce instead of resampling.
test("the cumulative base offsets continue the texture across the bounce", function()
	local sx = scaleX()
	local len1 = 317
	local len2 = 150
	local u0 = 25.6
	-- end of segment 1
	local end1 = LaserBeam.sampledTexel(len1, u0, sx, 546)
	-- start of segment 2 = same sample with the cumulative base added
	local start2 = LaserBeam.sampledTexel(0, u0 + len1 / sx, sx, 546)
	assertNear(end1, start2, 0.0001, "segment 2 must pick up where segment 1 left off")
	-- and far into segment 2, global position maps to one continuous texel
	local global = len1 + 77
	local local2 = LaserBeam.sampledTexel(77, u0 + len1 / sx, sx, 546)
	local direct = LaserBeam.sampledTexel(global, u0, sx, 546)
	assertNear(local2, direct, 0.0001)
end)

test("degenerate inputs to the sampler yield zero", function()
	assertEqual(0, LaserBeam.sampledTexel(50, 3, 0, 546))
	assertEqual(0, LaserBeam.sampledTexel(50, 3, 2, 0))
end)

-- The drain-front continuation contract behind the OLD beam's UV window:
-- a draining old beam is drawn as the head-anchored trailing suffix whose
-- first segment is PARTIAL, sliced at the moving drain front. Anchoring a
-- partial suffix's UV window at the mirror (offset = mirror distance only)
-- makes every drawn texel read as if the lit portion started at the mirror
-- -- an error equal to the drained distance that grows frame to frame (the
-- apparent scroll speedup) and re-anchors when the front crosses a segment
-- joint (the jump). Anchoring the window at the DRAIN FRONT (mirror ABOVE
-- the drained length) keeps each drawn segment's accumulated baseWorld
-- equal to its true absolute world distance from the emitter, so the
-- scroll stays at exactly SCROLL_SPEED -- no speedup, no re-anchor.
-- Replicated here by emulating drawSegments' accumulation loop: for a
-- fixed absolute world point, the sampled texel must be identical to the
-- un-drained reference no matter how far the drain front has advanced.
test("old-beam drain anchors its UV at the drain front, never the mirror", function()
	local sx = scaleX()
	local u0 = 55.5 -- arbitrary fixed scroll phase (single frame)
	local mirrorDist = 260 -- world px emitter->mirror
	-- Old path beyond the mirror: mirror -> horizontal 60 -> vertical 40 (total 100).
	local oldReflected = {
		{ x1 = 260, y1 = 0, x2 = 320, y2 = 0 },
		{ x1 = 320, y1 = 0, x2 = 320, y2 = 40 },
	}
	local oldTotal = 100

	-- Emulate drawSegments' core: iterate segments, accumulate baseWorld
	-- (seeded with the anchor), and sample the point at the accumulated
	-- baseWorld + local distance if it lies on that segment.
	local function sampleDrawn(lit, anchor, worldX)
		local baseWorld = anchor
		for _, seg in ipairs(lit) do
			local len = math.sqrt((seg.x2 - seg.x1)^2 + (seg.y2 - seg.y1)^2)
			local localX = worldX - baseWorld -- local distance from this segment's start
			if localX >= 0 and localX <= len then
				return LaserBeam.sampledTexel(localX, u0 + baseWorld / sx, sx, 546)
			end
			baseWorld = baseWorld + len
		end
		return nil
	end

	-- The fixed world point: 90px past the mirror (near the old head).
	local pointX = mirrorDist + 90
	-- Reference texel: the point as a plain emitter-anchored chain.
	local reference = LaserBeam.sampledTexel(pointX, u0, sx, 546)

	-- Any drain extent still containing the point (>= its distance from the
	-- head) must sample the same texel -- with the drain-front anchor.
	for _, extent in ipairs({ 100, 40, 12 }) do
		local drained = oldTotal - extent
		local lit = LaserBeam.suffixToLength(oldReflected, extent)
		local sample = sampleDrawn(lit, mirrorDist + drained, pointX)
		assertTrue(sample ~= nil, "suffix must contain the fixed point at extent=" .. extent)
		assertNear(reference, sample, 1e-6,
			("drain-front anchor must preserve the texel at extent=%d"):format(extent))
	end
end)

-- The merge-continuity contract behind drawSegments' baseOffset: an
-- emitter->mirror->collision beam drawn as TWO calls -- base chain plus a
-- reflected part carrying the mirror's world length -- must sample texels
-- identically to the same geometry drawn as ONE chain. If the reflected
-- part's window restarted at 0 at the mirror, every texel on it (the head
-- included) would shift by the mirror distance when the parts merge --
-- the visible stutter at the collision point.
test("a reflected part with a base offset samples like the merged single chain", function()
	local sx = scaleX()
	local u0 = 123.4 -- arbitrary scroll phase
	local mirrorDist = 260 -- world px emitter->mirror
	-- Reflected part drawn separately: local distance d carries base base offset.
	local d = 88
	local splitSample = LaserBeam.sampledTexel(mirrorDist + d, u0, sx, 546) -- global = mirror + d... local version below
	-- In drawSegments the reflected first segment's baseWorld = mirrorDist:
	local localWithOffset = LaserBeam.sampledTexel(d, u0 + mirrorDist / sx, sx, 546)
	local globalMerged = LaserBeam.sampledTexel(mirrorDist + d, u0, sx, 546)
	assertNear(globalMerged, localWithOffset, 1e-6, "offset reflected part must match the merged chain")
	assertNear(globalMerged, splitSample, 1e-6)
	-- And, as the regression that motivated baseOffset: WITHOUT the offset
	-- the reflected part samples a DIFFERENT texel than the merged chain
	-- whenever the mirror distance isn't an exact multiple of a texture copy.
	local localNoOffset = LaserBeam.sampledTexel(d, u0, sx, 546)
	assertTrue(math.abs(localNoOffset - globalMerged) > 1, "no-offset reflected sampling must differ (the bug being fixed)")
end)

-- clipSegmentsToLength truncates a path to a given visible length
-- along the polyline from the emitter. A partial final segment is
-- clipped so the returned polyline's total world length <= the
-- requested length. Used by Laser:draw so the visible beam extent
-- can animate at SCROLL_SPEED without changing resolved geometry.
test("clipSegmentsToLength truncates the last segment exactly at the length", function()
	local segs = { { x1 = 0, y1 = 0, x2 = 100, y2 = 0 }, { x1 = 100, y1 = 0, x2 = 100, y2 = 50 } }
	local clipped = LaserBeam.clipSegmentsToLength(segs, 120)
	assertEqual(2, #clipped, "first full segment kept")
	-- second segment is partially drawn: 20 px along its 50 px length
	local last = clipped[2]
	assertNear(20, math.sqrt((last.x2 - last.x1)^2 + (last.y2 - last.y1)^2), 1e-6,
		"partial second segment must be 20px long")
end)

test("clipSegmentsToLength with length longer than the path returns all segments", function()
	local segs = { { x1 = 0, y1 = 0, x2 = 100, y2 = 0 } }
	local clipped = LaserBeam.clipSegmentsToLength(segs, 999)
	assertEqual(1, #clipped)
	assertEqual(segs[1].x2, clipped[1].x2)
end)

test("clipSegmentsToLength with zero length returns an empty array", function()
	local segs = { { x1 = 0, y1 = 0, x2 = 100, y2 = 0 } }
	local clipped = LaserBeam.clipSegmentsToLength(segs, 0)
	assertEqual(0, #clipped)
end)

test("clipSegmentsToLength with a single short beam returns just that segment", function()
	local segs = { { x1 = 0, y1 = 0, x2 = 30, y2 = 0 } }
	local clipped = LaserBeam.clipSegmentsToLength(segs, 30)
	assertEqual(1, #clipped)
	assertEqual(30, math.sqrt((clipped[1].x2 - clipped[1].x1)^2 + (clipped[1].y2 - clipped[1].y1)^2))
end)

-- Beam extent grows toward the full resolved path length at
-- SCROLL_SPEED and clamps at it (holds at full once reached).
test("beam extent grows toward full path length and clamps", function()
	local path = { { x1 = 0, y1 = 0, x2 = 100, y2 = 0 } }
	local extent = 0
	-- 100px at 64px/s: after 1s -> 64, still growing; after 2s -> 128, clamps to 100.
	extent = math.min(100, extent + LaserBeam.SCROLL_SPEED * 1)
	assertEqual(64, extent)
	extent = math.min(100, extent + LaserBeam.SCROLL_SPEED * 1)
	assertEqual(100, extent, "must clamp at full path length")
end)

-- commonPrefixLength returns the shared length from the emitter.
test("commonPrefixLength matches identical paths", function()
	local a = { { x1 = 0, y1 = 0, x2 = 100, y2 = 0 }, { x1 = 100, y1 = 0, x2 = 100, y2 = 50 } }
	local b = { { x1 = 0, y1 = 0, x2 = 100, y2 = 0 }, { x1 = 100, y1 = 0, x2 = 100, y2 = 50 } }
	assertEqual(150, LaserBeam.commonPrefixLength(a, b))
end)

test("commonPrefixLength stops at first differing segment", function()
	local a = { { x1 = 0, y1 = 0, x2 = 100, y2 = 0 }, { x1 = 100, y1 = 0, x2 = 100, y2 = 50 } }
	local b = { { x1 = 0, y1 = 0, x2 = 100, y2 = 0 }, { x1 = 100, y1 = 0, x2 = 150, y2 = 0 } }
	-- first segment identical (100px), second differs -> common prefix = 100px
	assertEqual(100, LaserBeam.commonPrefixLength(a, b))
end)

test("commonPrefixLength with empty path returns 0", function()
	assertEqual(0, LaserBeam.commonPrefixLength({}, { { x1 = 0, y1 = 0, x2 = 10, y2 = 0 } }))
end)

-- suffixBeyond returns the tail beyond a given prefix length.
test("suffixBeyond returns full path when prefixLen is 0", function()
	local path = { { x1 = 0, y1 = 0, x2 = 100, y2 = 0 } }
	local suffix = LaserBeam.suffixBeyond(path, 0)
	assertEqual(1, #suffix)
	assertEqual(100, math.sqrt((suffix[1].x2 - suffix[1].x1)^2 + (suffix[1].y2 - suffix[1].y1)^2))
end)

test("suffixBeyond returns partial segment when prefixLen cuts inside a segment", function()
	local path = { { x1 = 0, y1 = 0, x2 = 100, y2 = 0 } }
	local suffix = LaserBeam.suffixBeyond(path, 40)
	assertEqual(1, #suffix)
	assertNear(60, math.sqrt((suffix[1].x2 - suffix[1].x1)^2 + (suffix[1].y2 - suffix[1].y1)^2), 1e-6)
	assertNear(40, suffix[1].x1, 1e-6, "suffix must start at the cut point")
end)

test("suffixBeyond returns empty when prefixLen exceeds path length", function()
	local path = { { x1 = 0, y1 = 0, x2 = 50, y2 = 0 } }
	local suffix = LaserBeam.suffixBeyond(path, 100)
	assertEqual(0, #suffix)
end)

-- suffixToLength returns the trailing portion of a path anchored at its
-- far end (the head) -- the drain direction a laser beam uses when it is
-- no longer fed: the tail (mirror/emitter end) dies first, the head stays
-- put until the very end.
test("suffixToLength returns the whole path when length equals the path", function()
	local path = { { x1 = 0, y1 = 0, x2 = 100, y2 = 0 } }
	local lit = LaserBeam.suffixToLength(path, 100)
	assertEqual(1, #lit)
	assertNear(100, math.sqrt((lit[1].x2 - lit[1].x1)^2 + (lit[1].y2 - lit[1].y1)^2), 1e-6)
end)

test("suffixToLength drains from the tail, keeping the head anchored", function()
	local path = { { x1 = 0, y1 = 0, x2 = 100, y2 = 0 } }
	local lit = LaserBeam.suffixToLength(path, 40)
	assertEqual(1, #lit)
	-- head stays at the far end (x2=100)...
	assertNear(100, lit[1].x2, 1e-6, "old head must stay at the far end while draining")
	-- ...and the visible portion is the trailing 40px (start cuts in at 60).
	assertNear(60, lit[1].x1, 1e-6, "the tail drain front must sit 40px before the head")
	assertNear(40, math.sqrt((lit[1].x2 - lit[1].x1)^2 + (lit[1].y2 - lit[1].y1)^2), 1e-6)
end)

test("suffixToLength cuts a partial first segment when the drain crosses a joint", function()
	local path = {
		{ x1 = 0, y1 = 0, x2 = 100, y2 = 0 },
		{ x1 = 100, y1 = 0, x2 = 100, y2 = 50 },
	}
	-- full length 150; lit length 75 -> the drain front sits 75px before the
	-- head, i.e. 25px along the second segment (partial cut + full remainder).
	local lit = LaserBeam.suffixToLength(path, 75)
	local litLen = 0
	for _, seg in ipairs(lit) do
		litLen = litLen + math.sqrt((seg.x2 - seg.x1)^2 + (seg.y2 - seg.y1)^2)
	end
	assertEqual(2, #lit)
	assertNear(75, lit[1].x1, 1e-6)
	assertNear(0, lit[1].y1, 1e-6)
	assertNear(100, lit[1].x2, 1e-6)
	assertNear(100, lit[2].x1, 1e-6)
	assertNear(50, lit[2].y2, 1e-6, "head must stay at the path's final endpoint")
	assertNear(75, litLen, 1e-6)
end)

test("suffixToLength with zero length returns empty", function()
	local path = { { x1 = 0, y1 = 0, x2 = 50, y2 = 0 } }
	assertEqual(0, #LaserBeam.suffixToLength(path, 0))
end)

test("suffixToLength with nil segments returns empty", function()
	assertEqual(0, #LaserBeam.suffixToLength(nil, 10))
end)