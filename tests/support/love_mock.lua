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
	function batch:set() end
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
		-- real LÖVE returns a FileInfo table when the file exists relative to
		-- the game's source, nil otherwise; checking the real repo file is
		-- enough for headless tests since res/ paths are real on disk
		getInfo = function(path)
			local file = io.open(path, 'rb')
			if file == nil then
				return nil
			end
			file:close()
			return {}
		end,
		read = function(path)
			local file = io.open(path, 'r')
			if file == nil then
				return nil
			end
			local contents = file:read('*a')
			file:close()
			return contents
		end,
		-- MenuState's MapList reads this to build its map cards. Real LÖVE
		-- lists a virtual filesystem directory; here `path` is a real repo
		-- path (e.g. 'res/map'), so shell out the same way
		-- all_maps_load_test.lua already does for res/map/*.tmj.
		getDirectoryItems = function(path)
			local items = {}
			local pipe = io.popen('ls ' .. path .. ' 2>/dev/null')
			if pipe then
				for line in pipe:lines() do
					table.insert(items, line)
				end
				pipe:close()
			end
			return items
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
		random = function() return 0.5 end,
	}

	-- Timer module for dt tracking in headless tests
	love.timer = {
		_getTime = 0,
		getDelta = function()
			return 1/60  -- fixed dt for deterministic testing
		end,
		getTime = function()
			love.timer._getTime = love.timer._getTime + 1/60
			return love.timer._getTime
		end,
		sleep = function() end,
		step = function() end,
	}

	love.getVersion = function()
		-- Return LÖVE 11 version (11, 4, 0) so vertex format uses old format
		-- This should be 11, 4, 0 for LÖVE 11 - but any version < 12 works
		return 11, 4, 0
	end

	state.audio = {created = {}}

	love.audio = {
		newSource = function(path, kind)
			local source = {path = path, kind = kind, pitch = 1, volume = 1, playing = false}
			function source:setPitch(pitch) self.pitch = pitch end
			function source:setVolume(vol) self.volume = vol end
			function source:play() self.playing = true end
			function source:stop() self.playing = false end
			function source:isPlaying() return self.playing end
			function source:seek(offset) end
			table.insert(state.audio.created, source)
			return source
		end,
	}

	local function newFakeMesh()
		local mesh = {
			vertices = {},
			texture = nil,
		}
		function mesh:setVertices(verts) self.vertices = verts end
		function mesh:getVertices() return self.vertices end
		function mesh:setTexture(tex) self.texture = tex end
		function mesh:draw() end
		function mesh:getVertexCount() return #self.vertices end
		return mesh
	end

	love.graphics = {
		newImage = function(source) return newFakeImage() end,
		newQuad = newFakeQuad,
		newSpriteBatch = newFakeSpriteBatch,
		newMesh = function(vertexFormat, vertices, drawMode) return newFakeMesh() end,
		-- STI's atlas packer (used for image-collection tilesets, e.g.
		-- props.tsj in the real maps) treats the returned canvas as an
		-- image afterwards (tileset.image:getWidth() etc.), so it needs
		-- the same shape as newImage's fake.
		newCanvas = function(w, h) return newFakeImage(w, h) end,
		newFont = function() return {} end,
		getFont = function() return {getWidth = function() return 0 end} end,
		getSystemLimits = function() return {texturesize = 16384} end,
		draw = function() end,
		setColor = function() end,
		getColor = function() return 1, 1, 1, 1 end,
		print = function() end,
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

	-- Window state for mock
	local windowState = {
		fullscreen = false,
		fullscreentype = 'desktop',
		maximized = false,
		minimized = false,
		width = 800,
		height = 600,
		x = 100,
		y = 100,
		title = 'Fido & Kitch',
		displayindex = 1,
		vsync = 1,
		msaa = 0,
		resizable = true,
		borderless = false,
	}

	love.window = {
		-- Fullscreen
		setFullscreen = function(fullscreen, fullscreentype)
			windowState.fullscreen = fullscreen == true
			if fullscreentype then windowState.fullscreentype = fullscreentype end
			return true
		end,
		getFullscreen = function()
			return windowState.fullscreen, windowState.fullscreentype
		end,

		-- Maximize/minimize/restore
		maximize = function()
			windowState.maximized = true
			windowState.minimized = false
		end,
		minimize = function()
			windowState.minimized = true
			windowState.maximized = false
		end,
		restore = function()
			windowState.maximized = false
			windowState.minimized = false
		end,
		isMaximized = function()
			return windowState.maximized
		end,
		isMinimized = function()
			return windowState.minimized
		end,

		-- Dimensions/position
		getDimensions = function()
			return windowState.width, windowState.height
		end,
		setDimensions = function(w, h)
			windowState.width = w
			windowState.height = h
		end,
		getPosition = function()
			return windowState.x, windowState.y
		end,
		setPosition = function(x, y)
			windowState.x = x
			windowState.y = y
		end,

		-- Title
		getTitle = function()
			return windowState.title
		end,
		setTitle = function(title)
			windowState.title = title
		end,

		-- Display
		getDisplayIndex = function()
			return windowState.displayindex
		end,
		setDisplayIndex = function(index)
			windowState.displayindex = index
		end,

		-- VSync/MSAA
		getVSync = function()
			return windowState.vsync
		end,
		setVSync = function(vsync)
			windowState.vsync = vsync
		end,

		getMSAA = function()
			return windowState.msaa
		end,

		-- Properties
		isResizable = function()
			return windowState.resizable
		end,
		setResizable = function(resizable)
			windowState.resizable = resizable
		end,
		isBorderless = function()
			return windowState.borderless
		end,
		setBorderless = function(borderless)
			windowState.borderless = borderless
		end,

		-- Mode (for love.window.getMode / setMode)
		getMode = function()
			return {
				width = windowState.width,
				height = windowState.height,
				fullscreen = windowState.fullscreen,
				fullscreentype = windowState.fullscreentype,
				vsync = windowState.vsync,
				msaa = windowState.msaa,
				resizable = windowState.resizable,
				borderless = windowState.borderless,
				display = windowState.displayindex,
				highdpi = false,
				minwidth = 1,
				minheight = 1,
				x = windowState.x,
				y = windowState.y,
			}
		end,
		setMode = function(width, height, flags)
			flags = flags or {}
			windowState.width = width
			windowState.height = height
			if flags.fullscreen ~= nil then windowState.fullscreen = flags.fullscreen end
			if flags.fullscreentype then windowState.fullscreentype = flags.fullscreentype end
			if flags.vsync ~= nil then windowState.vsync = flags.vsync end
			if flags.msaa ~= nil then windowState.msaa = flags.msaa end
			if flags.resizable ~= nil then windowState.resizable = flags.resizable end
			if flags.borderless ~= nil then windowState.borderless = flags.borderless end
			if flags.display ~= nil then windowState.displayindex = flags.display end
			if flags.minwidth then windowState.minwidth = flags.minwidth end
			if flags.minheight then windowState.minheight = flags.minheight end
			if flags.x then windowState.x = flags.x end
			if flags.y then windowState.y = flags.y end
			return true
		end,

		-- Icon
		setIcon = function(image) end,
	}

	love._state = state
	return love
end

return LoveMock
