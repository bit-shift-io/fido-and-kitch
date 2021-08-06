local vector = require('hump.vector')
local Class = require('hump.class')

local Animation = Class{}

local function cloneArray(arr)
    local result = {}
    for i=1,#arr do result[i] = arr[i] end
    return result
end

function Animation:init(props)
    local frames = props.frames
    local image = props.image
    local draw = Animation.draw_image_frames

    if type(frames) == 'table' then
        print('table!')
        local newFrames = {}
        for i = 1, frames, 1 do
            newFrames[i] = love.graphics.newImage(frames[i])
        end
        frames = newFrames
    end

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
        local newFrames = {}
        local frameCount = props.frameCount
        for i = 1, frameCount, 1 do
            local str = frames:gsub('${i}', tostring(i))
            newFrames[i] = love.graphics.newImage(str)
        end
        frames = newFrames
    end

    self.frames = cloneArray(frames)
    self.image = image
    self.duration = props.duration
    self.currentTime   = 0
    self.frameNum      = 1
    self.position      = props.position or vector(0, 0)
    self.scale         = props.scale or vector(1, 1)
    self.offset        = props.offset or vector(0, 0)
    self.draw          = draw
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

return Animation