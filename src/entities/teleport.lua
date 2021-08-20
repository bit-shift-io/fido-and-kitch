local Teleport = Class{__includes = Entity}

function Teleport:init(object)
	Entity.init(self)
	self.name = object.name
	self.type = 'teleport'
	local position = Vector(object.x+16, object.y-16)
	self.target = map:getObjectById(object.properties.target.id)
	self.sprite = self:addComponent(Sprite{
		image='res/img/teleporter_1.png',
		scale=Vector(0.03, 0.03), 
		frames=1, 
		duration=1.0,
		offset=Vector(500,500),
		loop=false
	})
	self.collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments={0, 0, 32, 32}, 
		body_type='static',
		enter=Func(Teleport.contact, self),
		sensor=true,
		sprite=self.sprite,
		position=position
	})
	self:addComponent(Usable{
		entity=self,
		use=Func(self.use, self)
	})
end

function Teleport:contact(other)

end


function Teleport:use(user)
	if self.target then
		-- center the player in the teleporter
		local user_bounds = user.collider:getBounds()

		local t_x = self.target.x + self.target.width * 0.5
		local t_y = self.target.y

		local x = t_x
		local y = t_y - user_bounds.height * 0.5
		user.collider:setPosition(x, y)
	end
end


return Teleport