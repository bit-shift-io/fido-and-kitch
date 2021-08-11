local Switch = Class{__includes = Entity}

function Switch:init(object)
    Entity.init(self)
    local sprite = self:addComponent(Sprite{
        image='assets/images/switch.png', 
        scale=vector(0.3, 0.3), 
        frames=2, 
        duration=1.0, 
        loop=false
    })
    local collider = self:addComponent(Collider{
        shape_type='rectangle', 
        shape_arguments={0, 0, 30, 30}, 
        postSolve=Switch.contact, 
        sprite=sprite, 
        position=vector(object.x, object.y)
    })
    collider:setRestitution(0.8) -- any function of shape/body/fixture works
    
end

function Switch:contact(other)
    print('Switch has made contact with something!')
end

return Switch