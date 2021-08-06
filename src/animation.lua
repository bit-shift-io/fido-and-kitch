local vector = require('vector')

local Animation = {}

local Animationmt = { __index = Animation }

local function cloneArray(arr)
    local result = {}
    for i=1,#arr do result[i] = arr[i] end
    return result
end

local function newAnimation(props)
    local frames = props.frames
    local image = props.image
    local draw = Animation.draw_image_frames

    if type(frames) == 'number' then
        image = love.graphics.newImage(image)

        local width = image:getWidth()
        local textureWidth = width / frames

        local newFrames = {}
        for i = 1, frames, 1 do
            local xs = (i - 1) * textureWidth
            local h = image:getHeight()
            newFrames[i] = love.graphics.newQuad(xs, 0, textureWidth, h, image:getDimensions())
        end

        frames = newFrames
        draw = Animation.draw_quad_frames
    end

    if type(frames) == 'string' then
        print('frmes is a string')
    end

    t =  setmetatable({
        frames        = cloneArray(frames),
        image         = image,
        duration      = props.duration,
        currentTime   = 0,
        frameNum      = 1,
        position      = props.position or vector(0, 0),
        scale         = vector(1, 1),
        offset        = vector(0, 0),
        draw          = draw
      },
      Animationmt
    )
    return t
end

function Animation:update(dt)
    self.currentTime = self.currentTime + dt
    while self.currentTime >= self.duration do
        self.currentTime = self.currentTime - self.duration
    end

    self.frameNum = math.floor(self.currentTime / self.duration * #self.frames) + 1
end

function Animation:draw_image_frames()
    local frame = self.frames[self.frameNum]
    love.graphics.draw(frame, self.position.x, self.position.y, 0, self.scale.x, self.scale.y, self.offset.x, self.offset.y)
end

function Animation:draw_quad_frames()
    local frame = self.frames[self.frameNum]
    love.graphics.draw(self.image, frame, self.position.x, self.position.y, 0, self.scale.x, self.scale.y, self.offset.x, self.offset.y)
end

return newAnimation