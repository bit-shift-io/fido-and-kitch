local Pushable = require('src.components.pushable.pushable')
local PushableSupport = require('src.components.pushable.pushable_support')

local PushBox = Class{__includes = Entity}

-- The templates carry an `image` file property for Tiled's own preview; the
-- runtime art is chosen here, matching src/entities/switch.lua, which
-- likewise ignores its object's `image` property.
local IMAGE = 'res/img/pushable_crate_wood.png'

function PushBox:init(object)
	Entity.init(self)
	self.type = 'push_box'
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
		-- component parks it as static once it settles (see
		-- PushableSupport.bodyTypeFor)
		body_type = 'dynamic',
		position = position,
		-- Collider:worldUpdate moves the body; handing it the sprite is how
		-- the art is kept on the box rather than left behind at spawn
		sprite = self.sprite,
	})
	-- its own group, so it collides with terrain, players and every other
	-- prop -- see PushableSupport.nextGroupIndex for why all three depend on it
	self.collider:setGroupIndex(PushableSupport.nextGroupIndex())
	-- Player:queryOnGround()/GroundSupport treat a bare `entity == nil`
	-- collider as terrain; this one belongs to the box, so it needs an
	-- explicit opt-in to be recognised as ground. Without it a player
	-- standing on the box is physically supported but stuck in FallState --
	-- on top of it, yet unable to walk.
	self.collider.walkable = true

	-- lets other props recognise this one: a pushable resting on top blocks
	-- the prop below from being shoved out from under it
	self.isPushable = true

	self.pushable = self:addComponent(Pushable{
		collider = self.collider,
		allowPushWhenStoodOn = object.properties and object.properties.allowPushWhenStoodOn,
	})
end

return PushBox
