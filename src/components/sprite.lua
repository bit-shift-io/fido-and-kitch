local Sprite = Class{}

local function setImageFilter(image, filter)
	if image and image.setFilter then
		image:setFilter(filter or 'linear', filter or 'linear')
	end
end

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

	local filter = props.filter or 'linear'

	if type(frames) == 'table' then
		local newFrames = {}
		for i = 1, frames, 1 do
			newFrames[i] = love.graphics.newImage(frames[i])
			setImageFilter(newFrames[i], filter)
		end
		frames = newFrames
	end

	if type(frames) == 'number' then
		image = love.graphics.newImage(image)
		setImageFilter(image, filter)

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
			setImageFilter(newFrames[i], filter)
		end
		frames = newFrames
	end

	self.frames = cloneArray(frames)
	self.image = image
	self.frameNum = 1
	self.position = props.position or Vector(0, 0)
	self.scale = props.scale or Vector(1, 1)
	self.offset = props.offset or Vector(0, 0)
	self.facing = props.facing or 'right'
	self.playingOnEnter = props.playing ~= false
	self.timeline = Timeline(props)

	if props.shape_arguments then
		-- calculate scale and offset
		local width = props.shape_arguments[3]
		local height = props.shape_arguments[4]

		local f = 1
		if (type(props.frames) == 'number') then
			f = props.frames
		end

		local img
		if (image) then
			img = image
		else
			img = frames[1]
		end
		local img_height = img:getHeight()
		local img_width = img:getWidth() / f

		local x_scale = width / img_width * self.scale.x
		local y_scale = height / img_height * self.scale.y
		self.scale = Vector(x_scale, y_scale)

		local x_offset = img_width * 0.5 + (self.offset.x / x_scale)
		local y_offset = img_height * 0.5 + (self.offset.y / y_scale)
		self.offset = Vector(x_offset, y_offset)
	end

	self:setFacing(self.facing)
	self.draw = draw
end

function Sprite:setFacing(facing)
	if facing ~= 'left' and facing ~= 'right' then
		return
	end

	self.facing = facing
	local x_scale = math.abs(self.scale.x)
	if facing == 'left' then
		x_scale = -x_scale
	end
	self.scale = Vector(x_scale, self.scale.y)
end


function Sprite:enter()
	self.timeline:reset()
	if self.playingOnEnter then
		self.timeline:play()
	end
	self.frameNum = 1
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
	-- incase the user wants to manually fudge frame numbers
	if self.timeline.playing == false then
		return;
	end
	self.timeline:update(dt)
	self.frameNum = self.timeline:getFrameIndex(#self.frames)
end


function Sprite:draw_image_frames()
	local frame = self.frames[self.frameNum]
	love.graphics.draw(frame, self.position.x, self.position.y, 0, self.scale.x, self.scale.y, self.offset.x, self.offset.y)
end

function Sprite:draw_quad_frames()
	local frame = self.frames[self.frameNum]
	assert(frame)
	love.graphics.draw(self.image, frame, self.position.x, self.position.y, 0, self.scale.x, self.scale.y, self.offset.x, self.offset.y)
end

return Sprite