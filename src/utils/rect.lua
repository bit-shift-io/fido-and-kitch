-- Rectangle class
local Rect = Class{}

function Rect:init(props)
    self.x = props.x
    self.y = props.y
    self.width = props.width
    self.height = props.height
end

function Rect:centre()
    return Vector(self.x + self.width * 0.5, self.y + self.height * 0.5)
end

function Rect:colliderShapeArgs()
    return {0, 0, self.width, self.height}
end

return Rect