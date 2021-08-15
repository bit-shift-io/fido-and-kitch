-- Usable component
-- an item the player (or entity) can use

local Usable = Class{}

function Usable:init(props)
	self.name = 'usable'
    self.requiredItem = props.requiredItem
    self.requiredItemCount = props.requiredItemCount or 1
    self.consumeItems = props.consumeItems or false -- consume on use?
    self.playerAnimationOnUse = props.playerAnimationOnUse
end


function Usable:use()
    self.entity:use()
end


return Usable