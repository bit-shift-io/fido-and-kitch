-- A pushable prop in roll mode: it starts moving exactly like a push box (a
-- grounded player walks into it) but keeps rolling under its own momentum
-- after contact ends, until it hits a wall, another prop or a player, or falls
-- into a gap. Harmless on contact -- it stops, it never crushes or shoves
-- (DECISIONS Q9). Everything but the mode is shared with the box via
-- src/entities/pushable_prop.lua.
--
-- Destroy-on-beam-hit needs no code here: src/entities/laser_beam_resolver.lua
-- classifies any `entity.type == 'boulder'` hit (self.type below, set by
-- PushableProp.define via Entity.init) as destroy-and-stop, and
-- src/entities/laser.lua's update loop calls `:queueDestroy()` on it when
-- fully on -- the same generic Entity removal path (src/entity.lua) every
-- other destroyed entity uses, requiring no boulder-specific hook.
local PushableProp = require('src.entities.pushable_prop')
local SpriteProps = require('src.entities.sprite_props')

return PushableProp.define{
	type = 'boulder',
	sprite = function(object, shape_arguments)
		local art = SpriteProps.fromObject(object)
		art.shape_arguments = shape_arguments
		return art
	end,
	mode = 'roll',
}