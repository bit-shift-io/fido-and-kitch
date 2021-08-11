local Coin = Class{__includes = Entity}

function Coin:init(object)
    Entity.init(self)
    local sprite = self:addComponent(Sprite{
        image='res/images/coins.png', 
        frames=8, 
        duration=1.0, 
        loop=true
    })
    
    local collider = self:addComponent(Collider{
        shape_type='circle', 
        shape_arguments={0, 0, 10}, 
        body_type='static',
        postSolve=Coin.contact, 
        sprite=sprite, 
        position=vector(object.x + 16, object.y - 32)})
    collider:setRestitution(0.8) -- any function of shape/body/fixture works
    
end

function Coin:contact(other)
    print('coin has made contact with something!')
end

return Coin