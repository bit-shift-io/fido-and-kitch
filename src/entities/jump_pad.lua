local JumpPad = Class{__includes = Entity}

function JumpPad:init(object)
	Entity.init(self)
	self.type = 'jump_pad'
	self.name = object.name
	local position = Vector(object.x + object.width * 0.5, object.y - object.height * 0.5)
	local shape_arguments = {0, 0, object.width, object.height}
	self.sprite = self:addComponent(Sprite{
		image='res/img/spring/Spring - 1.png',
		frames=1,
		duration=1.0,
		loop=true,
		playing=true,
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
		use=utils.func(self.use, self)
	})

	self.pathObject = map:getObjectById(object.properties.path.id)

end

function JumpPad:use(user)

	local function finish(user)
		user:removeComponent(user.pathFollow) -- todo: how to make this self and remove user arg? not working
		print('jump end delete path!')
	end

	-- calc offset
	local user_pos = user.collider:getPositionV()
	local path_start = self.pathObject.polyline[1]
	local offset = user_pos - path_start

	-- add path follow for player
	user.pathFollow = user:addComponent(PathFollow{
		collider=user.collider,
        path=Path(self.pathObject),
        finish=utils.forwardFunc(finish(user), self),
		speed=400,
		offset=offset
    })

	--user.pathFollow.timeline.tween.easing = 'outQuad' -- TODO: need a way to set tween
	user.pathFollow.timeline:play()
end


return JumpPad