-- https://www.reddit.com/r/love2d/comments/6tjwqm/lua_separate_file_inheritance/

local Entity   = {}
Entity.__index = Entity

function Entity:update(dt)
    print("update")
end

function Entity:draw()
    print('draw')
end

return Entity