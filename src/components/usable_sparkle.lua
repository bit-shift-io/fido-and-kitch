-- src/components/usable_sparkle.lua — gentle ambient sparkles that hover over a
-- usable while a player stands within range, telegraphing "you can use this".
--
-- Auto-attached to every entity that gains a Usable component (see
-- Usable:onAttach), so all usables get the effect for free. Particles spawn at
-- random points inside the entity's tile box, then drift slowly and fade out.
-- Emission stops while no player is in range or the owning Usable is disabled,
-- so a locked door doesn't sparkle but an unlocked one does.
--
-- Rendering uses the codebase's custom Particles engine (src/particles.lua),
-- which constructs and updates headless. The texture is loaded lazily on first
-- draw via AssetManager and falls back to soft rectangles if the file is
-- missing, so this never breaks unit/integration tiers.
--
-- Props (all optional):
--   entity    owning entity (set by Usable:onAttach)
--   texture   a texture path or array of paths to sparkle from; defaults to all
--             four res/img/fx/ glows so particles vary
--   range     px of extra space around the box the player must enter to trigger
--   rate      particles emitted per frame while a player is in range
--   width,height  emission box override (defaults to the entity's collider box)
local Particles = require('src.particles')

local TEXTURES = {
	'res/img/fx/fx_star_glow.png',
	'res/img/fx/fx_star_outline.png',
	'res/img/fx/fx_blob_glow.png',
	'res/img/fx/fx_square_outline.png',
}

local UsableSparkle = Class{}

function UsableSparkle:init(props)
	self.type = 'usable_sparkle'
	self.entity = props.entity
	self.texture = props.texture or TEXTURES
	self.range = props.range or 24
	self.rate = props.rate or 0.125
	self._emitAcc = 0
	self.boxWidth = props.width
	self.boxHeight = props.height

	self.emitter = Particles.new_emitter(self:config())
end

function UsableSparkle:config()
	return {
		position = {x = 0, y = 0},
		lifetime = {min = 1.4, max = 2.8},
		speed = {min = 3, max = 8},
		direction = {angle = math.pi, spread = math.pi},
		gravity = {x = 0, y = -8},
		size = {start = 10, ["end"] = 3},
		colors = {start = {1, 0.98, 0.88, 0.51}, ["end"] = {1, 0.9, 0.6, 0}},
		image = self.texture,
		area = {w = 64, h = 64},
		rotation = {angle = 0, spread = math.pi},
		spin = {min = -1.2, max = 1.2},
		fadeIn = 0.25,
	}
end

-- Is a player overlapping the entity's box grown by self.range? Mirrors how
-- Player:checkForUsables finds usables (world:queryOverlap), just from the
-- usable's side. Guarded so headless tests (no world) are safe.
function UsableSparkle:isPlayerInRange()
	if not (world and world.queryOverlap) then
		return false
	end
	local bounds = self:getBox()
	local query = {
		left = bounds.left - self.range,
		top = bounds.top - self.range,
		right = bounds.right + self.range,
		bottom = bounds.bottom + self.range,
	}
	for _, col in ipairs(world:queryOverlap(query)) do
		local e = col.entity
		if e and e.type == 'player' then
			return true
		end
	end
	return false
end

-- The tile box to emit from / range against: the entity's collider if it has
-- one (the collider's shape is the tile the Tiled object sits on), otherwise a
-- 32x32 box around whatever anchor we can find.
function UsableSparkle:getBox()
	local c = self.entity.collider
	if c and c.getBounds then
		return c:getBounds()
	end
	local cx, cy = self:getAnchor()
	return {
		left = cx - 16, right = cx + 16,
		top = cy - 16, bottom = cy + 16,
		width = 32, height = 32,
	}
end

function UsableSparkle:getAnchor()
	local c = self.entity.collider
	if c and c.getBounds then
		local b = c:getBounds()
		return (b.left + b.right) / 2, (b.top + b.bottom) / 2
	end
	local s = self.entity.sprite
	if s and s.position then
		return s.position.x, s.position.y
	end
	if self.entity.object then
		return Rect.centreOfMapObject(self.entity.object).x, Rect.centreOfMapObject(self.entity.object).y
	end
	return 0, 0
end

-- Re-anchor the emitter on the entity's current box each frame (usables are
-- static, but this keeps it correct for anything that moves).
function UsableSparkle:updatePosition()
	local bounds = self:getBox()
	self.emitter.opts.position.x = (bounds.left + bounds.right) / 2
	self.emitter.opts.position.y = (bounds.top + bounds.bottom) / 2
	self.emitter.opts.area.w = self.boxWidth or 64
	self.emitter.opts.area.h = self.boxHeight or 64
end

function UsableSparkle:update(dt)
	local usable = self.entity:getComponent(Usable)
	local available = not usable or usable.enabled ~= false
	if available and self:isPlayerInRange() then
		self:updatePosition()
		self._emitAcc = self._emitAcc + self.rate
		local n = math.floor(self._emitAcc)
		self._emitAcc = self._emitAcc - n
		self.emitter:emit(n)
	end
	self.emitter:update(dt)
end

function UsableSparkle:draw()
	if not (love and love.graphics) then
		return
	end
	self:updatePosition()
	self.emitter:draw()
end

return UsableSparkle
