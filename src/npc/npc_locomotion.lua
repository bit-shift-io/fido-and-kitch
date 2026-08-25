local Log = require('src.utils.log')

local NpcLocomotion = {}

-- Fallback dt (seconds) for one frame at 60 Hz; used when a non-number
-- dt leaks in (known LÖVE bug where update receives a table on first frame).
local FALLBACK_DT = 1/60

-- Guard dt to always be a number. Logs an error once per state type
-- so the caller can trace the source, then falls back to one frame.
function NpcLocomotion.sanitizeDt(dt, stateName)
	if type(dt) == 'number' then
		return dt
	end
	Log.error(stateName, ":update received non-number dt:", type(dt), dt)
	return FALLBACK_DT
end

-- Apply a single-axis horizontal accel+clamp to an NPC's collider.
-- `dirX` is the desired direction (-1/0/1). Each caller supplies its own
-- fallback defaults for accel/maxSpeed so states that need different
-- magnitudes (patrol=400, wander=200, etc.) don't silently regress.
function NpcLocomotion.stepHorizontal(entity, dirX, dt, accel, maxSpeed)
	accel    = accel    or entity.config.acceleration or 300
	maxSpeed = maxSpeed or entity.config.maxSpeed or 80

	local vx, vy = entity.collider:getLinearVelocity()
	vx = vx + dirX * accel * dt

	if math.abs(vx) > maxSpeed then
		vx = (vx > 0 and 1 or -1) * maxSpeed
	end
	entity.collider:setLinearVelocity(vx, vy)
end

return NpcLocomotion
