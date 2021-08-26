-- Path component
-- just a somple path utility class

local Path = Class{}

function Path:init(props)
	self.type = 'path'
    if props.polyline == nil then
        print('Bad object passed to Path! Pass an object that is a polyline')
        return -- error!
    end

    curveTable = {}
    self.points = {}

    for i,p in ipairs(props.polyline) do
        local v = Vector(p.x, p.y)
        table.insert(self.points, v)

        table.insert(curveTable, p.x)
        table.insert(curveTable, p.y)
    end

    self.curve = love.math.newBezierCurve(curveTable)

    -- TODO:
    -- bezier curves arent linear, so we can iterate with some small step to generate a table
    -- also we might want to use control points to reduce the curviness?

    -- compute length of polyline
    self.length = 0
    local pointCount = #self.points
    for i = 2, pointCount, 1 do
        self.length = self.length + self.points[i - 1]:dist(self.points[i])
    end
end

function Path:getPositionV(percentage)
    if self.curve == nil then
        return Vector(0, 0)
    end

    local t = math.min(1, math.max(0, percentage))
    return Vector(self.curve:evaluate(t))
end

function Path:draw()
    if self.curve == nil then
        return
    end

    love.graphics.line(self.curve:render())
end

return Path