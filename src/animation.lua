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
        x = 0,
        y = 0,
        sx = 1, -- scale
        sy = 1,
        ox = 0, -- offset
        oy = 0
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
    love.graphics.draw(frame, self.x, self.y, 0, self.sx, self.sy, self.ox, self.oy)
end

return newAnimation