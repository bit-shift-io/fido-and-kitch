local Log = require('src.utils.log')

local Bird = Class{__includes = Entity}

function Bird:init(object)
	Entity.init(self, object, 'bird')
	local color = object.properties.color
	local position = Rect.centreOfMapObject(object)
	local shape_arguments = Rect.shapeArgs(32, 32) -- fixed sprite box, not object.width/height
	self.sprite = self:addComponent(Sprite{
        frames='res/img/character_bird_idle.png',
        frameCount=1,
		duration=1.0,
		loop=true,
		position=position,
		shape_arguments=shape_arguments,
        playing=true
	})

    self.pathFollow = self:addComponent(PathFollow{
        sprite=self.sprite,
        path=Path(object),
        finish=utils.bindSelf(self.finish, self),
        speed=80
    })
end

-- freedom! follow the path!
function Bird:trigger()
    Log.debug('bird released, follow the path!')
    self.pathFollow.timeline:play()
end

-- we reached the end of the path
function Bird:finish()
    self.object:exec('finish', self)

    --[[
    local exitDoorObject = map:getObjectById(self.object.properties.target.id)
    local exitDoorEntity = exitDoorObject.entity
    exitDoorEntity:actorReached(self)
    ]]--
end

return Bird
