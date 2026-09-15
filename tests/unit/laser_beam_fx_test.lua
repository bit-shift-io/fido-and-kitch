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