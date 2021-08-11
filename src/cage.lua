local Cage = Class{__includes = Entity}

function Cage:init(object)
    Entity.init(self)
    local color = object.properties.color
    local sprite = self:addComponent(Sprite{
        image='res/images/cage.png',
        scale=vector(0.1, 0.1), 
        frames=1, 
        duration=1.0, 
        loop=false
    })
    local collider = self:addComponent(Collider{
        shape_type='rectangle', 
        shape_arguments={0, 0, 30, 30}, 
        body_type='static',
        postSolve=Cage.contact, 
        sprite=sprite, 
        position=vector(object.x, object.y)
    })
    collider:setRestitution(0.8) -- any function of shape/body/fixture works
    
end

function Cage:contact(other)
    print('Cage has made contact with something!')
end

return Cage