-- Usable component
-- an item the player (or entity) can use
-- TODO: take a table of item/count pairs... or an Inventory component!? to allow for complex usage scenarios?

local Usable = Class{}

function Usable:init(props)
	self.type = 'usable'
    self.entity = props.entity
    self.useFunc = props.use
    self.canUseFunc = props.canUse -- optional override for complex canUse situations
    self.requiredItem = props.requiredItem
    self.requiredItemCount = props.requiredItemCount or 1
    self.consumeItems = props.consumeItems or false -- consume on use?
    self.playerAnimationOnUse = props.playerAnimationOnUse
    self.enabled = (props.enabled == nil) and true or props.enabled
end


function Usable:canUse(user)
    if self.canUseFunc then
        return self.canUseFunc(user)
    end
    
    -- TODO: check player has the required items in their inventory
    return self.enabled
end


function Usable:use(user)
    print('usable is being used')
    self.useFunc(user)
end

return Usable