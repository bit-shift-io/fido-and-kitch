local Cage = Class{__includes = Entity}

function Cage:init(object)
	Entity.init(self)
	self.type = 'cage'
	local color = object.properties.color
	local position = Vector(object.x + object.width * 0.5, object.y - object.height * 0.5)
	local shape_arguments = {0, 0, object.width, object.height}
	self.sprite = self:addComponent(Sprite{
		image='res/img/cage/cage.png',
		frames=2,
		duration=1.0,
		loop=false,
		position=position,
		shape_arguments=shape_arguments,
	})
	self.lockSprite = self:addComponent(Sprite{
		image=string.format('res/img/cage/cage_lock_%s.png', color),
		frames=1,
		duration=1.0,
		loop=false,
		position=position,
		shape_arguments=shape_arguments,
	})
	self.collider = self:addComponent(Collider{
		shape_type='rectangle',
		shape_arguments={0, 0, 32, 32},
		body_type='static',
		sensor=true,
		position=position
	})
	
	self:addComponent(Usable{
		entity=self,
		use=utils.forwardFunc(self.use, self),
		requiredItem=string.format('key_%s', color)
	})

	-- spawn the prisoner!
	if object.properties.path == nil then
		print('Cage has no path property setup for the actor to follow when released')
		return
	end

	local pathObj = map:getObjectById(object.properties.path.id)
	self.actor = map:loadEntity(object.properties.actor or 'bird', object.layer, pathObj)
end

function Cage:use(user)
	print('Cage has been used')
	self:removeComponent(self.lockSprite)
	self.sprite.timeline:play()

	if self.actor == nil then
		return
	end
	self.actor:trigger()
end

return Cage