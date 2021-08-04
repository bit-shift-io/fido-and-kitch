local Entity = require('entity')
local newAnimation = require('animation')

-- can entity provide a wrapper function do do some leg work here?
local Coin   = {}
Coin.__index = Coin
setmetatable(Coin, Entity)

local function newCoin(object)
    frames = {
        love.graphics.newImage('assets/images/cat/Idle (1).png'),
        love.graphics.newImage('assets/images/cat/Idle (2).png'),
        love.graphics.newImage('assets/images/cat/Idle (3).png')
    }
    a = newAnimation(frames, 1.0)
    a.sx = 0.1
    a.sy = 0.1
    a.x = object.x
    a.y = object.y

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