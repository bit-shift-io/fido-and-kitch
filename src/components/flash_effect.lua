-- FlashEffect component: blink and fade effects for entity sprites.
-- Follows the Tint pattern: draw() sets love.graphics.setColor, postDraw()
-- resets it. The color persists to the next frame, so there's a one-frame
-- delay (negligible for 0.15s blinks and 1.2s fades).
--
-- Usage:
--   self.flashEffect = self:addComponent(FlashEffect{})
--   self.flashEffect:blink(0.15, 8, function() ... end)
--   self.flashEffect:fadeOut(1.2)
--   self.flashEffect:fadeIn(1.2)
local FlashEffect = Class({})

function FlashEffect:init(props)
	self.type = "flash_effect"

	-- Blink state
	self._blinkActive = false
	self._blinkElapsed = 0
	self._blinkInterval = 0
	self._blinkToggles = 0
	self._blinkTarget = 0
	self._blinkOnComplete = nil
	self._visible = true

	-- Fade state
	self._alpha = 1
	self._fadeInActive = false
	self._fadeInElapsed = 0
	self._fadeInDuration = 0
	self._fadeOutActive = false
	self._fadeOutElapsed = 0
	self._fadeOutDuration = 0
end

-- Start blink: toggles visibility at the given interval for N blinks,
-- then calls onComplete. Visibility is forced true on completion.
function FlashEffect:blink(interval, blinks, onComplete)
	self._blinkActive = true
	self._blinkElapsed = 0
	self._blinkInterval = interval or 0.12
	self._blinkToggles = 0
	self._blinkTarget = blinks or 6
	self._blinkOnComplete = onComplete
	self._visible = true
end

-- Start fade-in: tweens alpha from 0 to 1 over the given duration.
function FlashEffect:fadeIn(duration)
	self._fadeInActive = true
	self._fadeInElapsed = 0
	self._fadeInDuration = duration or 1
	self._alpha = 0
end

-- Start fade-out: tweens alpha from current to 0 over the given duration.
function FlashEffect:fadeOut(duration)
	self._fadeOutActive = true
	self._fadeOutElapsed = 0
	self._fadeOutDuration = duration or 1
	self._alpha = 1
end

function FlashEffect:update(dt)
	-- Blink timer
	if self._blinkActive then
		self._blinkElapsed = self._blinkElapsed + dt
		if self._blinkElapsed >= self._blinkInterval then
			self._blinkElapsed = self._blinkElapsed - self._blinkInterval
			self._visible = not self._visible
			self._blinkToggles = self._blinkToggles + 1
			if self._blinkToggles >= self._blinkTarget then
				self._blinkActive = false
				self._visible = true
				if self._blinkOnComplete then
					self._blinkOnComplete()
				end
			end
		end
	end

	-- Fade-in timer
	if self._fadeInActive then
		self._fadeInElapsed = self._fadeInElapsed + dt
		self._alpha = math.min(self._fadeInElapsed / self._fadeInDuration, 1)
		if self._alpha >= 1 then
			self._fadeInActive = false
		end
	end

	-- Fade-out timer
	if self._fadeOutActive then
		self._fadeOutElapsed = self._fadeOutElapsed + dt
		self._alpha = 1 - math.min(self._fadeOutElapsed / self._fadeOutDuration, 1)
		if self._alpha <= 0 then
			self._fadeOutActive = false
		end
	end
end

-- Set the LÖVE graphics color to the current flash alpha. When blink is
-- "off", alpha is forced to 0 (invisible).
function FlashEffect:draw()
	local alpha = self._alpha
	if not self._visible then
		alpha = 0
	end
	if alpha < 1 then
		love.graphics.setColor(1, 1, 1, alpha)
	end
end

-- Reset LÖVE graphics color to white/opaque.
function FlashEffect:postDraw()
	love.graphics.setColor(1, 1, 1, 1)
end

return FlashEffect
