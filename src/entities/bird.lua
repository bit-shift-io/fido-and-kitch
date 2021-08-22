local Bird = Class{__includes = Entity}

function Bird:init(object)
	Entity.init(self)
	self.type = 'bird'
	local color = object.properties.color
	local position = Vector(object.x - object.width * 0.5, object.y - object.height * 0.5)
	local shape_arguments = {0, 0, object.width, object.height}
	self.sprite = self:addComponent(Sprite{
        frames='res/img/bird/frame-${i}.png',
        frameCount=2,
		duration=1.0,
		loop=true,
		position=position,
		shape_arguments=shape_arguments,
        playing=true
	})
end

return Bird