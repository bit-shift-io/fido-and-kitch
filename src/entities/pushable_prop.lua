-- Shared entity archetype for pushable props (push_box, boulder): a sprite
-- over a dynamic rectangle collider, wired to the Pushable component. The
-- two prop types were previously identical copies of this shape, differing
-- only in art and Pushable's `mode` ('box' default vs 'roll' for boulder --
-- see DECISIONS Q9). Not an entity type itself -- PushableProp.define(spec)
-- returns the Class each of those files requires and returns directly, so
-- map object type 'push_box'/'boulder' still resolves to
-- src/entities/push_box.lua / boulder.lua exactly as before (see AGENTS.md:
-- "New map entity = new src/entities/<type>.lua").
local Pushable = require("src.components.pushable.pushable")
local PushableSupport = require("src.components.pushable.pushable_support")

local PushableProp = {}

-- Draws in front of teleport.lua's sprite (renderOrder 0) by default, so a
-- pushable resting on/near a teleporter reads as a solid object sitting on
-- top of it rather than tucked behind its art. Overridable per-instance via
-- the object's own `renderOrder` template property, same as any other
-- Sprite prop.
PushableProp.RENDER_ORDER = 10

-- spec fields:
--   type   entity type string (Entity.init's self.type)
--   sprite(object, shape_arguments) -> Sprite{} constructor props (art now
--          comes from the entity's template via the SpriteProps helper, so
--          the map object's own `image` property is no longer ignored)
--   mode   passed straight through to Pushable{} (nil = box, 'roll' = boulder)
function PushableProp.define(spec)
	local Prop = Class({ __includes = Entity })

	function Prop:init(object)
		Entity.init(self, object, spec.type)

		local centreX, centreY = PushableSupport.spawnCentre(object)
		local position = Vector(centreX, centreY)
		local shape_arguments = Rect.shapeArgs(object.width, object.height)

		local spriteProps = spec.sprite(object, shape_arguments)
		spriteProps.renderOrder = spriteProps.renderOrder or PushableProp.RENDER_ORDER
		self.sprite = self:addComponent(Sprite(spriteProps))

		self.collider = self:addComponent(Collider({
			shape_type = "rectangle",
			shape_arguments = shape_arguments,
			-- starts dynamic so it falls to the ground on load; the Pushable
			-- component parks it as static once it settles (see
			-- PushableSupport.bodyTypeFor)
			body_type = "dynamic",
			position = position,
			-- Collider:worldUpdate moves the body; handing it the sprite is how
			-- the art is kept on the prop rather than left behind at spawn
			sprite = self.sprite,
		}))
		-- its own group, so it collides with terrain, players and every other
		-- prop -- see PushableSupport.nextGroupIndex for why all three depend on it
		self.collider:setGroupIndex(PushableSupport.nextGroupIndex())
		-- Player:queryOnGround()/GroundSupport treat a bare `entity == nil`
		-- collider as terrain; this one belongs to the prop, so it needs an
		-- explicit opt-in to be recognised as ground. Without it a player
		-- standing on it is physically supported but stuck in FallState --
		-- on top of it, yet unable to walk.
		self.collider.walkable = true

		-- lets other props recognise this one: a pushable resting on top blocks
		-- the prop below from being shoved out from under it
		self.isPushable = true

		self.pushable = self:addComponent(Pushable({
			collider = self.collider,
			mode = spec.mode,
			allowPushWhenStoodOn = object.properties and object.properties.allowPushWhenStoodOn,
		}))
	end

	return Prop
end

return PushableProp
