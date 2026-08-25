-- src/fx/teleport_trail.lua — particle effect for teleporter travel
-- Emits oscillating particles along a parametric curve (half-sine wave + perpendicular noise)

local Class = require('lib.hump.class')
local FxBase = require('src.fx.base')
local Particles = require('src.particles')

local TeleportTrail = Class{__includes = FxBase}

-- Curve generation: half-sine wave + perpendicular noise
-- Returns a curve object with start, dest, and control parameters
function TeleportTrail.generateCurve(start, dest)
    local dx = dest.x - start.x
    local dy = dest.y - start.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
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
    local noiseFreq1 = 2.0  -- 2 cycles over the curve
    local noiseFreq2 = 5.3  -- 5.3 cycles for higher frequency wobble
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
function TeleportTrail.computeCurvePoint(curve, t)
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
function TeleportTrail.calculateTravelDuration(dist)
    local base = 0.5
    local perPixel = 0.0025
    local duration = base + perPixel * dist
    return math.max(0.5, math.min(3.0, duration))
end

function TeleportTrail:init(props)
    props = props or {}
    
    -- Store curve and travel parameters
    self.curve = props.curve or TeleportTrail.generateCurve(props.start, props.dest)
    self.duration = props.duration or TeleportTrail.calculateTravelDuration(self.curve.dist)
    self.elapsed = 0
    self.finished = false
    
    -- Emit rate: particles per second along the curve
    self.emitRate = props.emitRate or 80  -- particles per second
    self.emitAccumulator = 0
    
    -- Call parent init with hold=true to prevent auto-burst
    props.hold = true
    FxBase.init(self, props)
    
    -- Override emitter config for trail particles
    self.emitter = Particles.new_emitter(self:trailConfig())
end

function TeleportTrail:trailConfig()
    return {
        position = {x = self.curve.startX, y = self.curve.startY},
        lifetime = {min = 0.3, max = 0.8},
        speed = {min = 5, max = 25},
        direction = {angle = 0, spread = math.pi * 2}, -- omnidirectional
        gravity = {x = 0, y = 0},
        size = {start = 30, ["end"] = 2.5},
        colors = {
            start = {0.2, 0.8, 1.0, 0.9},   -- cyan
            ["end"] = {0.6, 0.3, 1.0, 0.0}  -- magenta fade
        },
        image = 'res/img/fx/fx_blob_glow.png',
        rotation = {angle = 0, spread = math.pi * 2},
        spin = {min = -2, max = 2},
        fadeIn = 0.15,
        area = {w = 8, h = 8},
    }
end

function TeleportTrail:update(dt)
    self.elapsed = self.elapsed + dt
    
    if self.elapsed >= self.duration then
        self.elapsed = self.duration
        self.finished = true
    end
    
    -- Emit particles at current curve position
    self.emitAccumulator = self.emitAccumulator + self.emitRate * dt
    local emitCount = math.floor(self.emitAccumulator)
    self.emitAccumulator = self.emitAccumulator - emitCount
    
    if emitCount > 0 and not self.finished then
        local t = self.elapsed / self.duration
        local pos = TeleportTrail.computeCurvePoint(self.curve, t)
        self.emitter.opts.position = pos
        self.emitter:emit(emitCount)
    end
    
    -- Update particles
    self.emitter:update(dt)
end

function TeleportTrail:draw()
    self.emitter:draw()
end

function TeleportTrail:done()
    return self.finished and self.emitter:done()
end

-- Export curve math for testing
TeleportTrail.generateCurve = TeleportTrail.generateCurve
TeleportTrail.computeCurvePoint = TeleportTrail.computeCurvePoint
TeleportTrail.calculateTravelDuration = TeleportTrail.calculateTravelDuration

return TeleportTrail