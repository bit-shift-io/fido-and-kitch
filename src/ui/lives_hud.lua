local LivesHud = Class{}

local SQUARE_SIZE = 24
local SQUARE_SPACING = 8
local MARGIN = 16

function LivesHud:init(props)
	self.getLives = props.getLives
end

function LivesHud:draw()
	local lives = self.getLives()

	love.graphics.setColor(0.9, 0.15, 0.15, 1)
	for i = 1, lives do
		local x = MARGIN + (i - 1) * (SQUARE_SIZE + SQUARE_SPACING)
		love.graphics.rectangle('fill', x, MARGIN, SQUARE_SIZE, SQUARE_SIZE)
	end
	love.graphics.setColor(1, 1, 1, 1)
end

return LivesHud
