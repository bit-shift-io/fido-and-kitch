-- src/fx/base.lua — base class for preset particle effects ("fx components").
--
-- A preset effect owns one Particles emitter plus the config describing it.
-- Subclasses override `config()` to return emitter options, and optionally
-- `emitCount()` for a one-shot burst that spawns at construction. Instances
-- are driven by FxManager (update/draw/done) and can equally be attached to
-- a persistent entity via addComponent(Fx) for continuous effects.
--
--   local CoinPickup = Class{__includes = FxBase}
--   function CoinPickup:config()
--     return { speed = {...}, colors = {...}, ... }
--   end
--   function CoinPickup:emitCount() return 12 end
--
-- props (all optional):
--   x, y        spawn origin (overrides config.position)
--   position    {x, y} spawn origin (alt form)
--   color       {r,g,b,a} overrides both colors.start and colors.end
--   hold        if truthy, build an empty emitter without auto-bursting
local Class = require('lib.hump.class')
local Particles = require('src.emitters.sprite_emitter')

local FxBase = Class{}

function FxBase:init(props)
	props = props or {}
	self.type = 'fx'

	local opts = self:config() or {}
	local pos = props.position or (props.x ~= nil and {x = props.x, y = props.y}) or opts.position
	opts.position = pos or {x = 0, y = 0}
	if props.color then
		opts.colors = {start = props.color, ["end"] = props.color}
	end

	self.emitter = Particles.new_emitter(opts)

	if self.emitCount and not props.hold then
		self.emitter:emit(self:emitCount())
	end
end

-- Emitter options for new_emitter. Override in subclasses.
function FxBase:config()
	return {}
end

-- Emit one more particle now (used by continuous/trail effects per frame).
function FxBase:emit()
	self.emitter:emit(1)
end

function FxBase:update(dt)
	self.emitter:update(dt)
end

function FxBase:draw()
	self.emitter:draw()
end

-- True once every particle has expired (FxManager reaps a done effect).
function FxBase:done()
	return self.emitter:done()
end

return FxBase