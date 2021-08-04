-- https://www.reddit.com/r/love2d/comments/6tjwqm/lua_separate_file_inheritance/

local Entity   = {}
Entity.__index = Entity

function Entity:new(q)
    self.object = q
    print(q)
    print("Entity created")
end

return Entity