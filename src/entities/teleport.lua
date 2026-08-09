local Teleport = Class{__includes = Entity}

function Teleport:init(object, map)
	Entity.init(self, object, 'teleport')
	local position = Rect.centreOfMapObject(object)
	local shape_arguments = Rect.shapeArgs(object.width, object.height)
	self.target = object.properties.target and map:getObjectById(object.properties.target.id)

	-- visual footprint only -- the collider below stays the map's 1x1 tile;
	-- the bigger sprite is purely decorative art so the art can extend
	-- beyond the tile the teleporter sits on. The box is 2x the tile,
	-- centred on the tile centre, which would hang the art 16px past the
	-- tile's bottom; lift the sprite by half the extra height so it sits
	-- back on the ground. The sprite's position is set explicitly rather
	-- than synced from the collider (which would clobber this offset).
	local sprite_shape = Rect.shapeArgs(object.width * 2, object.height * 2)
	local sprite_position = position - Vector(0, object.height * 0.5)
	self.sprite = self:addComponent(Sprite{
		image='res/img/entity_teleporter.png',
		frames=1,
		duration=1.0,
		shape_arguments=sprite_shape,
		position=sprite_position,
		loop=false
	})
	self.collider = self:addComponent(Collider{
		shape_type='rectangle',
		shape_arguments=shape_arguments,
		body_type='static',
		enter=utils.bindSelf(Teleport.contact, self),
		sensor=true,
		position=position
	})
	-- Defaults to enabled, matching every existing map (none author this
	-- property) -- an authored `enabled=false` lets a level start this
	-- teleporter blocked until a switch/pressure-plate targeting it turns
	-- it on, rather than always starting usable.
	local startEnabled = (object.properties.enabled == nil) and true or object.properties.enabled
	self.usable = self:addComponent(Usable{
		entity=self,
		use=utils.bindSelf(self.use, self),
		enabled=startEnabled
	})
	self:addComponent(Switchable{
		entity=self,
		enabled=startEnabled,
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
