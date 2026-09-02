-- src/fx/teleport_trail.lua — particle effect for teleporter travel
-- Emits oscillating particles along a parametric curve (half-sine wave + perpendicular noise)

local Class = require("lib.hump.class")
local FxBase = require("src.fx.base")
local Particles = require("src.emitters.sprite_emitter")
local SwoopCurve = require("src.utils.swoop_curve")

local TeleportTrail = Class({ __includes = FxBase })

-- Delegate curve math to shared SwoopCurve module
function TeleportTrail.generateCurve(start, dest)
	return SwoopCurve.generateCurve(start, dest)
end

function TeleportTrail.computeCurvePoint(curve, t)
	return SwoopCurve.computeCurvePoint(curve, t)
end

function TeleportTrail.calculateTravelDuration(dist)
	return SwoopCurve.calculateTravelDuration(dist)
end

function TeleportTrail:init(props)
	props = props or {}

	-- Store curve and travel parameters
	self.curve = props.curve or TeleportTrail.generateCurve(props.start, props.dest)
	self.duration = props.duration or TeleportTrail.calculateTravelDuration(self.curve.dist)
	self.elapsed = 0
	self.finished = false

	-- Emit rate: particles per second along the curve
	self.emitRate = props.emitRate or 80 -- particles per second
	self.emitAccumulator = 0

	-- Call parent init with hold=true to prevent auto-burst
	props.hold = true
	FxBase.init(self, props)

	-- Override emitter config for trail particles
	self.emitter = Particles.new_emitter(self:trailConfig())
end

function TeleportTrail:trailConfig()
	return {
		position = { x = self.curve.startX, y = self.curve.startY },
		lifetime = { min = 0.3, max = 0.8 },
		speed = { min = 5, max = 25 },
		direction = { angle = 0, spread = math.pi * 2 }, -- omnidirectional
		gravity = { x = 0, y = 0 },
		size = { start = 30, ["end"] = 2.5 },
		colors = {
			start = { 0.2, 0.8, 1.0, 0.9 }, -- cyan
			["end"] = { 0.6, 0.3, 1.0, 0.0 }, -- magenta fade
		},
		image = "res/img/fx/fx_blob_glow.png",
		rotation = { angle = 0, spread = math.pi * 2 },
		spin = { min = -2, max = 2 },
		fadeIn = 0.15,
		area = { w = 8, h = 8 },
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
	-- Draw debug curve line
	if conf.debug ~= false then
		self:drawCurveLine()
	end

	self.emitter:draw()
end

function TeleportTrail:drawCurveLine()
	-- Sample the curve and draw line connecting the points
	local samples = 50
	love.graphics.setColor(1, 1, 0, 0.5) -- yellow with 50% alpha

	for i = 0, samples - 1 do
		local t1 = i / samples
		local t2 = (i + 1) / samples

		local p1 = TeleportTrail.computeCurvePoint(self.curve, t1)
		local p2 = TeleportTrail.computeCurvePoint(self.curve, t2)

		love.graphics.line(p1.x, p1.y, p2.x, p2.y)
	end

	love.graphics.setColor(1, 1, 1, 1) -- reset to white
end

function TeleportTrail:done()
	return self.finished and self.emitter:done()
end

-- Export curve math for testing
TeleportTrail.generateCurve = TeleportTrail.generateCurve
TeleportTrail.computeCurvePoint = TeleportTrail.computeCurvePoint
TeleportTrail.calculateTravelDuration = TeleportTrail.calculateTravelDuration

return TeleportTrail
