-- src/fx/manager.lua — a map-owned registry of live particle effects.
--
-- Emitters owned by a map entity die with that entity (Entity:update/draw
-- only run while the entity sits in its object layer), but a pickup burst
-- must keep animating after the coin/key it spawned from has been destroyed.
-- FxManager is that persistent home: it owns each in-flight effect, drives
-- its update/draw, and reaps it once its particles have fully expired.
--
-- The map holds exactly one manager (Map:new -> self.fx). Effects are added
-- as preset components (see src/fx/coin_pickup.lua etc.) and reaped when
-- `done()` reports true:
--
--   map.fx:add(CoinPickup{x = px, y = py})       -- add a single effect
--   map.fx:burst(CoinPickup, {x = px, y = py})    -- convenience: new + add
local FxManager = {}
FxManager.__index = FxManager

function FxManager:new()
	return setmetatable({ active = {} }, FxManager)
end

-- Register a live effect so the map keeps updating/drawing it.
function FxManager:add(fx)
	table.insert(self.active, fx)
	return fx
end

-- Build and register a preset component in one step. `preset` may be any
-- callable that returns an effect with update/draw/done (e.g. a hump Class).
function FxManager:burst(preset, opts)
	return self:add((preset)(opts))
end

function FxManager:update(dt)
	local active, alive = self.active, 0
	for i = 1, #active do
		local fx = active[i]
		fx:update(dt)
		if fx:done() then
			if fx.onDone then fx:onDone() end
		else
			alive = alive + 1
			active[alive] = fx
		end
	end
	for i = alive + 1, #active do active[i] = nil end
end

-- Callers draw within whatever world-space transform the map is using
-- (Map:drawEntities pushes/translates/scales before this is invoked).
function FxManager:draw()
	for i = 1, #self.active do
		self.active[i]:draw()
	end
end

return FxManager