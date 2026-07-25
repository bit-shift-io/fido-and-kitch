-- Minimal love.* mock so the real Game/InGameState/Map/Player stack can load
-- and update headlessly. Scoped to exactly what map loading, entity
-- construction, and the update loop touch (see DECISIONS.md Q1/Q5 under
-- .scratch/integration-testing/) -- if a later mechanic touches a new love
-- call, extend this mock rather than reimplementing more of LÖVE up front.
--
-- Deliberately absent: love.window and love.graphics.isCreated. Map:resize()
-- treats their absence as "no window", skipping canvas creation entirely --
-- exactly right since these tests never call draw().
local LoveMock = {}

local function newFakeImage(width, height)
	local image = {width = width or 32, height = height or 32}
	function image:getWidth() return self.width end
	function image:getHeight() return self.height end
	function image:getDimensions() return self.width, self.height end
	function image:setFilter() end
	return image
end

local function newFakeImageData()
	local data = {}
	function data:mapPixel() end
	function data:getWidth() return 32 end
	function data:getHeight() return 32 end
	return data
end

local function newFakeQuad(x, y, w, h, sw, sh)
	return {x = x, y = y, w = w, h = h, sw = sw, sh = sh}
end

local function newFakeSpriteBatch()
	local batch = {}
	function batch:add() end
	function batch:clear() end
	function batch:setColor() end
	return batch
end

-- Pure-Lua base64 decoder. STI decodes real exported tile-layer data with
-- love.data.decode, then FFI-casts the raw bytes straight into GIDs -- so
-- this has to produce the exact original bytes, not just any string, or
-- every map with a tile layer (i.e. every real map under res/map/) would
-- load with garbage tile ids. This is the assumption flagged in DECISIONS.md
-- as needing verification against real STI output.
local BASE64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local BASE64_INDEX = {}
for i = 1, #BASE64_CHARS do
	BASE64_INDEX[BASE64_CHARS:sub(i, i)] = i - 1
end

local function base64Decode(data)
	data = data:gsub('[^' .. BASE64_CHARS .. '=]', '')
	local bytes = {}
	local bits, bitCount = 0, 0

	for i = 1, #data do
		local c = data:sub(i, i)
		if c ~= '=' then
			bits = (bits * 64) + BASE64_INDEX[c]
			bitCount = bitCount + 6

			if bitCount >= 8 then
				bitCount = bitCount - 8
				local byte = math.floor(bits / (2 ^ bitCount)) % 256
				table.insert(bytes, string.char(byte))
				-- drop the bits already emitted, or `bits` grows without
				-- bound (and loses precision) across a long tile layer
				bits = bits % (2 ^ bitCount)
			end
		end
	end

	return table.concat(bytes)
end

-- Straight-line approximation of a bezier curve's evaluate(): entities like
-- bird/jump_pad only need a deterministic, error-free position along the
-- path for a headless smoke run, not visually-accurate curvature.
local function newFakeBezierCurve(points)
	local curve = {points = points}

	function curve:evaluate(t)
		t = math.min(1, math.max(0, t))
		local x1, y1 = self.points[1], self.points[2]
		local x2, y2 = self.points[#self.points - 1], self.points[#self.points]
		return x1 + (x2 - x1) * t, y1 + (y2 - y1) * t
	end

	function curve:render()
		return self.points
	end

	return curve
end

-- Builds one fresh love mock (own keyboard/joystick state) per test so
-- tests don't leak input state between each other.
function LoveMock.new()
	local state = {
		keysDown = {},
		joysticks = {},
	}

	local love = {}

	love.keyboard = {
		isDown = function(key)
			return state.keysDown[key] == true
		end,
	}

	love.joystick = {
		getJoysticks = function()
			return state.joysticks
		end,
	}

	love.filesystem = {
		load = function(path)
			return loadfile(path)
		end,
	}

	love.data = {
		decode = function(containerType, format, data)
			assert(format == 'base64', 'love_mock only supports base64-decoding tile layer data')
			return base64Decode(data)
		end,
	}

	love.image = {
		newImageData = function(path)
			return newFakeImageData()
		end,
	}

	love.math = {
		newBezierCurve = newFakeBezierCurve,
		isConvex = function() return true end,
		triangulate = function(vertices) return {vertices} end,
	}

	love.graphics = {
		newImage = function(source) return newFakeImage() end,
		newQuad = newFakeQuad,
		newSpriteBatch = newFakeSpriteBatch,
		-- STI's atlas packer (used for image-collection tilesets, e.g.
		-- props.tsx in the real maps) treats the returned canvas as an
		-- image afterwards (tileset.image:getWidth() etc.), so it needs
		-- the same shape as newImage's fake.
		newCanvas = function(w, h) return newFakeImage(w, h) end,
		newFont = function() return {} end,
		getSystemLimits = function() return {texturesize = 16384} end,
		draw = function() end,
		setColor = function() end,
		getColor = function() return 1, 1, 1, 1 end,
		push = function() end,
		pop = function() end,
		translate = function() end,
		scale = function() end,
		origin = function() end,
		rectangle = function() end,
		line = function() end,
		circle = function() end,
		polygon = function() end,
		clear = function() end,
		getCanvas = function() end,
		setCanvas = function() end,
		setDefaultFilter = function() end,
		getWidth = function() return 800 end,
		getHeight = function() return 600 end,
	}

	love._state = state
	return love
end

return LoveMock
