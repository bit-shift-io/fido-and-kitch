-- A pushable prop in roll mode: it starts moving exactly like a push box (a
-- grounded player walks into it) but keeps rolling under its own momentum
-- after contact ends, until it hits a wall, another prop or a player, or falls
-- into a gap. Harmless on contact -- it stops, it never crushes or shoves
-- (DECISIONS Q9). Everything but the mode is shared with the box via the
-- Pushable component.
local Pushable = require('src.components.pushable.pushable')
local PushableSupport = require('src.components.pushable.pushable_support')

local Boulder = Class{__includes = Entity}

-- The templates carry an `image` file property for Tiled's own preview; the
-- runtime art is chosen here, matching src/entities/switch.lua.
local IMAGE = 'res/img/pushable_stone_block.png'

function Boulder:init(object)
	Entity.init(self)
	self.type = 'boulder'
	self.object = object
	self.name = object.name

	local centreX, centreY = PushableSupport.spawnCentre(object)
	local position = Vector(centreX, centreY)
	local shape_arguments = {0, 0, object.width, object.height}

	self.sprite = self:addComponent(Sprite{
		image = IMAGE,
		frames = 1,
		duration = 1.0,
		loop = false,
		position = position,
		shape_arguments = shape_arguments,
	})

	self.collider = self:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = shape_arguments,
		-- starts dynamic so it falls to the ground on load; the Pushable
		-- component parks it as static once it settles
		body_type = 'dynamic',
		position = position,
		sprite = self.sprite,
	})
	self.collider:setGroupIndex(PushableSupport.nextGroupIndex())
	self.collider.walkable = true

	-- so other props recognise it: one resting on top blocks the prop below
	self.isPushable = true

	self.pushable = self:addComponent(Pushable{
		collider = self.collider,
		mode = 'roll',
		allowPushWhenStoodOn = object.properties and object.properties.allowPushWhenStoodOn,
	})
end

return Boulder
