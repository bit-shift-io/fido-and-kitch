local Entity = require('entity')
local newAnimation = require('animation')
local vector = require('vector')

-- can entity provide a wrapper function do do some leg work here?
local Coin   = {}
Coin.__index = Coin
setmetatable(Coin, Entity)

local function newCoin(object)
    a = newAnimation{image='assets/images/coins.png', frames=8, duration=1.0, loop=true, position=vector(object.x, object.y)}

    return setmetatable({
        object = object,
        animation = a
      },
      Coin
    )
end

function Coin:update(dt)
    self.animation:update(dt)
end

function Coin:draw()
    self.animation:draw()
end

return newCoin