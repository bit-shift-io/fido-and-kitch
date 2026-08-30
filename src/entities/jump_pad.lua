local JumpPadStreak = require('src.fx.jump_pad_streak')
local SpriteProps = require('src.entities.sprite_props')

local JumpPad = Class{__includes = Entity}

function JumpPad:init(object, map)
	Entity.init(self, object, 'jump_pad')
	local position = Rect.centreOfMapObject(object)
	local shape_arguments = Rect.shapeArgs(object.width, object.height)
	local spriteProps = SpriteProps.fromObject(object)
	spriteProps.bounce = true
	spriteProps.hold = 1.0
	spriteProps.playing = false
	spriteProps.shape_arguments = shape_arguments
	self.sprite = self:addComponent(Sprite(spriteProps))

	self.collider = self:addComponent(Collider{
		shape_type='rectangle',
		shape_arguments=shape_arguments,
		body_type='static',
		sprite=self.sprite,
		position=position,
		sensor=true,
		entity=self
	})

	self.usable = self:addComponent(Usable{
		entity=self,
		use=utils.bindSelf(self.use, self)
	})
	self:addComponent(Switchable{
		entity=self,
		onStateChange=function(enabled)
			self.usable.enabled = enabled
		end
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

	local center = self.collider:getPositionV()
	local path_start = self.pathObject.polyline[1]
	local angle = math.atan2(path_start.y - center.y, path_start.x - center.x)
	if self.map and self.map.fx then
		self.map.fx:burst(JumpPadStreak, {x = center.x, y = center.y, angle = angle, count = 16})
	end

	if user.pathFollow then
		user.pathFollow:finish()
		user:removeComponent(user.pathFollow)
		user.pathFollow = nil
	end

	-- calc offset
	local user_pos = user.collider:getPositionV()
	local path_start = self.pathObject.polyline[1]
	local offset = user_pos - path_start

	-- add path follow for player
	local pathFollow = user:addComponent(PathFollow{
		collider=user.collider,
        path=Path(self.pathObject),
        speed=120,
		offset=offset,
		easing='linear',
		ignoreCollider=self.collider
    })

	local duration = pathFollow.path.length / 120
	user.fsm:setState('JumpTravelState', {
		pathFollow = pathFollow,
		duration = duration,
		camera = self.map and self.map.camera
	})
end


return JumpPad
