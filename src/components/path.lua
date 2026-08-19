-- Path component
-- just a somple path utility class

local Log = require('src.utils.log')

local Path = Class{}

function Path:init(props)
	self.type = 'path'
    if props.polyline == nil then
        Log.warn('Bad object passed to Path! Pass an object that is a polyline')
        return -- error!
    end

    local curveTable = {}
    self.points = {}

    for i,p in ipairs(props.polyline) do
        local v = Vector(p.x, p.y)
        table.insert(self.points, v)

        table.insert(curveTable, p.x)
        table.insert(curveTable, p.y)
    end

    self.curve = love.math.newBezierCurve(curveTable)

    -- bezier curves arent linear in t, so sample the curve into a dense table
    -- and traverse it with piecewise-linear interpolation. This makes travel
    -- along the path a constant world speed (t=0 -> sample[1], t=1 ->
    -- sample[#]) instead of easing into/out of the authored points. The
    -- sampled table also gives us the true arc length for duration math.
    local SAMPLE_COUNT = 100
    self.samples = {}
    self.length = 0
    local prev
    for i = 0, SAMPLE_COUNT do
        local v = Vector(self.curve:evaluate(i / SAMPLE_COUNT))
        table.insert(self.samples, v)
        if prev then
            self.length = self.length + prev:dist(v)
        end
        prev = v
    end
end

function Path:getPositionV(percentage)
    if #self.samples == 0 then
        return Vector(0, 0)
    end

    local t = math.min(1, math.max(0, percentage))
    local scaled = t * (#self.samples - 1)
    local index = math.floor(scaled)
    local f = scaled - index
    local a = self.samples[index + 1]
    local b = self.samples[math.min(index + 2, #self.samples)]
    return a + (b - a) * f
end

function Path:draw()
    if conf.debug == false then
        return
    end

    if self.curve == nil then
        return
    end

    love.graphics.line(self.curve:render())
end

return Path