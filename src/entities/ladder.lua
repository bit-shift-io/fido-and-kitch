local Ladder = Class{__includes = Entity}

function Ladder:init(object)
	Entity.init(self)
	self.name = object.name
	self.type = 'ladder'
	self.isLadder = true
	local position = Vector(object.x + object.width * 0.5, object.y + object.height *0.5)
	self.collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments={0, 0, 1, object.height}, 
		body_type='static',
		sensor=true,
		position=position,
		--enter=utils.forwardFunc(self.enter, self),
		--exit=utils.forwardFunc(self.exit, self),
		entity=self
	})
end

--[[
function Ladder:enter(user)
	user.entity.ladder = self
end

function Ladder:exit(user)
	if user.entity.ladder == self then
		user.entity.ladder = null
	end
end
]]--
return Ladder