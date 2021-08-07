local Entity = require('entity')
local Sprite = require('sprite')
local vector = require('hump.vector')
local Class = require('hump.class')

local Coin = Class{__includes = Entity}

function Coin:init(object)
    Entity.init(self)
    self:addComponent(Sprite{image='assets/images/coins.png', frames=8, duration=1.0, loop=true, position=vector(object.x, object.y)})
end

return Coin