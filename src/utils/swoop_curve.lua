-- src/utils/swoop_curve.lua — shared swoop curve utilities
-- Curve generation: half-sine wave + perpendicular noise
-- Used by teleporter FX and potentially other flight mechanics

local SwoopCurve = {}

-- Generate a curve object with start, dest, and control parameters
-- Returns a curve object with start, dest, and control parameters
function SwoopCurve.generateCurve(start, dest)
	local dx = dest.x - start.x
	local dy = dest.y - start.y
	local dist = math.sqrt(dx * dx + dy * dy)

	-- Normalized direction vector
	local dirX = dx / dist
	local dirY = dy / dist

	-- Perpendicular vector (rotated 90 degrees CCW)
	local perpX = -dirY
	local perpY = dirX

	-- Curve parameters
	-- Half-sine wave amplitude: 12% of distance, capped at 60px
	local amplitude = math.min(dist * 0.12, 60)
	-- Perpendicular noise: multiple sine waves for wobble
	local noiseFreq1 = 2.0 -- 2 cycles over the curve
	local noiseFreq2 = 5.3 -- 5.3 cycles for higher frequency wobble
	local noiseFreq3 = 11.7 -- 11.7 cycles for fine detail
	local noiseAmp1 = amplitude * 0.2
	local noiseAmp2 = amplitude * 0.1
	local noiseAmp3 = amplitude * 0.05

	-- Deterministic seed based on start/dest positions
	local seed = math.floor(start.x * 73856093 + start.y * 19349663 + dest.x * 83492791 + dest.y * 93287471) % 1000000

	return {
		startX = start.x,
		startY = start.y,
		destX = dest.x,
		destY = dest.y,
		dirX = dirX,
		dirY = dirY,
		perpX = perpX,
		perpY = perpY,
		dist = dist,
		amplitude = amplitude,
		noiseFreq1 = noiseFreq1,
		noiseFreq2 = noiseFreq2,
		noiseFreq3 = noiseFreq3,
		noiseAmp1 = noiseAmp1,
		noiseAmp2 = noiseAmp2,
		noiseAmp3 = noiseAmp3,
		seed = seed,
	}
end

-- Compute position on curve at parameter t (0..1)
function SwoopCurve.computeCurvePoint(curve, t)
	t = math.max(0, math.min(1, t))

	-- Linear interpolation along direction
	local baseX = curve.startX + curve.dirX * curve.dist * t
	local baseY = curve.startY + curve.dirY * curve.dist * t

	-- Envelope that goes to 0 at t=0 and t=1 (so noise vanishes at endpoints)
	local envelope = math.sin(t * math.pi)

	-- Half-sine wave offset (peaks at t=0.5)
	local sineOffset = envelope * curve.amplitude

	-- Perpendicular noise (multiple sine waves for wobble), modulated by envelope
	-- Use curve seed for deterministic but varied noise
	local phase1 = curve.seed * 0.001
	local phase2 = curve.seed * 0.0037
	local phase3 = curve.seed * 0.0089

	local noise1 = math.sin(t * curve.noiseFreq1 * math.pi + phase1) * curve.noiseAmp1 * envelope
	local noise2 = math.sin(t * curve.noiseFreq2 * math.pi + phase2) * curve.noiseAmp2 * envelope
	local noise3 = math.sin(t * curve.noiseFreq3 * math.pi + phase3) * curve.noiseAmp3 * envelope

	local totalPerpOffset = sineOffset + noise1 + noise2 + noise3

	return {
		x = baseX + curve.perpX * totalPerpOffset,
		y = baseY + curve.perpY * totalPerpOffset,
	}
end

-- Travel duration: base 0.5s + 0.0025s per pixel, clamped 0.5-3s
function SwoopCurve.calculateTravelDuration(dist)
	local base = 0.5
	local perPixel = 0.0025
	local duration = base + perPixel * dist
	return math.max(0.5, math.min(3.0, duration))
end

return SwoopCurve
