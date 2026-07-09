local MapList = Class{}

local THUMBNAIL_WIDTH = 360
local THUMBNAIL_HEIGHT = 220

local MAP_DETAILS = {
	sandbox={
		title='Sandbox',
		description='A playground map for testing movement, teleporters, jump pads, keys, and other mechanics.'
	},
	ll1={
		title='Ladder Lab 1',
		description='A compact co-op puzzle with ladders, keys, cages, birds, and an exit objective.'
	},
	ll2={
		title='Ladder Lab 2',
		description='A wider puzzle space with layered platforms and more routes to coordinate.'
	}
}

local ENTITY_COLORS = {
	spawn={0.35, 0.85, 1.0, 1},
	key={1.0, 0.85, 0.2, 1},
	cage={0.85, 0.45, 1.0, 1},
	exit_door={0.25, 1.0, 0.35, 1},
	teleport={0.35, 0.45, 1.0, 1},
	jump_pad={1.0, 0.45, 0.25, 1},
	coin={1.0, 0.75, 0.1, 1},
	bird={1.0, 1.0, 1.0, 1},
	ladder={0.75, 0.55, 0.3, 1},
}

local function baseName(file)
	return file:gsub('%.lua$', '')
end

local function titleFromFile(file)
	local title = baseName(file):gsub('_', ' '):gsub('-', ' ')
	return (title:gsub('(%a)([%w_\']*)', function(first, rest)
		return first:upper() .. rest:lower()
	end))
end

local function readTile(data, index)
	local i = ((index - 1) * 4) + 1
	local b1, b2, b3, b4 = data:byte(i, i + 3)
	if b4 == nil then
		return 0
	end

	-- Tiled stores global tile ids as little-endian uint32 values. The high
	-- bits can contain flip flags, so strip those for preview purposes.
	return (b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)) % 268435456
end

local function collectEntityTypes(mapData)
	local types = {}
	for _, layer in ipairs(mapData.layers or {}) do
		if layer.type == 'objectgroup' then
			for _, object in ipairs(layer.objects or {}) do
				if object.type and object.type ~= '' and object.type ~= 'spawn' then
					types[object.type] = true
				end
			end
		end
	end
	return types
end

local function descriptionFor(file, mapData)
	local details = MAP_DETAILS[baseName(file)]
	if details and details.description then
		return details.description
	end

	if mapData.properties and mapData.properties.description then
		return mapData.properties.description
	end

	local labels = {}
	local entityTypes = collectEntityTypes(mapData)
	local ordered = {
		{'key', 'keys'},
		{'cage', 'cages'},
		{'teleport', 'teleporters'},
		{'jump_pad', 'jump pads'},
		{'coin', 'coins'},
		{'exit_door', 'an exit door'},
	}
	for _, item in ipairs(ordered) do
		if entityTypes[item[1]] then
			table.insert(labels, item[2])
		end
	end

	if #labels == 0 then
		return 'A bite-sized Fido and Kitch puzzle map.'
	end

	return 'A bite-sized puzzle featuring ' .. table.concat(labels, ', ') .. '.'
end

local function titleFor(file, mapData)
	local details = MAP_DETAILS[baseName(file)]
	if details and details.title then
		return details.title
	end

	if mapData.properties and mapData.properties.title then
		return mapData.properties.title
	end

	return titleFromFile(file)
end

local function drawMapThumbnail(mapData)
	local lg = love.graphics
	local mapPixelWidth = math.max(1, (mapData.width or 1) * (mapData.tilewidth or 32))
	local mapPixelHeight = math.max(1, (mapData.height or 1) * (mapData.tileheight or 32))
	local scale = math.min(THUMBNAIL_WIDTH / mapPixelWidth, THUMBNAIL_HEIGHT / mapPixelHeight)
	local tx = (THUMBNAIL_WIDTH - (mapPixelWidth * scale)) * 0.5
	local ty = (THUMBNAIL_HEIGHT - (mapPixelHeight * scale)) * 0.5

	lg.clear(0, 0, 0, 0)

	lg.push()
	lg.translate(tx, ty)
	lg.scale(scale, scale)

	for _, layer in ipairs(mapData.layers or {}) do
		if layer.type == 'tilelayer' and layer.visible ~= false and type(layer.data) == 'string' then
			local ok, decoded = pcall(love.data.decode, 'string', 'base64', layer.data)
			if ok and decoded then
				local isCollision = layer.properties and layer.properties.collision
				if isCollision then
					lg.setColor(1, 1, 1, 0.22)
				else
					lg.setColor(1, 1, 1, 0.08)
				end

				for y = 1, layer.height do
					for x = 1, layer.width do
						local gid = readTile(decoded, ((y - 1) * layer.width) + x)
						if gid > 0 then
							lg.rectangle('fill', (x - 1) * mapData.tilewidth, (y - 1) * mapData.tileheight, mapData.tilewidth, mapData.tileheight)
						end
					end
				end
			end
		elseif layer.type == 'objectgroup' and layer.visible ~= false then
			for _, object in ipairs(layer.objects or {}) do
				local color = ENTITY_COLORS[object.type]
				if color then
					lg.setColor(1, 1, 1, 0.32)
					local width = math.max(object.width or 16, 16)
					local height = math.max(object.height or 16, 16)
					lg.rectangle('fill', object.x or 0, (object.y or 0) - height, width, height)
				end
			end
		end
	end

	lg.pop()
end

function MapList:init(props)
	self.dir = props.dir
	self.entries = {}
	self.selectedIndex = 1
	self.inputCooldown = 0
	self.buttonRects = {}
	self.titleFont = love.graphics.newFont(30)
	self.bodyFont = love.graphics.newFont(16)
	self.smallFont = love.graphics.newFont(13)

	local files = love.filesystem.getDirectoryItems(self.dir)
	table.sort(files)

	for _, file in ipairs(files) do
		if str.endsWith(file, '.lua') then
			local path = self.dir .. '/' .. file
			local ok, chunk = pcall(love.filesystem.load, path)
			local mapData = ok and chunk and chunk()
			if mapData then
				local canvas = love.graphics.newCanvas(THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT)
				local previousCanvas = love.graphics.getCanvas()
				love.graphics.setCanvas(canvas)
				drawMapThumbnail(mapData)
				love.graphics.setCanvas(previousCanvas)

				table.insert(self.entries, {
					file=file,
					path=path,
					title=titleFor(file, mapData),
					description=descriptionFor(file, mapData),
					canvas=canvas,
					mapData=mapData,
				})
			else
				print('Could not load map for menu: ' .. path)
			end
		end
	end

	self:updateSelection()
end

function MapList:updateSelection()
	local entry = self.entries[self.selectedIndex]
	self.selectedFileName = entry and entry.file or nil
	self.selectedFile = entry and entry.path or nil
end

function MapList:select(delta)
	if #self.entries == 0 then
		return
	end

	self.selectedIndex = ((self.selectedIndex - 1 + delta) % #self.entries) + 1
	self:updateSelection()
end

function MapList:previous()
	self:select(-1)
end

function MapList:next()
	self:select(1)
end

function MapList:update(dt)
	self.inputCooldown = math.max(0, self.inputCooldown - dt)

	if self.inputCooldown > 0 then
		return nil
	end

	local joysticks = love.joystick.getJoysticks()
	local joystick = joysticks[1]
	if joystick then
		local x = 0
		if joystick:isGamepad() then
			x = joystick:getGamepadAxis('leftx') or 0
		else
			x = joystick:getAxis(1) or 0
		end

		if x < -0.55 then
			self:previous()
			self.inputCooldown = 0.25
		elseif x > 0.55 then
			self:next()
			self.inputCooldown = 0.25
		end
	end

	return nil
end

function MapList:gamepadpressed(button)
	if button == 'dpleft' or button == 'leftshoulder' then
		self:previous()
	elseif button == 'dpright' or button == 'rightshoulder' then
		self:next()
	elseif button == 'a' or button == 'start' then
		return 'start'
	elseif button == 'b' then
		return 'back'
	end

	return nil
end

function MapList:joystickpressed(button)
	if button == 1 then
		return 'start'
	elseif button == 2 then
		return 'back'
	elseif button == 5 then
		self:previous()
	elseif button == 6 then
		self:next()
	end

	return nil
end

function MapList:pressed(x, y)
	for action, rect in pairs(self.buttonRects) do
		if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
			if action == 'previous' then
				self:previous()
				return nil
			elseif action == 'next' then
				self:next()
				return nil
			else
				return action
			end
		end
	end

	return nil
end

function MapList:drawButton(label, x, y, w, h, action, filled)
	local lg = love.graphics
	self.buttonRects[action] = {x=x, y=y, w=w, h=h}

	if filled then
		lg.setColor(1, 0.86, 0.22, 1)
	else
		lg.setColor(1, 1, 1, 0.78)
	end

	lg.printf(label, x, y + ((h - self.bodyFont:getHeight()) * 0.5), w, 'center')
end

function MapList:draw()
	local lg = love.graphics
	local entry = self.entries[self.selectedIndex]
	local w = lg.getWidth()
	local h = lg.getHeight()
	local contentW = math.min(w * 0.9, 680)
	local contentX = (w - contentW) * 0.5
	self.buttonRects = {}

	lg.setColor(0.015, 0.018, 0.025, 1)
	lg.rectangle('fill', 0, 0, w, h)

	lg.setFont(self.titleFont)
	lg.setColor(1, 1, 1, 1)
	lg.printf('FIDO & KITCH', contentX, h * 0.12, contentW, 'center')

	lg.setFont(self.smallFont)
	lg.setColor(1, 1, 1, 0.45)
	lg.printf('SELECT LEVEL', contentX, h * 0.12 + 42, contentW, 'center')

	if not entry then
		lg.setFont(self.bodyFont)
		lg.setColor(1, 1, 1, 0.82)
		lg.printf('No exported .lua maps found in ' .. self.dir, contentX, h * 0.38, contentW, 'center')
		lg.setColor(1, 1, 1, 1)
		return
	end

	local thumbMaxW = math.min(contentW * 0.58, THUMBNAIL_WIDTH)
	local thumbMaxH = math.min(h * 0.18, THUMBNAIL_HEIGHT)
	local thumbScale = math.min(thumbMaxW / THUMBNAIL_WIDTH, thumbMaxH / THUMBNAIL_HEIGHT)
	local thumbW = THUMBNAIL_WIDTH * thumbScale
	local thumbH = THUMBNAIL_HEIGHT * thumbScale
	local thumbX = contentX + ((contentW - thumbW) * 0.5)
	local thumbY = h * 0.25

	lg.setColor(1, 1, 1, 0.75)
	lg.draw(entry.canvas, thumbX, thumbY, 0, thumbScale, thumbScale)

	lg.setFont(self.smallFont)
	lg.setColor(1, 1, 1, 0.42)
	lg.printf(self.selectedIndex .. ' / ' .. #self.entries, contentX, thumbY + thumbH + 24, contentW, 'center')

	lg.setFont(self.titleFont)
	lg.setColor(1, 0.86, 0.22, 1)
	lg.printf(entry.title:upper(), contentX, thumbY + thumbH + 54, contentW, 'center')

	lg.setFont(self.bodyFont)
	lg.setColor(1, 1, 1, 0.76)
	lg.printf(entry.description, contentX + 32, thumbY + thumbH + 104, contentW - 64, 'center')

	local buttonY = math.min(h - 118, thumbY + thumbH + 180)
	local sideButtonW = math.min(110, contentW * 0.24)
	local startButtonW = math.min(220, contentW * 0.42)
	local buttonH = 56
	lg.setFont(self.bodyFont)
	self:drawButton('< PREV', contentX, buttonY, sideButtonW, buttonH, 'previous')
	self:drawButton('START', contentX + ((contentW - startButtonW) * 0.5), buttonY, startButtonW, buttonH, 'start', true)
	self:drawButton('NEXT >', contentX + contentW - sideButtonW, buttonY, sideButtonW, buttonH, 'next')

	lg.setColor(1, 1, 1, 1)
end

return MapList
