-- sprite_emitter.lua — a tiny, dependency-free particle emitter engine.
--
-- Returns a single module table `Particles` exposing `Particles.new_emitter`:
--
--   local SpriteEmitter = require('src.emitters.sprite_emitter')
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
--   colors:    {start, end} {r,g,b,a}  lerped over the particle's lifetime
--   image:     Image/Image-path, or array of those   optional; renders each
--                                     particle as one image scaled to `size`
--                                     instead of a rect. String paths load
--                                     lazily on first draw; with an array each
--                                     particle is assigned one texture at spawn.
--                                     Missing files fall back to rects.
--   rotation:  {angle, spread} rad     initial facing; angle + uniform random
--                                     offset in +-spread (images only)
--   spin:      {min, max} rad/sec      per-particle angular velocity applied on
--                                     top of the initial rotation (images only)
--   fadeIn:    fraction 0..1           optional; the first fadeIn of each
--                                     particle's life eases size and alpha up
--                                     from 0 (a gentle scale/fade-in) before the
--                                     normal size/fade-out takes over. Default 0.
--   area:      {w, h} px              optional; spawn particles at a random
--                                     point within a w x h box centered on
--                                     `position` (defaults to spawning at the
--                                     exact position)
local Particles = {}

local Log = require('src.utils.log')
local AssetManager = require('src.utils.asset_manager')

local function rand(min, max) return min + math.random() * (max - min) end
local function lerp(a, b, t) return a + (b - a) * t end

local Emitter = {}
Emitter.__index = Emitter

-- Spawn n particles at the emitter's current position, each with its own
-- randomized lifetime, speed and heading. Never grows past VARIABLE.cap. When
-- multiple textures are configured, each particle is permanently assigned one
-- at spawn (picked at random) so the variety comes from a mix of textures.
function Emitter:emit(n)
	n = n or 1
	self:resolveImages()
	local images = self._images
	local withImages = #images > 0
	for _ = 1, n do
		if #self.particles >= self.cap then break end
		local area = self.opts.area
		local ox = area and area.w > 0 and rand(-area.w / 2, area.w / 2) or 0
		local oy = area and area.h > 0 and rand(-area.h / 2, area.h / 2) or 0
		local angle = self.opts.direction.angle + rand(-self.opts.direction.spread, self.opts.direction.spread)
		local speed = rand(self.opts.speed.min, self.opts.speed.max)
		local particle = {
			x = self.opts.position.x + ox,
			y = self.opts.position.y + oy,
			vx = math.cos(angle) * speed,
			vy = math.sin(angle) * speed,
			age = 0,
			lifetime = rand(self.opts.lifetime.min, self.opts.lifetime.max),
			angle = self.opts.rotation.angle + rand(-self.opts.rotation.spread, self.opts.rotation.spread),
			spin = rand(self.opts.spin.min, self.opts.spin.max),
		}
		if withImages then
			particle.image = images[math.random(#images)]
		end
		self.particles[#self.particles + 1] = particle
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

-- Load one image, translating a path string into a cached Image (or nil).
function Emitter:loadImage(path)
	if path and path.getWidth then
		return path
	end
	if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(path) == nil then
		Log.warn('Particle image not found: ' .. tostring(path))
		return nil
	end
	return AssetManager.getImage(path)
end

-- Resolve opts.image (path string, Image, or an array mixing both) into a
-- flat list of loaded Images, once. Missing entries are dropped; if none
-- resolve, particles degrade to rectangles.
function Emitter:resolveImages()
	if self._images ~= nil then return end
	self._images = {}
	local src = self.opts.image
	if not src then return end
	local list
	if type(src) == 'table' and not src.getWidth then
		list = src
	else
		list = { src }
	end
	for _, entry in ipairs(list) do
		local img = self:loadImage(entry)
		if img then self._images[#self._images + 1] = img end
	end
end

-- Draw each particle as a centered rectangle whose size and color are
-- linearly interpolated from start to end over the particle's lifetime.
-- Resets the color to opaque white afterwards.
function Emitter:draw()
	local s0 = self.opts.size.start
	local s1 = self.opts.size["end"]
	local c0 = self.opts.colors.start
	local c1 = self.opts.colors["end"]
	self:resolveImages()
	local debug = conf and conf.draw_particles
	if debug then
		-- emitter emit-box outline (F2): shows the box particles spawn into
		local area = self.opts.area
		if area and area.w > 0 and area.h > 0 then
			love.graphics.setColor(1, 0.55, 0.2, 0.9)
			love.graphics.rectangle('line', self.opts.position.x - area.w / 2, self.opts.position.y - area.h / 2, area.w, area.h)
		end
	end
	for i = 1, #self.particles do
		local p = self.particles[i]
		local t = math.min(p.age / p.lifetime, 1)
		local intro = 1
		if self.opts.fadeIn > 0 and t < self.opts.fadeIn then
			intro = (1 - math.cos((t / self.opts.fadeIn) * math.pi)) / 2
		end
		local s = lerp(s0, s1, t) * intro
		love.graphics.setColor(
			lerp(c0[1], c1[1], t), lerp(c0[2], c1[2], t),
			lerp(c0[3], c1[3], t), lerp(c0[4], c1[4], t) * intro)
		local img = p.image
		if img then
			local imgW, imgH = img:getWidth(), img:getHeight()
			local scale = imgW > 0 and (s / imgW) or 1
			local rot = (p.angle or 0) + (p.spin or 0) * p.age
			love.graphics.draw(img, p.x, p.y, rot, scale, scale, imgW / 2, imgH / 2)
		else
			love.graphics.rectangle("fill", p.x - s / 2, p.y - s / 2, s, s)
		end
		if debug then
			love.graphics.setColor(0, 1, 1, 0.7)
			love.graphics.rectangle("line", p.x - s / 2, p.y - s / 2, s, s)
		end
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
		image = opts.image,
		rotation = opts.rotation or {angle = 0, spread = 0},
		spin = opts.spin or {min = 0, max = 0},
		fadeIn = opts.fadeIn or 0,
		area = opts.area or {w = 0, h = 0},
	}
	emitter.particles = {}
	emitter.cap = EMITTER_CAP
	return emitter
end

return Particles