local Sprite = require('src.components.sprite')

local LivesHud = Class{}

local HEART_SIZE = 48
local HEART_SPACING = 16
local MARGIN = 16

function LivesHud:init(props)
	self.getLives = props.getLives
	self.hearts = {}
end

function LivesHud:draw(startX)
	local lives = self.getLives()
	local baseX = startX or MARGIN

	-- Create heart sprites if needed
	while #self.hearts < lives do
		local i = #self.hearts + 1
		local x = baseX + (i - 1) * (HEART_SIZE + HEART_SPACING)
		local heart = Sprite{
			frames = {'res/img/ui_heart.png'},
			position = Vector(x, MARGIN),
			scale = Vector(HEART_SIZE / 128, HEART_SIZE / 128),
		}
		table.insert(self.hearts, heart)
	end

	-- Draw hearts
	for i = 1, lives do
		local heart = self.hearts[i]
		if heart then
			heart:draw()
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return LivesHud