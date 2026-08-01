-- A pushable prop in roll mode: it starts moving exactly like a push box (a
-- grounded player walks into it) but keeps rolling under its own momentum
-- after contact ends, until it hits a wall, another prop or a player, or falls
-- into a gap. Harmless on contact -- it stops, it never crushes or shoves
-- (DECISIONS Q9). Everything but the mode is shared with the box via
-- src/entities/pushable_prop.lua.
local PushableProp = require('src.entities.pushable_prop')

return PushableProp.define{
	type = 'boulder',
	image = 'res/img/pushable_stone_block.png',
	mode = 'roll',
}
