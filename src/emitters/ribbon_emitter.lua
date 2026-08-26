-- src/ribbon_emitter.lua — ribbon/trail particle emitter.
--
-- Returns a module table `RibbonEmitter` exposing `RibbonEmitter.new`:
--
--   local RibbonEmitter = require('src.ribbon_emitter')
--   local e = RibbonEmitter.new({ position = {x, y}, ... })
--   e:emit(n)      -- spawn n ribbon segments (capped)
--   e:update(dt)   -- integrate positions/velocities, expire dead segments
--   e:draw()       -- render each segment as a stretched quad or connected line
--
-- Ribbon segments have a "previous position" allowing them to be drawn as
-- stretched quads between current and previous position, or as connected
-- line strips. Supports multiple visual modes.
--
-- Emitter options (every field optional, defaults below):
--   position:     {x, y}                 center segments spawn at
--   lifetime:     {min, max} seconds     per-segment lifetime (uniform random)
--   speed:        {min, max} px/sec      initial speed (uniform random)
--   direction:    {angle, spread} rad    angle + uniform random offset in +-spread
--   gravity:      {x, y} px/sec^2        constant acceleration applied each frame
--   size:         {start, end} px        ribbon width lerped over lifetime
--   colors:       {start, end} {r,g,b,a} lerped over segment's lifetime
--   image:        Image/Image-path/array optional; renders each segment as a
--                                        textured quad instead of colored rect
--   rotation:     {angle, spread} rad    initial facing; angle + uniform random
--                                        offset in +-spread (textured mode only)
--   spin:         {min, max} rad/sec     per-segment angular velocity (textured)
--   fadeIn:       fraction 0..1          optional; first fadeIn of life eases
--                                        width and alpha up from 0. Default 0.
--   area:         {w, h} px              optional; spawn at random point within
--                                        w x h box centered on position
--   mode:         'stretched'|'connected'|'textured'
--                                        'stretched'   = each segment is a quad
--                                           stretched from prevPos to current pos
--                                        'connected'   = line strip connecting
--                                           all segment positions in order
--                                        'textured'    = textured quad strip
--                                           with UV scrolling along length
--   textureScale: number                 texture V scale (textured mode)
--   textureScroll: number                UV scroll speed (textured mode)
--   maxLength:   number                  max segments in connected strip (0=unlimited)
local RibbonEmitter = {}

local Log = require('src.utils.log')
local AssetManager = require('src.utils.asset_manager')

local function rand(min, max) return min + math.random() * (max - min) end
local function lerp(a, b, t) return a + (b - a) * t end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local Emitter = {}
Emitter.__index = Emitter

function Emitter:emit(n)
	n = n or 1
	self:resolveImages()
	local images = self._images
	local withImages = #images > 0
	for _ = 1, n do
		if #self.segments >= self.cap then break end
		local area = self.opts.area
		local ox = area and area.w > 0 and rand(-area.w / 2, area.w / 2) or 0
		local oy = area and area.h > 0 and rand(-area.h / 2, area.h / 2) or 0
		local angle = self.opts.direction.angle + rand(-self.opts.direction.spread, self.opts.direction.spread)
		local speed = rand(self.opts.speed.min, self.opts.speed.max)
		local segment = {
			x = self.opts.position.x + ox,
			y = self.opts.position.y + oy,
			px = self.opts.position.x + ox,
			py = self.opts.position.y + oy,
			vx = math.cos(angle) * speed,
			vy = math.sin(angle) * speed,
			age = 0,
			lifetime = rand(self.opts.lifetime.min, self.opts.lifetime.max),
			angle = self.opts.rotation.angle + rand(-self.opts.rotation.spread, self.opts.rotation.spread),
			spin = rand(self.opts.spin.min, self.opts.spin.max),
		}
		if withImages then
			segment.image = images[math.random(#images)]
		end
		self.segments[#self.segments + 1] = segment
	end
end

function Emitter:update(dt)
	local gx, gy = self.opts.gravity.x, self.opts.gravity.y
	local alive = 0
	for i = 1, #self.segments do
		local s = self.segments[i]
		s.age = s.age + dt
		if s.age < s.lifetime then
			s.px, s.py = s.x, s.y
			s.vx = s.vx + gx * dt
			s.vy = s.vy + gy * dt
			s.x = s.x + s.vx * dt
			s.y = s.y + s.vy * dt
			alive = alive + 1
			self.segments[alive] = s
		end
	end
	for i = alive + 1, #self.segments do self.segments[i] = nil end

	if self.opts.mode == 'connected' and self.opts.maxLength > 0 then
		while #self.segments > self.opts.maxLength do
			table.remove(self.segments, 1)
		end
	end
end

function Emitter:done()
	return #self.segments == 0
end

function Emitter:loadImage(path)
	if path and path.getWidth then
		return path
	end
	if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(path) == nil then
		Log.warn('Ribbon image not found: ' .. tostring(path))
		return nil
	end
	return AssetManager.getImage(path)
end

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

function Emitter:draw()
	local s0 = self.opts.size.start
	local s1 = self.opts.size["end"]
	local c0 = self.opts.colors.start
	local c1 = self.opts.colors["end"]
	self:resolveImages()
	local debug = conf and conf.draw_particles
	local mode = self.opts.mode or 'stretched'
	local withImages = #self._images > 0

	if debug then
		local area = self.opts.area
		if area and area.w > 0 and area.h > 0 then
			love.graphics.setColor(1, 0.55, 0.2, 0.9)
			love.graphics.rectangle('line', self.opts.position.x - area.w / 2, self.opts.position.y - area.h / 2, area.w, area.h)
		end
	end

	if mode == 'connected' then
		self:drawConnected(s0, s1, c0, c1, withImages)
	elseif mode == 'textured' then
		self:drawTextured(s0, s1, c0, c1)
	else
		self:drawStretched(s0, s1, c0, c1, withImages)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

function Emitter:drawStretched(s0, s1, c0, c1, withImages)
	for i = 1, #self.segments do
		local s = self.segments[i]
		local t = math.min(s.age / s.lifetime, 1)
		local intro = 1
		if self.opts.fadeIn > 0 and t < self.opts.fadeIn then
			intro = (1 - math.cos((t / self.opts.fadeIn) * math.pi)) / 2
		end
		local width = lerp(s0, s1, t) * intro
		local alpha = lerp(c0[4], c1[4], t) * intro
		local r = lerp(c0[1], c1[1], t)
		local g = lerp(c0[2], c1[2], t)
		local b = lerp(c0[3], c1[3], t)

		local dx = s.x - s.px
		local dy = s.y - s.py
		local len = math.sqrt(dx * dx + dy * dy)
		if len < 0.001 then
			if withImages and s.image then
				local imgW, imgH = s.image:getWidth(), s.image:getHeight()
				local scale = imgW > 0 and (width / imgW) or 1
				local rot = (s.angle or 0) + (s.spin or 0) * s.age
				love.graphics.setColor(r, g, b, alpha)
				love.graphics.draw(s.image, s.x, s.y, rot, scale, scale, imgW / 2, imgH / 2)
			else
				love.graphics.setColor(r, g, b, alpha)
				love.graphics.rectangle("fill", s.x - width / 2, s.y - width / 2, width, width)
			end
		else
			local ux, uy = dx / len, dy / len
			local px, py = -uy * width / 2, ux * width / 2
			local x1, y1 = s.px - px, s.py - py
			local x2, y2 = s.px + px, s.py + py
			local x3, y3 = s.x + px, s.y + py
			local x4, y4 = s.x - px, s.y - py

			if withImages and s.image then
				local imgW, imgH = s.image:getWidth(), s.image:getHeight()
				local vScale = self.opts.textureScale or (width / imgH)
				love.graphics.setColor(r, g, b, alpha)
				love.graphics.draw(s.image, s.x, s.y, math.atan2(dy, dx), len / imgW, vScale, 0, imgH / 2)
			else
				love.graphics.setColor(r, g, b, alpha)
				love.graphics.polygon("fill", x1, y1, x2, y2, x3, y3, x4, y4)
			end
		end

		if debug then
			love.graphics.setColor(0, 1, 1, 0.7)
			love.graphics.line(s.px, s.py, s.x, s.y)
			love.graphics.rectangle("line", s.x - width / 2, s.y - width / 2, width, width)
		end
	end
end

function Emitter:drawConnected(s0, s1, c0, c1, withImages)
	if #self.segments < 2 then return end

	local points = {}
	local colors = {}
	for i = 1, #self.segments do
		local s = self.segments[i]
		local t = math.min(s.age / s.lifetime, 1)
		local intro = 1
		if self.opts.fadeIn > 0 and t < self.opts.fadeIn then
			intro = (1 - math.cos((t / self.opts.fadeIn) * math.pi)) / 2
		end
		local width = lerp(s0, s1, t) * intro
		table.insert(points, s.x)
		table.insert(points, s.y)
		table.insert(colors, {
			lerp(c0[1], c1[1], t),
			lerp(c0[2], c1[2], t),
			lerp(c0[3], c1[3], t),
			lerp(c0[4], c1[4], t) * intro
		})
		table.insert(colors, colors[#colors])
	end

	if withImages then
		love.graphics.setColor(1, 1, 1, 1)
		for i = 1, #points - 3, 2 do
			local s = self.segments[math.ceil(i / 2)]
			if s and s.image then
				local x1, y1 = points[i], points[i+1]
				local x2, y2 = points[i+2], points[i+3]
				local dx, dy = x2 - x1, y2 - y1
				local len = math.sqrt(dx * dx + dy * dy)
				if len > 0.001 then
					local imgW, imgH = s.image:getWidth(), s.image:getHeight()
					local vScale = self.opts.textureScale or (s0 / imgH)
					love.graphics.draw(s.image, x1, y1, math.atan2(dy, dx), len / imgW, vScale, 0, imgH / 2)
				end
			end
		end
	else
		love.graphics.setLineWidth(s0)
		for i = 1, #points - 3, 2 do
			local c = colors[i]
			love.graphics.setColor(c[1], c[2], c[3], c[4])
			love.graphics.line(points[i], points[i+1], points[i+2], points[i+3])
		end
	end
end

function Emitter:drawTextured(s0, s1, c0, c1)
	if #self.segments < 2 then return end
	if not self._images or #self._images == 0 then
		self:drawStretched(s0, s1, c0, c1, false)
		return
	end

	local texture = self._images[1]
	local imgW, imgH = texture:getWidth(), texture:getHeight()
	local vScale = self.opts.textureScale or (s0 / imgH)
	local scrollSpeed = self.opts.textureScroll or 0
	local scrollOffset = (love.timer and love.timer.getTime() or 0) * scrollSpeed

	local verts = {}
	for i = 1, #self.segments do
		local s = self.segments[i]
		local t = math.min(s.age / s.lifetime, 1)
		local intro = 1
		if self.opts.fadeIn > 0 and t < self.opts.fadeIn then
			intro = (1 - math.cos((t / self.opts.fadeIn) * math.pi)) / 2
		end
		local width = lerp(s0, s1, t) * intro
		local alpha = lerp(c0[4], c1[4], t) * intro
		local r = lerp(c0[1], c1[1], t)
		local g = lerp(c0[2], c1[2], t)
		local b = lerp(c0[3], c1[3], t)

		table.insert(verts, {s.x, s.y, r, g, b, alpha})
	end

	love.graphics.setColor(1, 1, 1, 1)
	for i = 1, #verts - 1 do
		local v1, v2 = verts[i], verts[i+1]
		local dx, dy = v2[1] - v1[1], v2[2] - v1[2]
		local len = math.sqrt(dx * dx + dy * dy)
		if len > 0.001 then
			local angle = math.atan2(dy, dx)
			local u1 = (scrollOffset + (i - 1) * 0.1) % 1
			local u2 = (scrollOffset + i * 0.1) % 1
			love.graphics.draw(texture, v1[1], v1[2], angle, len / imgW, vScale, 0, imgH / 2)
		end
	end
end

local RIBBON_CAP = 500

function RibbonEmitter.new(opts)
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
		mode = opts.mode or 'stretched',
		textureScale = opts.textureScale,
		textureScroll = opts.textureScroll,
		maxLength = opts.maxLength or 0,
	}
	emitter.segments = {}
	emitter.cap = RIBBON_CAP
	return emitter
end

return RibbonEmitter