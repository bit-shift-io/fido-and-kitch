-- A pushable prop in roll mode: it starts moving exactly like a push box (a
-- grounded player walks into it) but keeps rolling under its own momentum
-- after contact ends, until it hits a wall, another prop or a player, or falls
-- into a gap. Harmless on contact -- it stops, it never crushes or shoves
-- (DECISIONS Q9). Everything but the mode is shared with the box via
-- src/entities/pushable_prop.lua.
--
-- Destroy-on-beam-hit is extended, not duplicated: src/entities/
-- laser_beam_resolver.lua's isDestructible(entity) classifies any
-- `entity.type == 'boulder'` hit (self.type below, set by PushableProp.define
-- via Entity.init) as destroy-and-stop, and src/entities/laser.lua's
-- already-generic destroy loop calls destroyedEntity.beamContactDelay:
-- markContact() instead of queueDestroy()-ing it directly. So a boulder must
-- carry a BeamContactDelay component by the time the laser's destroy loop
-- runs, attached below via the init wrapper after PushableProp.define returns.
local PushableProp = require('src.entities.pushable_prop')
local SpriteProps = require('src.entities.sprite_props')
local BeamContactDelay = require('src.components.beam_contact_delay')

-- Delay between a fully-on beam first touching this boulder and it actually
-- destroying, driven by the BeamContactDelay component attached in init below.
local DESTROY_DELAY = 0.5

local Boulder = PushableProp.define{
	type = 'boulder',
	sprite = function(object, shape_arguments)
		local art = SpriteProps.fromObject(object)
		art.shape_arguments = shape_arguments
		return art
	end,
	mode = 'roll',
}

local originalInit = Boulder.init
function Boulder:init(object)
	originalInit(self, object)
	self.beamContactDelay = self:addComponent(BeamContactDelay{delay = DESTROY_DELAY})
end

return Boulder