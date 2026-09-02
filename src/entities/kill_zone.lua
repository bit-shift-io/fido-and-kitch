local KillZone = Class({ __includes = Entity })

function KillZone:init(object)
	Entity.init(self, object, "kill_zone")
	self.isKillZone = true
	self.deathType = object.properties.deathType or "unknown"
	self.rect = Rect(object)
	self.collider = self:addComponent(Collider({
		shape_type = "rectangle",
		shape_arguments = self.rect:colliderShapeArgs(),
		body_type = "static",
		sensor = true,
		position = self.rect:centre(),
	}))
	self.collider.entity = self

	-- no assets yet at res/snd/entity_kill_*.wav; Sound:play warns and skips
	-- until they're added
	self.sound = self:addComponent(Sound({
		sounds = {
			water = "res/snd/entity_kill_water.wav",
			pit = "res/snd/entity_kill_pit.wav",
			spikes = "res/snd/entity_kill_spikes.wav",
			lava = "res/snd/entity_kill_lava.wav",
		},
	}))
end

return KillZone
