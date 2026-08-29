local Tint = Class{}

function Tint:init(props)
	self.type = 'tint'
	self.color = props.color or {1, 1, 1, 1}
end

function Tint:update(dt)
	-- no-op
end

function Tint:draw()
	love.graphics.setColor(self.color)
end

function Tint:postDraw()
	love.graphics.setColor(1, 1, 1, 1)
end

return Tint