local Bird = Class{__includes = Entity}

function Bird:init(object)
	Entity.init(self)
	self.type = 'bird'
    self.object = object
	local color = object.properties.color
	local position = Vector(object.x - object.width * 0.5, object.y - object.height * 0.5)
	local shape_arguments = {0, 0, 32, 32} -- object.width, object.height}
	self.sprite = self:addComponent(Sprite{
        frames='res/img/bird/frame-${i}.png',
        frameCount=2,
		duration=1.0,
		loop=true,
		position=position,
		shape_arguments=shape_arguments,
        playing=true
	})

    self.pathFollow = self:addComponent(PathFollow{
        sprite=self.sprite,
        path=Path(object),
        finish=Func(self.finish, self),
    })
end

-- freedom! follow the path!
function Bird:trigger()
    print('bird released, follow the path!')
    self.pathFollow:setPlaying(true)
end

-- we reached the end of the path
function Bird:finish()
    local exitDoorObject = map:getObjectById(self.object.properties.target.id)
    local exitDoorEntity = exitDoorObject.entity
    exitDoorEntity:actorReached(self)
end

return Bird