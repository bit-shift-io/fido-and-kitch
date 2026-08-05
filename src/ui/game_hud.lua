-- Unifies the hearts (a LivesHud) and the per-level coin counter behind one
-- shared fade alpha. Alpha is applied the FlashEffect way -- the ambient
-- love.graphics colour around each drawn piece -- not as a Sprite field.
local Sprite = require('src.components.sprite')
local LivesHud = require('src.ui.lives_hud')
local EventBus = require('src.utils.event_bus')
local utils = require('src.utils.utils')

local GameHud = Class{}

-- Heart geometry mirrors LivesHud's locals (24/8/16) so the coin counter
-- can sit immediately right of the last heart.
local HEART_SIZE = 24
local HEART_SPACING = 8
local ICON_SIZE = 24
local MARGIN = 16
local TEXT_SPACING = 6
local TEXT_Y_OFFSET = 6
local FADE_DURATION = 0.15 * 8 -- 1.2s, same as the player spawn flash
local HOLD_DURATION = 2.0

GameHud._internal = {
	centerOffset = function(winW, blockW)
		return math.max(MARGIN, math.floor((winW - blockW) / 2))
	end,
	heartRunWidth = function(lives)
		if lives <= 0 then
			return 0
		end
		return lives * (HEART_SIZE + HEART_SPACING) - HEART_SPACING
	end,
	coinSegmentWidth = function(hasCoins, textWidth)
		if not hasCoins then
			return 0
		end
		return HEART_SPACING + ICON_SIZE + TEXT_SPACING + textWidth
	end,
	blockWidth = function(lives, hasCoins, textWidth)
		return GameHud._internal.heartRunWidth(lives)
			+ GameHud._internal.coinSegmentWidth(hasCoins, textWidth)
	end,
}

function GameHud:init(props)
	self.getLives = props.getLives
	self.getCoins = props.getCoins
	self.getTotal = props.getTotal
	self.getCameraMode = props.getCameraMode

	self.livesHud = props.livesHud or LivesHud{getLives = self.getLives}

	self.alpha = 0
	self._fadeIn = false
	self._fadeInElapsed = 0
	self._fadeOut = false
	self._fadeOutElapsed = 0
	self.holdTimer = 0
	self.coinIcon = nil

	-- Cleared along with everything else by InGameState:exit() -> EventBus.clear()
	EventBus.on('coin_collected', utils.bindSelf(self._onTrigger, self))
	EventBus.on('player_died', utils.bindSelf(self._onTrigger, self))
end

function GameHud:_onTrigger()
	self.holdTimer = HOLD_DURATION
	if self._fadeOut then
		-- reverse a fade-out from wherever it currently is
		self._fadeOut = false
		self._fadeIn = true
		self._fadeInElapsed = (1 - self.alpha) * FADE_DURATION
	elseif not self._fadeIn and self.alpha < 1 then
		self._fadeIn = true
		self._fadeInElapsed = (1 - self.alpha) * FADE_DURATION
	end
end

function GameHud:update(dt)
	local mode = self.getCameraMode()
	if mode == 'overview' or mode == 'gameover' then
		self._fadeIn = false
		self._fadeOut = false
		self.holdTimer = 0
		self.alpha = 1
		return
	end

	if self._fadeIn then
		self._fadeInElapsed = self._fadeInElapsed + dt
		self.alpha = math.min(1, self._fadeInElapsed / FADE_DURATION)
		if self.alpha >= 1 then
			self._fadeIn = false
		end
	end

	if self.holdTimer > 0 then
		self.holdTimer = math.max(0, self.holdTimer - dt)
		if self.holdTimer <= 0.0001 and self.alpha > 0 then
			-- snap float residual so the hold ends exactly on time
			self.holdTimer = 0
			self._fadeOut = true
			self._fadeOutElapsed = 0
		end
		return
	end

	if self._fadeOut then
		self._fadeOutElapsed = self._fadeOutElapsed + dt
		self.alpha = math.max(0, 1 - self._fadeOutElapsed / FADE_DURATION)
		if self.alpha < 0.001 then
			-- snap the float tail so the HUD is truly gone
			self.alpha = 0
			self._fadeOut = false
		end
	elseif self.alpha > 0 then
		-- just left overview/gameover with a full-opacity HUD: drift back out
		self._fadeOut = true
		self._fadeOutElapsed = 0
	end
end

function GameHud:draw()
	if self.alpha <= 0 then
		return
	end

	love.graphics.setColor(1, 1, 1, self.alpha)

	local coins = self.getCoins()
	local text
	local textWidth = 0
	if coins > 0 then
		text = string.format('%d/%d', coins, self.getTotal())
		textWidth = love.graphics.getFont():getWidth(text)
	end

	local offset = GameHud._internal.centerOffset(love.graphics.getWidth(),
		GameHud._internal.blockWidth(self.getLives(), coins > 0, textWidth))

	self.livesHud:draw(offset)

	if coins > 0 then
		-- LivesHud:draw() reset the colour to (1,1,1,1); re-apply the fade
		love.graphics.setColor(1, 1, 1, self.alpha)

		local x = offset + GameHud._internal.heartRunWidth(self.getLives()) + HEART_SPACING
		local icon = self.coinIcon
		if not icon then
			icon = Sprite{
				frames = {'res/img/ui_coin.png'},
				position = Vector(x, MARGIN),
				scale = Vector(ICON_SIZE / 128, ICON_SIZE / 128),
			}
			self.coinIcon = icon
		end
		icon.position = Vector(x, MARGIN)
		icon:draw()

		love.graphics.print(text, x + ICON_SIZE + TEXT_SPACING, MARGIN + TEXT_Y_OFFSET)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return GameHud
