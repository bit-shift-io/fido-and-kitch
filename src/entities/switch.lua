local Switch = Class{__includes = Entity}

function Switch:init(object)
	Entity.init(self)
	self.name = 'switch'
	self.sprite = self:addComponent(Sprite{
		image='res/img/switch.png', 
		scale=Vector(0.3, 0.3), 
		frames=2, 
		duration=1.0, 
		loop=false
	})
	self.collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments={0, 0, 30, 30}, 
		body_type='static',
		enter=Switch.contact,
		sprite=self.sprite,
		position=Vector(object.x, object.y),
		sensor=true,
	})
	self.usable = self:addComponent(Usable{})
	self.states = {'off', 'on'}
	self.state = 0
	self.targetEntity = nil
end


function Switch:contact(other)
	print('Switch has made contact with something!')
end


function Switch:use()
	-- lua is 1 based, but we store 0 based
	local s = self.states[self.state + 1]
	local next_state = (self.state + 1) % 2 -- self.states.length
	print(s)
	self.state = next_state
end

return Switch