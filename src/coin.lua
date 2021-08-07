local Coin = Class{__includes = Entity}

function Coin:init(object)
    Entity.init(self)
    self:addComponent(Sprite{image='assets/images/coins.png', frames=8, duration=1.0, loop=true, position=vector(object.x, object.y)})

    self:addComponent(Collider{collider_type='circle', shape_arguments={325, 325, 20}, postSolve=Coin.contact})
end

function Coin:contact(other)
    print('coin has made contact with something!')
end

return Coin