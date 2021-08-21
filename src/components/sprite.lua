local Sprite = Class{}

local function cloneArray(arr)
	local result = {}
	for i=1,#arr do result[i] = arr[i] end
	return result
end


function Sprite:init(props)
	self.type = 'sprite'
	local frames = props.frames
	local image = props.image
	local draw = Sprite.draw_image_frames

	if type(frames) == 'table' then
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
		draw = Sprite.draw_quad_frames
	end

	if type(frames) == 'string' then
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
	self.currentTime = 0
	self.frameNum = 1
	self.position = props.position or Vector(0, 0)
	self.scale = props.scale or Vector(1, 1)
	self.offset = props.offset or Vector(0, 0)

	if props.shape_arguments then
		-- calculate scale and offset
		local width = props.shape_arguments[3]
		local height = props.shape_arguments[4]
		local img_height = image:getHeight() / #self.frames
		local img_width= image:getWidth() / #self.frames
		local x_scale = width / img_width
		local y_scale = x_scale -- TODO: support y scale? for now assume squares
		self.scale = Vector(x_scale, y_scale)
		self.offset = Vector(width, height)
		print('calculate scale offset')
	end

	self.playing = false
	if props.playing ~= nil then
		self.playing = props.playing
	end

	self.draw = draw
end


function Sprite:setFrameNum(frameNum)
	self.frameNum = frameNum
end


function Sprite:setPositionV(pos)
	self.position = pos
end


function Sprite:getPositionV()
	return self.position
end


function Sprite:update(dt)
	if self.playing == false then
		return
	end

	self.currentTime = self.currentTime + dt
	while self.currentTime >= self.duration do
		self.currentTime = self.currentTime - self.duration
	end

	self.frameNum = math.floor(self.currentTime / self.duration * #self.frames) + 1
end


function Sprite:draw_image_frames()
	local frame = self.frames[self.frameNum]
	love.graphics.draw(frame, self.position.x, self.position.y, 0, self.scale.x, self.scale.y, self.offset.x, self.offset.y)
end

function Sprite:draw_quad_frames()
	local frame = self.frames[self.frameNum]
	love.graphics.draw(self.image, frame, self.position.x, self.position.y, 0, self.scale.x, self.scale.y, self.offset.x, self.offset.y)
end

return Sprite