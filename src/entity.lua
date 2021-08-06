local Class = require('hump.class')

local Entity = Class{}

-- TODO:
-- a list of components - map?
-- an update list and a draw list incase some components have one without the other, to eliminate if statements
-- then child classes shouldnt need to have update or draw methods except in special cases

function Entity:update(dt)
    print("entity.update")
end

function Entity:draw()
    print('entity.draw')
end

return Entity