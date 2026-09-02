-- Pickup component
-- if a prop has this component, then the player knows it can be picked up
local Pickup = Class{}

function Pickup:init(props)
	self.type = 'pickup'
    self.entity = props.entity
    self.itemName = props.itemName
	self.itemCount = props.itemCount or 1

    -- set up the physics contact callback
    self.collider = props.collider
    self.collider.enter = Pickup.contact
    self.collider.pickup = self
end

function Pickup:contact(other)
    -- self = the collider, so we had to set another var on the collider called 'pickup'
    -- which refers to the actual pickup 'self' which we pass to the entity that is picking up this item
	local entity = other.entity
	-- plain terrain (e.g. the ground a falling pickup lands on) has no
	-- owning entity at all -- only something that IS an entity can pick
	-- anything up
	if entity and entity.pickup ~= nil then
		entity:pickup(self.pickup)
	end
end

return Pickup