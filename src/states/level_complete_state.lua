local BaseState = require("src.states.base_state")
local Log = require("src.utils.log")
local LevelScore = require("src.scoring.level_score")
local LevelRecords = require("src.utils.level_records")
local Format = require("src.utils.format")

local LevelCompleteState = Class({ __includes = BaseState })

local MEDAL_COLORS = Format.MEDAL_COLORS

function LevelCompleteState:enter()
	Log.debug("levelcomplete enter")
	self.buttonRects = {}
	self.titleFont = love.graphics.newFont(30)
	self.bodyFont = love.graphics.newFont(20)
end

function LevelCompleteState:load(props)
	props = props or {}
	self.map = props.map
	self.livesRemaining = props.lives or 0
	self.maxLives = props.maxLives or 0
	self.coinsCollected = props.coins or 0
	self.totalCoins = props.totalCoins or 0
	self.timeTaken = props.time or 0

	self.score = LevelScore.compute({
		livesRemaining = self.livesRemaining,
		maxLives = self.maxLives,
		coinsCollected = self.coinsCollected,
		totalCoins = self.totalCoins,
	})

	LevelRecords.recordCompletion(self.map, {
		totalPct = self.score.totalPct,
		medal = self.score.medal,
		timeSeconds = self.timeTaken,
	})
end

function LevelCompleteState:exit() end

function LevelCompleteState:update(dt)
	for i = 1, 4 do
		if inputManager:wasPressed(i, "start") or inputManager:wasPressed(i, "use") then
			self:continue()
			break
		end
	end
end

function LevelCompleteState:continue()
	local game = self.entity
	game:setGameState("MenuState")
end

function LevelCompleteState:handlePress(x, y)
	for id, rect in pairs(self.buttonRects) do
		if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
			self:continue()
			return
		end
	end
end

function LevelCompleteState:draw()
	local lg = love.graphics
	local w = lg.getWidth()
	local h = lg.getHeight()
	self.buttonRects = {}

	lg.setColor(0, 0, 0, 0.85)
	lg.rectangle("fill", 0, 0, w, h)

	lg.setFont(self.titleFont)
	lg.setColor(1, 1, 1, 1)
	lg.printf("LEVEL COMPLETE", 0, h * 0.15, w, "center")

	lg.setFont(self.bodyFont)
	lg.setColor(1, 1, 1, 0.9)
	local lineHeight = 28
	local y = h * 0.15 + 60

	lg.printf(string.format("Hearts: %d/%d", self.livesRemaining, self.maxLives), 0, y, w, "center")
	y = y + lineHeight

	lg.printf(string.format("Coins: %d/%d", self.coinsCollected, self.totalCoins), 0, y, w, "center")
	y = y + lineHeight

	lg.printf(string.format("Score: %d%%", math.floor(self.score.totalPct)), 0, y, w, "center")
	y = y + lineHeight

	local medalColor = MEDAL_COLORS[self.score.medal] or { 1, 1, 1, 1 }
	lg.setColor(medalColor)
	lg.printf(string.format("Medal: %s", self.score.medal), 0, y, w, "center")
	lg.setColor(1, 1, 1, 0.9)
	y = y + lineHeight

	lg.printf(string.format("Time: %s", Format.time(self.timeTaken)), 0, y, w, "center")
	y = y + lineHeight

	local buttonWidth = 220
	local buttonHeight = 40
	local buttonY = y + 20
	local buttonX = (w - buttonWidth) * 0.5
	self.buttonRects["continue"] = { x = buttonX, y = buttonY, w = buttonWidth, h = buttonHeight }

	lg.setColor(1, 0.86, 0.22, 1)
	lg.printf("Continue", buttonX, buttonY + ((buttonHeight - self.bodyFont:getHeight()) * 0.5), buttonWidth, "center")

	lg.setColor(1, 1, 1, 1)
end

function LevelCompleteState:keypressed(k)
	if k == "return" or k == "space" then
		self:continue()
	end
end

function LevelCompleteState:mousepressed(x, y, button)
	if button ~= 1 then
		return
	end
	self:handlePress(x, y)
end

function LevelCompleteState:touchpressed(id, x, y)
	self:handlePress(x, y)
end

return LevelCompleteState
