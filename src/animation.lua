local vector = require('vector')

local Animation = {}

local Animationmt = { __index = Animation }

local function cloneArray(arr)
    local result = {}
    for i=1,#arr do result[i] = arr[i] end
    return result
end

local function newAnimation(frames, duration)
    return setmetatable({
        frames        = cloneArray(frames),
        duration      = duration,
        currentTime   = 0,
        position = vector(0, 0),
        scale = vector(1, 1),
        offset = vector(0, 0),
      },
      Animationmt
    )
end

function Animation:update(dt)
    self.currentTime = self.currentTime + dt
    while self.currentTime >= self.duration do
        self.currentTime = self.currentTime - self.duration
    end
end

function Animation:draw()
    local frameNum = math.floor(self.currentTime / self.duration * #self.frames) + 1
    local frame = self.frames[frameNum]
    love.graphics.draw(frame, self.position.x, self.position.y, 0, self.scale.x, self.scale.y, self.offset.x, self.offset.y)
end

return newAnimation