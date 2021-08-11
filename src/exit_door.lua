local ExitDoor = Class{__includes = Entity}

function ExitDoor:init(object)
    Entity.init(self)
    local sprite = self:addComponent(Sprite{
        image='assets/images/door.png',
        scale=vector(0.8, 0.8), 
        frames=5, 
        duration=1.0, 
        loop=false
    })
    local collider = self:addComponent(Collider{
        shape_type='rectangle', 
        shape_arguments={0, 0, 50, 50}, 
        body_type='static',
        postSolve=ExitDoor.contact, 
        sprite=sprite, 
        position=vector(object.x, object.y)
    })
    collider:setRestitution(0.8) -- any function of shape/body/fixture works
    
end

function ExitDoor:contact(other)
    print('ExitDoor has made contact with something!')
end

return ExitDoor