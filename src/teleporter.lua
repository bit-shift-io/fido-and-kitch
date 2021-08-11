local Teleporter = Class{__includes = Entity}

function Teleporter:init(object)
    Entity.init(self)
    local id = object.id
    local target = object.properties.target
    local sprite = self:addComponent(Sprite{
        image='assets/images/teleporter_1.png',
        scale=vector(0.04, 0.04), 
        frames=1, 
        duration=1.0, 
        loop=false
    })
    local collider = self:addComponent(Collider{
        shape_type='circle', 
        shape_arguments={0, 0, 10}, 
        postSolve=Teleporter.contact, 
        sprite=sprite, 
        position=vector(object.x, object.y)
    })
    collider:setRestitution(0.8) -- any function of shape/body/fixture works
    
end

function Teleporter:contact(other)
    print('Teleporter has made contact with something!')
end

return Teleporter