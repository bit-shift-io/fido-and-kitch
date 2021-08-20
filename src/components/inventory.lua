-- Inventory component
-- store what items the player (or an entity) has

local Inventory = Class{}

function Inventory:init(props)
	self.type = 'inventory'
    self.items = {}
end

function Inventory:addItems(itemName, itemCount)
    if self.items[itemName] == nil then
        self.items[itemName] = 0
    end

    self.items[itemName] = self.items[itemName] + itemCount
end

function Inventory:hasItems(itemName, itemCount)
    if self.items[itemName] == nil then
        return false
    end

    return self.items[itemName] >= itemCount
end

function Inventory:removeItems(itemName, itemCount)
    if self.items[itemName] == nil then
        return
    end

    self.items[itemName] = math.max(0, self.items[itemName] - itemCount)
end

return Inventory