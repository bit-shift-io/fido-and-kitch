local KillZone = Class{__includes = Entity}

function KillZone:init(object)
	Entity.init(self)
	self.object = object
	self.name = object.name
	self.type = 'kill_zone'
	self.isKillZone = true
	self.deathType = object.properties.deathType or 'unknown'
	self.rect = Rect(object)
	self.collider = self:addComponent(Collider{
		shape_type='rectangle',
		shape_arguments=self.rect:colliderShapeArgs(),
		body_type='static',
		sensor=true,
		position=self.rect:centre(),
		entity=self
	})
end

return KillZone
