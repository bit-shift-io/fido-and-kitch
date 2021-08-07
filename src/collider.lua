-- A physics body component

local Collider = Class{__includes = bf.Collider}

function Collider:init(props)
    self.collider = bf.Collider.new(props.world or world, props.collider_type, unpack(props.shape_arguments))

    if props.postSolve then
        self.collider.postSolve = props.postSolve
    end

    if props.preSolve then
        self.collider.preSolve = props.preSolve
    end

    if props.enter then
        self.collider.enter = props.enter
    end

    if props.exit then
        self.collider.exit = props.exit
    end

    self.collider.draw = Collider.collider_draw

    setmetatable(self.collider, Collider)
end

function Collider:collider_draw(alpha)
    -- TODO: can we just call f.Collider.__draw__ somehow?
    love.graphics.setColor(0.9, 0.9, 0.0)
    local x = self.getX(self)
    local y = self.getY(self)
    local radius = self.getRadius(self)
    love.graphics.circle('fill', x, y, radius)
end

return Collider