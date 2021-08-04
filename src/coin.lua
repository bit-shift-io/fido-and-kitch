local Entity = require('entity')

-- can entity provide a wrapper function do do some leg work here?
local Coin   = {}
Coin.__index = Coin
setmetatable(Coin, Entity)

local function newCoin(object)
    return setmetatable({
        object = object
      },
      Coin
    )
end

function Coin:new(q)
    print("coin")
    Entity:new(q)
end

return newCoin