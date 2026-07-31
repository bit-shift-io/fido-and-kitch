-- Placeholder-quad web overlay drawn over a wrapped player (DECISIONS Q8,
-- Q11). Runtime-spawned only -- deliberately outside src/entities/ so it can
-- never be matched by the Tiled object-type loader (see HANDOFF gotcha).
--
-- Plain Lua (no Class/hump dependency, unlike entities) so it stays
-- requireable headless in tests/unit/, mirroring the PushableSupport /
-- enemy_brain testability seam pattern.
local Web = {}
Web.__index = Web

local DEFAULT_FADE_DURATION = 3

function Web.new(props)
	local self = setmetatable({}, Web)
	self.duration = props.duration
	self.fadeDuration = props.fadeDuration or DEFAULT_FADE_DURATION
	self.elapsed = 0
	self.color = props.color or {0.75, 0.75, 0.85, 1}
	return self
end

function Web:update(dt)
	self.elapsed = self.elapsed + dt
end

function Web:remaining()
	return math.max(self.duration - self.elapsed, 0)
end

function Web:isExpired()
	return self.elapsed >= self.duration
end

-- 1 until the fade window starts, fading linearly to 0 at expiry
function Web:alpha()
	local remaining = self:remaining()
	if remaining >= self.fadeDuration then
		return 1
	end
	return remaining / self.fadeDuration
end

function Web:draw(bounds)
	local r, g, b, a = love.graphics.getColor()
	local c = self.color
	love.graphics.setColor(c[1], c[2], c[3], c[4] * self:alpha())
	love.graphics.rectangle('fill', bounds.left, bounds.top, bounds.width, bounds.height)
	love.graphics.setColor(r, g, b, a)
end

setmetatable(Web, {__call = function(_, props) return Web.new(props) end})

return Web