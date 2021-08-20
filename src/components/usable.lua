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
end


function Usable:canUse(user)
    if self.canUseFunc then
        return self.canUseFunc:call(user)
    end
    
    -- TODO: check player has the required items in their inventory
    return true
end


function Usable:use(user)
    print('usable is beinng used')
    self.useFunc:call(user)
end

return Usable