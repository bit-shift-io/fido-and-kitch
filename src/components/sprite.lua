local AssetManager = require("src.utils.asset_manager")

local Sprite = Class({})

local function setImageFilter(image, filter)
	if image and image.setFilter then
		image:setFilter(filter or "linear", filter or "linear")
	end
end

local function cloneArray(arr)
	local result = {}
	for i = 1, #arr do
		result[i] = arr[i]
	end
	return result
end

-- Sprite{} accepts three unrelated shapes for `frames`/`image`, dispatched
-- on type below -- effectively three constructors sharing one prop table.
-- Kept as one public Sprite{props} call (used ~identically at every call
-- site) rather than three separate constructor functions, but decomposed
-- here so each shape's frame-building logic reads on its own instead of
-- three branches tangled through shared locals.

-- frames is a table of image paths: one real image per frame, no shared
-- sheet. Returns {frames}; image stays nil (drawn via draw_image_frames).
local function framesFromFileList(paths, filter)
	local frames = {}
	for i = 1, #paths do
		frames[i] = AssetManager.getImage(paths[i])
		setImageFilter(frames[i], filter)
	end
	return frames
end

-- frames is a number: a single sprite-sheet image (props.image) cut into
-- that many equal-width quads left to right. Returns {frames}, the loaded
-- sheet image, and 'quad' to mark the draw mode (drawn via draw_quad_frames,
-- since each frame is a Quad into the shared sheet, not its own Image).
local function framesFromSheet(imagePath, frameCount, filter)
	local image = AssetManager.getImage(imagePath)
	if not image then
		-- headless: no texture to load or cut into real Quads, but
		-- Timeline:getFrameIndex still indexes against #frames to drive
		-- animation state (frameNum, direction, finish callbacks) -- logic
		-- a headless test may well be exercising. Placeholder entries keep
		-- the count right; draw_quad_frames itself is never reached
		-- without love.graphics.
		local placeholders = {}
		for i = 1, frameCount do
			placeholders[i] = false
		end
		return placeholders, nil
	end
	setImageFilter(image, filter)

	local textureWidth = image:getWidth() / frameCount
	local h = image:getHeight()

	local frames = {}
	for i = 1, frameCount do
		local xs = (i - 1) * textureWidth
		frames[i] = love.graphics.newQuad(xs, 0, textureWidth, h, image:getDimensions())
	end
	return frames, image
end

-- frames is a string template ('res/img/dog/Idle (${i}).png'): frameCount
-- real, separately-numbered image files. Returns {frames}; image stays nil.
local function framesFromGlob(pattern, frameCount, filter)
	local frames = {}
	for i = 1, frameCount do
		local path = pattern:gsub("${i}", tostring(i))
		frames[i] = AssetManager.getImage(path)
		setImageFilter(frames[i], filter)
	end
	return frames
end

-- Rescales/offsets the sprite so its art fills a shape_arguments box
-- (width/height from an entity's Tiled object or collider), centred on the
-- sprite's own origin. shape_arguments carry dimensions only ({width,height});
-- position is never baked into them. `frameImageWidth` is a single frame's
-- width -- the full sheet's width divided by frame count for sheet mode, or
-- just the frame's own width otherwise.
local function fitToShapeArguments(shape_arguments, frameImageWidth, frameImageHeight, scale, offset)
	local width = shape_arguments[1]
	local height = shape_arguments[2]

	local x_scale = width / frameImageWidth * scale.x
	local y_scale = height / frameImageHeight * scale.y
	local newScale = Vector(x_scale, y_scale)

	local x_offset = frameImageWidth * 0.5 + (offset.x / x_scale)
	local y_offset = frameImageHeight * 0.5 + (offset.y / y_scale)
	local newOffset = Vector(x_offset, y_offset)

	return newScale, newOffset
end

function Sprite:init(props)
	self.type = "sprite"

	local frames = props.frames
	local image = props.image
	local draw = Sprite.draw_image_frames
	local filter = props.filter or "linear"
	local framesPerImage = 1 -- sheet mode's per-frame width divisor; 1 for the others

	if type(frames) == "table" then
		frames = framesFromFileList(frames, filter)
	elseif type(frames) == "number" then
		framesPerImage = frames
		frames, image = framesFromSheet(image, frames, filter)
		draw = Sprite.draw_quad_frames
	elseif type(frames) == "string" then
		frames = framesFromGlob(frames, props.frameCount, filter)
	else
		-- no frames authored: a single-frame sheet. Entities whose art comes
		-- from a template always carry `frames`, but logic-only stubs (headless
		-- tests with properties={}) may not -- degrade to one placeholder frame
		-- the same way framesFromSheet already does without love.graphics.
		framesPerImage = 1
		draw = Sprite.draw_quad_frames
		if image then
			frames, image = framesFromSheet(image, 1, filter)
		else
			frames = { false }
		end
	end

	self.frames = cloneArray(frames)
	self.image = image
	self.frameNum = 1
	self.position = props.position or Vector(0, 0)
	self.scale = props.scale or Vector(1, 1)
	self.offset = props.offset or Vector(0, 0)
	self.facing = props.facing or "right"
	self.playingOnEnter = props.playing ~= false
	self.renderOrder = props.renderOrder
	-- Gating flag for staggered reveals (e.g. ladder tiles popping in one by
	-- one). Draw methods early-out when false; headless code never touches it.
	self.visible = props.visible ~= false

	-- Default duration for single-frame sprites (no animation)
	local duration = props.duration
	if not duration and #self.frames == 1 then
		duration = 1.0
	end
	self.timeline = Timeline({
		duration = duration,
		loop = props.loop,
		bounce = props.bounce,
		hold = props.hold,
		playing = props.playing,
		finish = props.finish,
	})

	-- headless: no real texture loaded (image and frames[1] both nil), so
	-- there's nothing to measure and no fit to compute -- self.scale/offset
	-- stay at their props/default values. Nothing under headless test reads
	-- them; only real rendering (never exercised outside e2e) would notice.
	local frameImage = image or frames[1]
	if props.shape_arguments and frameImage then
		local frameImageWidth = frameImage:getWidth() / framesPerImage
		local frameImageHeight = frameImage:getHeight()
		self.scale, self.offset =
			fitToShapeArguments(props.shape_arguments, frameImageWidth, frameImageHeight, self.scale, self.offset)
	end

	self:setFacing(self.facing)
	self.draw = draw
end

function Sprite:setFacing(facing)
	if facing ~= "left" and facing ~= "right" then
		return
	end

	self.facing = facing
	local x_scale = math.abs(self.scale.x)
	if facing == "left" then
		x_scale = -x_scale
	end
	self.scale = Vector(x_scale, self.scale.y)
end

function Sprite:setFrameNum(frameNum)
	self.frameNum = frameNum
end

-- play forward from the start and sync the visible frame immediately
function Sprite:playForward()
	self.timeline:playForward()
	self.frameNum = self.timeline:getFrameIndex(#self.frames)
end

-- play in reverse from the end and sync the visible frame immediately
function Sprite:playReverse()
	self.timeline:playReverse()
	self.frameNum = self.timeline:getFrameIndex(#self.frames)
end

-- jump to the end frame at rest (not playing), ready to play in reverse if
-- toggled -- for entities that start in their 'on' state at map load, where
-- no animation should run
function Sprite:snapToEnd()
	self.timeline:resetReverse()
	self.frameNum = self.timeline:getFrameIndex(#self.frames)
end

-- flip direction from the current frame (no snap)
function Sprite:reverseFromCurrent()
	self.timeline:reverseFromCurrent()
	self.frameNum = self.timeline:getFrameIndex(#self.frames)
end

function Sprite:getDirection()
	return self.timeline:getDirection()
end

function Sprite:isPlaying()
	return self.timeline:isPlaying()
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
		return
	end
	-- Defensive check for dt being a table
	if type(dt) ~= "number" then
		Log.error("Sprite:update received non-number dt:", type(dt), dt)
		dt = 1 / 60 -- fallback
	end
	self.timeline:update(dt)
	self.frameNum = self.timeline:getFrameIndex(#self.frames)
end

function Sprite:draw_image_frames()
	if self.visible == false then
		return
	end
	local frame = self.frames[self.frameNum]
	love.graphics.draw(
		frame,
		self.position.x,
		self.position.y,
		0,
		self.scale.x,
		self.scale.y,
		self.offset.x,
		self.offset.y
	)
end

function Sprite:draw_quad_frames()
	if self.visible == false then
		return
	end
	local frame = self.frames[self.frameNum]
	assert(frame)
	love.graphics.draw(
		self.image,
		frame,
		self.position.x,
		self.position.y,
		0,
		self.scale.x,
		self.scale.y,
		self.offset.x,
		self.offset.y
	)
end

return Sprite
