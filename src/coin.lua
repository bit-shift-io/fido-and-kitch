local Entity = require('entity')
local Animation = require('animation')
local vector = require('hump.vector')
local Class = require('hump.class')

local Coin = Class{}

function Coin:init(object)
    self.animation = Animation{image='assets/images/coins.png', frames=8, duration=1.0, loop=true, position=vector(object.x, object.y)}
end

function Coin:update(dt)
    self.animation:update(dt)
end

function Coin:draw()
    self.animation:draw()
end

return Coin