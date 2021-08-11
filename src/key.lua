local Key = Class{__includes = Entity}

function Key:init(object)
    Entity.init(self)
    local color = object.properties.color
    local sprite = self:addComponent(Sprite{
        image=string.format('assets/images/key_%s.png', color), 
        frames=1, 
        duration=1.0, 
        loop=false
    })
    local collider = self:addComponent(Collider{
        shape_type='circle', 
        shape_arguments={0, 0, 10}, 
        postSolve=Key.contact, 
        sprite=sprite, 
        position=vector(object.x + 16, object.y - 32)
    })
    collider:setRestitution(0.8) -- any function of shape/body/fixture works
    
end

function Key:contact(other)
    print('Key has made contact with something!')
end

return Key