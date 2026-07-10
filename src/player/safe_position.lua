-- Pure tracker for a player's "last safe position": the most recent spot
-- where they were continuously grounded for a stability threshold, so a
-- respawn never lands on the crumbling pixel-edge of a ledge.
local SafePosition = {}
SafePosition.__index = SafePosition

local DEFAULT_THRESHOLD = 0.5

function SafePosition.new(x, y, threshold)
	return setmetatable({
		x = x,
		y = y,
		threshold = threshold or DEFAULT_THRESHOLD,
		groundedTime = 0,
	}, SafePosition)
end

function SafePosition:update(dt, grounded, x, y)
	if not grounded then
		self.groundedTime = 0
		return
	end

	self.groundedTime = self.groundedTime + dt
	if self.groundedTime >= self.threshold then
		self.x = x
		self.y = y
	end
end

return SafePosition
