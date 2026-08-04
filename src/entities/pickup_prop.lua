-- Shared entity archetype for simple pickups (coin, key): a sprite over a
-- sensor circle collider, a Pickup component, and a Sound component with a
-- single 'pickup' sound. coin.lua and key.lua were previously identical
-- copies of this shape, differing only in art, item name and pickup sound.
-- Not an entity type itself -- PickupProp.define(spec) returns the Class
-- each of those files requires and returns directly, so map object type
-- 'coin'/'key' still resolves to src/entities/coin.lua / key.lua exactly
-- as before (see AGENTS.md: "New map entity = new src/entities/<type>.lua").
local PickupProp = {}

-- spec fields:
--   type          entity type string (Entity.init's self.type)
--   pickupRadius  sensor circle radius, defaults to 10 (coin/key's shared value)
--   pickupSound   res/snd path played on pickup
--   itemName(object)      -> Inventory item name granted on pickup
--   sprite(object, shape_arguments) -> Sprite{} constructor props
--   components(object)      -> table of {ComponentName = props} to add
function PickupProp.define(spec)
	local Prop = Class{__includes = Entity}

	function Prop:init(object)
		Entity.init(self, object, spec.type)

		local position = Rect.centreOfMapObject(object)
		local shape_arguments = Rect.shapeArgs(object.width, object.height)

		self.sprite = self:addComponent(Sprite(spec.sprite(object, shape_arguments)))

		self.collider = self:addComponent(Collider{
			shape_type = 'circle',
			shape_arguments = {0, 0, spec.pickupRadius or 10},
			body_type = 'static',
			sprite = self.sprite,
			position = position,
			sensor = true,
			entity = self,
		})

		self:addComponent(Pickup{
			itemName = spec.itemName(object),
			collider = self.collider,
			entity = self,
		})

		self.sound = self:addComponent(Sound{
			sounds = {
				pickup = spec.pickupSound,
			},
		})

		-- When picked up the entity is queueDestroy()'d; the burst must keep
		-- animating after the pickup is gone, so it's handed to the map's
		-- persistent FxManager rather than left on this dying entity.
		if spec.pickupFx then
			self.destroySignal:connect(function()
				if map and map.fx then
					map.fx:burst(spec.pickupFx, {x = position.x, y = position.y})
				end
			end)
		end

		if spec.components then
			local comps = spec.components(object)
			for compName, compProps in pairs(comps) do
				local Comp = require('src.components.' .. compName:lower())
				self:addComponent(Comp(compProps))
			end
		end
	end

	return Prop
end

return PickupProp
