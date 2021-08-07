local Class = require('hump.class')

local Entity = Class{}

function Entity:init()
    self.components = {}
end

function Entity:addComponent(component)
    table.insert(self.components, component)
    return component
end

function Entity:update(dt)
    for _, component in pairs(self.components) do
        if component.update ~= nil then
            component:update(dt)
        end
    end
end

function Entity:draw()
    for _, component in pairs(self.components) do
        if component.draw ~= nil then
            component:draw()
        end
    end
end

return Entity