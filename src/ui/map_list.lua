local Tmx = require('src.map.tmx')
local Log = require('src.utils.log')
local MapCard = require('src.ui.map_card')

local MapList = Class{}

local THUMBNAIL_WIDTH = 360
local THUMBNAIL_HEIGHT = 220

function MapList:init(props)
	self.dir = props.dir
	self.cards = {}
	self.selectedIndex = 1
	self.inputCooldown = 0
	self.titleFont = love.graphics.newFont(30)
	self.bodyFont = love.graphics.newFont(20)
	self.smallFont = love.graphics.newFont(13)

	local files = love.filesystem.getDirectoryItems(self.dir)
	table.sort(files)

	for _, file in ipairs(files) do
		if str.endsWith(file, '.lua') or str.endsWith(file, '.tmx') then
			local path = self.dir .. '/' .. file
			local ok, mapData
			if str.endsWith(file, '.tmx') then
				ok, mapData = pcall(Tmx.parse, path)
			else
				local loadOk, chunk = pcall(love.filesystem.load, path)
				ok = loadOk and chunk ~= nil
				mapData = ok and chunk()
			end
			if ok and mapData then
				local title = MapCard.titleFor and MapCard.titleFor(file, mapData) or titleFor(file, mapData)
				local description = MapCard.descriptionFor and MapCard.descriptionFor(file, mapData) or descriptionFor(file, mapData)
				local players = mapData.properties and mapData.properties.players or 1

				local card = MapCard{
					file=file,
					path=path,
					title=title,
					description=description,
					players=players,
					mapData=mapData,
				}
				table.insert(self.cards, card)
			else
				Log.warn('Could not load map for menu: ' .. path)
			end
		end
	end

	if props.selectedFile then
		self:selectFile(props.selectedFile)
	end

	self:updateSelection()
end

local function baseName(file)
	return file:gsub('%.lua$', ''):gsub('%.tmx$', '')
end

local function titleFromFile(file)
	local title = baseName(file):gsub('_', ' '):gsub('-', ' ')
	return (title:gsub('(%a)([%w_\']*)', function(first, rest)
		return first:upper() .. rest:lower()
	end))
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
	if mapData.properties and mapData.properties.name then
		return mapData.properties.name
	end

	if mapData.properties and mapData.properties.title then
		return mapData.properties.title
	end

	return titleFromFile(file)
end

function MapList:updateSelection()
	local card = self.cards[self.selectedIndex]
	self.selectedFileName = card and card.file or nil
	self.selectedFile = card and card.path or nil
end

-- Selects the card for a map file name ('fab1.tmx'); a map that has since been
-- renamed or deleted just leaves the current selection alone.
function MapList:selectFile(file)
	for i, card in ipairs(self.cards) do
		if card.file == file then
			self.selectedIndex = i
			self:updateSelection()
			return true
		end
	end
	return false
end

function MapList:select(delta)
	if #self.cards == 0 then
		return
	end

	self.selectedIndex = ((self.selectedIndex - 1 + delta) % #self.cards) + 1
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

	if inputManager:isDown(1, 'left') or inputManager:wasPressed(1, 'left') then
		self:previous()
		self.inputCooldown = 0.25
	elseif inputManager:isDown(1, 'right') or inputManager:wasPressed(1, 'right') then
		self:next()
		self.inputCooldown = 0.25
	end

	return nil
end

function MapList:gamepadpressed(button)
	return nil
end

function MapList:joystickpressed(button)
	return nil
end

function MapList:pressed(x, y)
	local w = love.graphics.getWidth()
	local h = love.graphics.getHeight()
	local contentW = math.min(w * 0.9, 680)
	local contentX = (w - contentW) * 0.5
	local centerX = contentX + contentW * 0.5

	local thumbMaxW = math.min(contentW * 0.5, THUMBNAIL_WIDTH)
	local thumbMaxH = math.min(h * 0.25, THUMBNAIL_HEIGHT)
	local thumbScale = math.min(thumbMaxW / THUMBNAIL_WIDTH, thumbMaxH / THUMBNAIL_HEIGHT)
	local thumbW = THUMBNAIL_WIDTH * thumbScale
	local thumbH = THUMBNAIL_HEIGHT * thumbScale
	local thumbY = h * 0.3
	local cardGap = 40

	-- Check pips first
	local pipY = h - 60
	local pipSize = 10
	local pipGap = 16
	local totalPipWidth = (#self.cards - 1) * pipGap + pipSize
	local pipStartX = centerX - totalPipWidth * 0.5

	for i = 1, #self.cards do
		local pipX = pipStartX + (i - 1) * pipGap
		if x >= pipX and x <= pipX + pipSize and y >= pipY and y <= pipY + pipSize then
			if i ~= self.selectedIndex then
				self.selectedIndex = i
				self:updateSelection()
			end
			return nil
		end
	end

	-- Check current thumbnail (start)
	local currentCard = self.cards[self.selectedIndex]
	local currentX = centerX - thumbW * 0.5
	if currentCard and currentCard:hitTest(currentX, thumbY, x, y, thumbScale) then
		return 'start'
	end

	-- Check previous thumbnail
	local prevIndex = self.selectedIndex - 1
	if prevIndex < 1 then prevIndex = #self.cards end
	local prevCard = self.cards[prevIndex]
	local prevX = currentX - cardGap - thumbW
	if prevCard and prevCard:hitTest(prevX, thumbY, x, y, thumbScale) then
		self:previous()
		return nil
	end

	-- Check next thumbnail
	local nextIndex = self.selectedIndex + 1
	if nextIndex > #self.cards then nextIndex = 1 end
	local nextCard = self.cards[nextIndex]
	local nextX = currentX + thumbW + cardGap
	if nextCard and nextCard:hitTest(nextX, thumbY, x, y, thumbScale) then
		self:next()
		return nil
	end

	return nil
end

function MapList:draw()
	local lg = love.graphics
	local card = self.cards[self.selectedIndex]
	local w = lg.getWidth()
	local h = lg.getHeight()
	local contentW = math.min(w * 0.9, 680)
	local contentX = (w - contentW) * 0.5

	lg.setColor(0.015, 0.018, 0.025, 1)
	lg.rectangle('fill', 0, 0, w, h)

	lg.setFont(self.titleFont)
	lg.setColor(1, 1, 1, 1)
	lg.printf('FIDO & KITCH', contentX, h * 0.12, contentW, 'center')

	if not card then
		lg.setFont(self.bodyFont)
		lg.setColor(1, 1, 1, 0.82)
		lg.printf('No exported .lua maps found in ' .. self.dir, contentX, h * 0.38, contentW, 'center')
		lg.setColor(1, 1, 1, 1)
		return
	end

	local thumbMaxW = math.min(contentW * 0.5, THUMBNAIL_WIDTH)
	local thumbMaxH = math.min(h * 0.25, THUMBNAIL_HEIGHT)
	local thumbScale = math.min(thumbMaxW / THUMBNAIL_WIDTH, thumbMaxH / THUMBNAIL_HEIGHT)
	local thumbW = THUMBNAIL_WIDTH * thumbScale
	local thumbH = THUMBNAIL_HEIGHT * thumbScale
	local centerX = contentX + contentW * 0.5
	local thumbY = h * 0.3

	-- Consistent gap between cards
	local cardGap = 40

	-- Draw previous entry (faded, left)
	local prevIndex = self.selectedIndex - 1
	if prevIndex < 1 then prevIndex = #self.cards end
	local prevCard = self.cards[prevIndex]
	if prevCard then
		-- Left card right edge aligns with current card left edge minus gap
		local prevX = centerX - thumbW * 0.5 - cardGap - thumbW
		prevCard:drawThumbnail(prevX, thumbY, thumbScale, 0.25)
	end

	-- Draw current entry (center, full opacity)
	local currentX = centerX - thumbW * 0.5
	card:drawThumbnail(currentX, thumbY, thumbScale, 0.95)

	-- Draw next entry (faded, right)
	local nextIndex = self.selectedIndex + 1
	if nextIndex > #self.cards then nextIndex = 1 end
	local nextCard = self.cards[nextIndex]
	if nextCard then
		-- Right card left edge aligns with current card right edge plus gap
		local nextX = centerX + thumbW * 0.5 + cardGap
		nextCard:drawThumbnail(nextX, thumbY, thumbScale, 0.25)
	end

	-- Title and description below the current thumbnail
	local titleY = thumbY + thumbH + 24
	card:drawTitleAndInfo(contentX, titleY, contentW, {
		titleFont = self.titleFont,
		bodyFont = self.bodyFont,
		smallFont = self.smallFont,
	}, {
		title = {1, 0.86, 0.22, 1},
		body = {1, 1, 1, 0.76},
		players = {1, 1, 1, 0.76},
	})

	-- Pips at bottom
	local pipY = h - 60
	local pipSize = 10
	local pipGap = 16
	local totalPipWidth = (#self.cards - 1) * pipGap + pipSize
	local pipStartX = centerX - totalPipWidth * 0.5

	for i = 1, #self.cards do
		local pipX = pipStartX + (i - 1) * pipGap
		if i == self.selectedIndex then
			lg.setColor(1, 0.86, 0.22, 1)
			lg.rectangle('fill', pipX, pipY, pipSize, pipSize, 3, 3)
		else
			lg.setColor(1, 1, 1, 0.3)
			lg.rectangle('line', pipX, pipY, pipSize, pipSize, 3, 3)
		end
	end

	lg.setColor(1, 1, 1, 1)
end

return MapList