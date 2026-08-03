local Log = require('src.utils.log')

local JumpPad = Class{__includes = Entity}

function JumpPad:init(object, map)
	Entity.init(self, object, 'jump_pad')
	local position = Rect.centreOfMapObject(object)
	local shape_arguments = Rect.shapeArgs(object.width, object.height)
	self.sprite = self:addComponent(Sprite{
		image='res/img/entity_jump_pad.png',
		frames=3,
		duration=0.2,
		loop=false,
		bounce=true,
		hold=1.0,
		playing=false,
		shape_arguments=shape_arguments
	})

	self.collider = self:addComponent(Collider{
		shape_type='rectangle',
		shape_arguments=shape_arguments,
		body_type='static',
		sprite=self.sprite,
		position=position,
		sensor=true,
		entity=self
	})

	self:addComponent(Usable{
		entity=self,
		use=utils.bindSelf(self.use, self)
	})

	self.sound = self:addComponent(Sound{
		sounds = {
			launch = 'res/snd/entity_jump_pad_launch.wav'
		}
	})

	self.pathObject = map:getObjectById(object.properties.path.id)

end

function JumpPad:use(user)
	self.sound:play('launch')
	self.sprite.timeline:playForward()

	if user.pathFollow then
		user.pathFollow:finish()
		user:removeComponent(user.pathFollow)
		user.pathFollow = nil
	end

	local function finish()
		if user.pathFollow then
			user:removeComponent(user.pathFollow)
			user.pathFollow = nil
		end
		Log.debug('jump end delete path!')
	end

	-- calc offset
	local user_pos = user.collider:getPositionV()
	local path_start = self.pathObject.polyline[1]
	local offset = user_pos - path_start

	-- add path follow for player
	user.pathFollow = user:addComponent(PathFollow{
		collider=user.collider,
        path=Path(self.pathObject),
        finish=finish,
		speed=400,
		offset=offset
    })

	--user.pathFollow.timeline.tween.easing = 'outQuad' -- TODO: need a way to set tween
	user.pathFollow.timeline:play()
end


return JumpPad
