local Teleport = Class{__includes = Entity}

function Teleport:init(object, map)
	Entity.init(self, object, 'teleport')
	local position = Rect.centreOfMapObject(object)
	local shape_arguments = Rect.shapeArgs(object.width, object.height)
	self.target = object.properties.target and map:getObjectById(object.properties.target.id)

	-- visual footprint only -- the collider below stays the map's 1x1 tile;
	-- the bigger sprite is purely decorative bleed so the art can extend
	-- beyond the tile the teleporter sits on
	local sprite_shape_arguments = Rect.shapeArgs(object.width * 2, object.height * 2)
	self.sprite = self:addComponent(Sprite{
		image='res/img/entity_teleporter.png',
		frames=1,
		duration=1.0,
		shape_arguments=sprite_shape_arguments,
		loop=false
	})
	self.collider = self:addComponent(Collider{
		shape_type='rectangle',
		shape_arguments=shape_arguments,
		body_type='static',
		enter=utils.bindSelf(Teleport.contact, self),
		sensor=true,
		sprite=self.sprite,
		position=position
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

	-- only one teleport sound asset exists (res/snd/); both directions share it
	self.sound = self:addComponent(Sound{
		sounds = {
			['in'] = 'res/snd/entity_teleport.wav',
			out = 'res/snd/entity_teleport.wav',
		}
	})
end

function Teleport:contact(other)

end


function Teleport:use(user)
	if self.target then
		self.sound:play('in')

		-- center the player in the teleporter
		local user_bounds = user.collider:getBounds()

		local t_x = self.target.x + self.target.width * 0.5
		local t_y = self.target.y

		local x = t_x
		local y = t_y - user_bounds.height * 0.5
		user.collider:setPosition(x, y)

		if self.target.entity then
			self.target.entity.sound:play('out')
		end
	end
end


return Teleport
