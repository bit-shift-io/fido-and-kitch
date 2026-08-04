-- particles.lua — a tiny, dependency-free particle emitter engine.
--
-- Returns a single module table `Particles` exposing `Particles.new_emitter`:
--
--   local Particles = require('src.particles')
--   local e = Particles.new_emitter({ position = {x, y}, ... })
--   e:emit(n)      -- spawn n particles (capped)
--   e:update(dt)   -- integrate positions/velocities, expire dead particles
--   e:draw()       -- render each particle as a filled rectangle
--
-- The emitter owns all of its state; there are no globals and no shared
-- buffers, so any number of emitters can run independently. Rendering uses
-- love.graphics.setColor / love.graphics.rectangle only — no SpriteBatches,
-- no shaders. `love` is only touched from draw(), keeping update()/emit()
-- constructible and testable headless.
--
-- Emitter options (every field optional, defaults below):
--   position:  {x, y}                  center particles spawn at
--   lifetime:  {min, max} seconds      per-particle lifetime (uniform random)
--   speed:     {min, max} px/sec       initial speed (uniform random)
--   direction: {angle, spread} rad     angle + uniform random offset in +-spread
--   gravity:   {x, y} px/sec^2         constant acceleration applied each frame
--   size:      {start, end} px         lerped over the particle's lifetime
--   colors:    {start, end} {r,g,b,a}  lerped over the particle's lifetime
local Particles = {}

local function rand(min, max) return min + math.random() * (max - min) end
local function lerp(a, b, t) return a + (b - a) * t end

local Emitter = {}
Emitter.__index = Emitter

-- Spawn n particles at the emitter's current position, each with its own
-- randomized lifetime, speed and heading. Never grows past VARIABLE.cap.
function Emitter:emit(n)
	n = n or 1
	for _ = 1, n do
		if #self.particles >= self.cap then break end
		local angle = self.opts.direction.angle + rand(-self.opts.direction.spread, self.opts.direction.spread)
		local speed = rand(self.opts.speed.min, self.opts.speed.max)
		self.particles[#self.particles + 1] = {
			x = self.opts.position.x,
			y = self.opts.position.y,
			vx = math.cos(angle) * speed,
			vy = math.sin(angle) * speed,
			age = 0,
			lifetime = rand(self.opts.lifetime.min, self.opts.lifetime.max),
		}
	end
end

-- Advance every particle: velocity by gravity * dt, then position by
-- velocity * dt (semi-implicit Euler), age by dt. Any particle whose age
-- surpasses its lifetime is dropped. Done in-place so no GC churn per frame.
function Emitter:update(dt)
	local gx, gy = self.opts.gravity.x, self.opts.gravity.y
	local alive = 0
	for i = 1, #self.particles do
		local p = self.particles[i]
		p.age = p.age + dt
		if p.age < p.lifetime then
			p.vx = p.vx + gx * dt
			p.vy = p.vy + gy * dt
			p.x = p.x + p.vx * dt
			p.y = p.y + p.vy * dt
			alive = alive + 1
			self.particles[alive] = p
		end
	end
	for i = alive + 1, #self.particles do self.particles[i] = nil end
end

-- True once every particle has expired — lets an owner reap the emitter.
function Emitter:done()
	return #self.particles == 0
end

-- Draw each particle as a centered rectangle whose size and color are
-- linearly interpolated from start to end over the particle's lifetime.
-- Resets the color to opaque white afterwards.
function Emitter:draw()
	local s0 = self.opts.size.start
	local s1 = self.opts.size["end"]
	local c0 = self.opts.colors.start
	local c1 = self.opts.colors["end"]
	for i = 1, #self.particles do
		local p = self.particles[i]
		local t = math.min(p.age / p.lifetime, 1)
		local s = lerp(s0, s1, t)
		love.graphics.setColor(
			lerp(c0[1], c1[1], t), lerp(c0[2], c1[2], t),
			lerp(c0[3], c1[3], t), lerp(c0[4], c1[4], t))
		love.graphics.rectangle("fill", p.x - s / 2, p.y - s / 2, s, s)
	end
	love.graphics.setColor(1, 1, 1, 1)
end

local EMITTER_CAP = 500

function Particles.new_emitter(opts)
	opts = opts or {}
	local emitter = setmetatable({}, Emitter)
	emitter.opts = {
		position = opts.position or {x = 0, y = 0},
		lifetime = opts.lifetime or {min = 0.5, max = 1},
		speed = opts.speed or {min = 50, max = 100},
		direction = opts.direction or {angle = -math.pi / 2, spread = 0.6},
		gravity = opts.gravity or {x = 0, y = 0},
		size = opts.size or {start = 4, ["end"] = 1},
		colors = opts.colors or {start = {1, 1, 1, 1}, ["end"] = {1, 1, 1, 0}},
	}
	emitter.particles = {}
	emitter.cap = EMITTER_CAP
	return emitter
end

return Particles