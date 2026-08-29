-- Invisible static-sensor hotspot with a `text` Tiled property (`\n` = line
-- break). Pressing `use` while overlapping toggles a screen-space speech
-- bubble above the entity for that player: a rounded box + tail, centred
-- text, per-line NES typewriter ramp (first ~4 chars letter-by-letter at
-- 40/s, then the rest, then the full slab). `use` mid-reveal shows the rest
-- instantly; the next `use` dismisses. A bubble auto-dismisses when the
-- triggering player's overlap ends; re-trigger is gated by a 0.5s cooldown
-- counted from dismissal. Both players can show bubbles on the same entity
-- simultaneously (one per player).
--
-- Pure decision helpers (typewriter ramp, cooldown gate, overlap check,
-- bubble geometry) stay private locals reached by tests/unit/story_test.lua
-- through the `_internal` white-box seam below -- same pattern as
-- src/entities/drawbridge.lua. Only drawBubbleScreen touches love.graphics.

local Story = Class{__includes = Entity}
local SpriteProps = require('src.entities.sprite_props')

local LETTER_COUNT = 4
local LETTER_RATE = 25.6
local WORD_PHASE = 0.234375
local COOLDOWN = 0.5
local PADDING = 12
local CORNER_RADIUS = 3
local LINE_HEIGHT = 16
local MAX_WIDTH = 500
local TAIL_HEIGHT = 8
local TAIL_WIDTH = 16
local BOX_GAP = 4
local SCREEN_MARGIN = 4

--
-- typewriter ramp
--

local function splitLines(text)
	if text == nil or text == '' then
		return {}
	end
	local lines = {}
	for line in (text .. '\n'):gmatch('(.-)\n') do
		table.insert(lines, line)
	end
	return lines
end

-- per-line reveal duration: lines up to LETTER_COUNT chars reveal entirely by
-- letter-rate; longer lines add the word phase
local function lineDuration(line)
	local len = #line
	if len <= LETTER_COUNT then
		return len / LETTER_RATE
	end
	return LETTER_COUNT / LETTER_RATE + WORD_PHASE
end

-- how many characters of `line` are visible at time `t` (per-line clock):
-- 1 char at t=0, letter-by-letter through the letter phase, then the rest of
-- the line over the word phase
local function revealedCount(line, t)
	local len = #line
	if len <= LETTER_COUNT then
		return math.min(math.floor(t * LETTER_RATE) + 1, len)
	end

	local letterPhase = LETTER_COUNT / LETTER_RATE
	if t < letterPhase then
		return math.min(math.floor(t * LETTER_RATE) + 1, LETTER_COUNT)
	end

	-- word phase: the word holding the LETTER_COUNT-th character completes at
	-- the start of the phase, then the remaining characters reveal linearly
	local firstWordEnd = 0
	local cumulative = 0
	for word in string.gmatch(line, '%S+') do
		cumulative = cumulative + #word
		if firstWordEnd == 0 and cumulative >= LETTER_COUNT then
			firstWordEnd = cumulative
			break
		end
	end

	local tail = len - firstWordEnd
	if tail <= 0 then
		return len
	end

	local tailRevealed = math.min(math.floor(((t - letterPhase) / WORD_PHASE) * tail), tail)
	return firstWordEnd + tailRevealed
end

local function totalDuration(lines)
	local total = 0
	for i, line in ipairs(lines) do
		total = total + lineDuration(line)
	end
	return total
end

local function isFullyRevealed(revealElapsed, lines)
	return revealElapsed >= totalDuration(lines)
end

-- byte-safe slice of `s` to at most `n` characters (revealedCount counts
-- bytes via #line, but cutting mid-multibyte-character would hand
-- love.graphics a truncated UTF-8 sequence); steps over continuation bytes
local function utf8Cut(s, n)
	local i = 1
	local count = 0
	while count < n and i <= #s do
		local b = s:byte(i)
		local width = 1
		if b >= 0xF0 then width = 4
		elseif b >= 0xE0 then width = 3
		elseif b >= 0xC0 then width = 2
		end
		i = i + width
		count = count + 1
	end
	return s:sub(1, i - 1)
end

-- before the cursor, '' after it, a partial line in between
local function visibleText(lines, t)
	local result = {}
	local elapsed = 0
	for i, line in ipairs(lines) do
		local duration = lineDuration(line)
		if elapsed + duration <= t then
			result[i] = line
		elseif t <= elapsed then
			result[i] = ''
		else
			result[i] = utf8Cut(line, revealedCount(line, t - elapsed))
		end
		elapsed = elapsed + duration
	end
	return result
end

--
-- cooldown gate
--

-- cooldownUntil is a remaining-seconds countdown: nil/<= 0 means ready to
-- show, a positive value means locked
local function canShow(cooldownUntil)
	return cooldownUntil == nil or cooldownUntil <= 0
end

--
-- overlap check
--

local function playerOverlaps(world, collider, playerCollider)
	if not world or not collider or not playerCollider then
		return false
	end
	local results = world:queryOverlap(collider:getBounds())
	for _, item in ipairs(results) do
		if item == playerCollider then
			return true
		end
	end
	return false
end

--
-- bubble geometry (all pure, no love calls; measure(line) is injected)
--

-- project a world point through the camera's translate-then-scale transform:
-- (wx, wy) with a world-space translation (tx, ty) and scale (sx, sy)
local function screenPoint(wx, wy, tx, ty, sx, sy)
	return (wx + tx) * sx, (wy + ty) * sy
end

local function boxWidth(lines, measure)
	local width = 0
	for i, line in ipairs(lines) do
		local w = measure(line)
		if w > width then
			width = w
		end
	end
	return width + 2 * PADDING
end

local function boxHeight(lineCount, lineHeight)
	return lineCount * lineHeight + 2 * PADDING
end

-- three tail points connecting the box's bottom centre down to the anchor
local function tailPoints(x, y, w, h, anchorX, anchorY)
	local cx = x + w / 2
	local baseY = y + h
	return {
		{ x = cx - TAIL_WIDTH / 2, y = baseY },
		{ x = cx + TAIL_WIDTH / 2, y = baseY },
		{ x = anchorX, y = anchorY },
	}
end

-- clamp a box's top-left so the whole box fits inside the screen rect
-- (0,0,sw,sh) with `margin` on every side, pushing it inwards when it would
-- run off an edge; when the box is wider/taller than the available space it
-- pins to the top-left so as much stays visible as possible
local function clampToScreen(x, y, w, h, sw, sh, margin)
	x = math.max(margin, math.min(x, sw - w - margin))
	y = math.max(margin, math.min(y, sh - h - margin))
	return x, y
end

--
-- word wrap (pure; measure(line) is injected)
--

-- greedy word-wrap of a single line into sub-lines that each fit within
-- maxWidth; returns {line} unchanged when it already fits
local function wrapLine(line, measure, maxWidth)
	if measure(line) <= maxWidth then
		return { line }
	end
	local wrapped = {}
	local current = ''
	for word in string.gmatch(line, '%S+') do
		if current == '' then
			current = word
		elseif measure(current .. ' ' .. word) <= maxWidth then
			current = current .. ' ' .. word
		else
			table.insert(wrapped, current)
			current = word
		end
	end
	table.insert(wrapped, current)
	return wrapped
end

-- flatten every line's wrapped sub-lines into one display list
local function wrapLines(lines, measure, maxWidth)
	local result = {}
	for i, line in ipairs(lines) do
		for j, sub in ipairs(wrapLine(line, measure, maxWidth)) do
			table.insert(result, sub)
		end
	end
	return result
end

Story._internal = {
	CONST = {
		LETTER_COUNT = LETTER_COUNT,
		LETTER_RATE = LETTER_RATE,
		WORD_PHASE = WORD_PHASE,
		COOLDOWN = COOLDOWN,
		PADDING = PADDING,
	},
	typewriter = {
		splitLines = splitLines,
		lineDuration = lineDuration,
		revealedCount = revealedCount,
		totalDuration = totalDuration,
		isFullyRevealed = isFullyRevealed,
		visibleText = visibleText,
	},
	cooldown = {
		canShow = canShow,
	},
	playerOverlaps = playerOverlaps,
	wrap = {
		wrapLine = wrapLine,
		wrapLines = wrapLines,
	},
	bubble = {
		screenPoint = screenPoint,
		boxWidth = boxWidth,
		boxHeight = boxHeight,
		clampToScreen = clampToScreen,
	},
}

function Story:init(object, map)
	Entity.init(self, object, 'story')
	self.text = (object.properties and object.properties.text) or ''
	self.lines = splitLines(self.text)

	-- retro blocky font for the speech bubble
	self.font = nil
	if love and love.graphics then
		self.font = love.graphics.newFont('res/fnt/SuperMarioBrosNES.ttf', 14)
	end

	local position = Rect.centreOfMapObject(object)
	local shape_arguments = Rect.shapeArgs(object.width, object.height)
	local spriteProps = SpriteProps.fromObject(object)
	spriteProps.position = position
	spriteProps.shape_arguments = shape_arguments
	self.sprite = self:addComponent(Sprite(spriteProps))
	self.collider = self:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = shape_arguments,
		body_type = 'static',
		position = position,
		sensor = true,
	})
	self:addComponent(Usable{
		entity = self,
		use = utils.bindSelf(self.use, self),
	})
	self.sound = self:addComponent(Sound{
		sounds = {
			blip = 'res/snd/entity_story_blip.wav',
		}
	})

	self.bubbles = {}
end

-- toggle per player: not visible -> show (cooldown permitting); visible but
-- mid-reveal -> reveal the rest instantly; visible and fully revealed ->
-- dismiss and start the cooldown
function Story:use(user)
	local bubble = self.bubbles[user]
	if not (bubble and bubble.visible) then
		if canShow(bubble and bubble.cooldownTimer) then
			if not bubble then
				bubble = {}
				self.bubbles[user] = bubble
			end
			bubble.visible = true
			bubble.revealElapsed = 0
			bubble.cooldownTimer = 0
			self.sound:play('blip')
		end
		return
	end

	if not isFullyRevealed(bubble.revealElapsed, self.lines) then
		bubble.revealElapsed = totalDuration(self.lines)
		return
	end

	bubble.visible = false
	bubble.cooldownTimer = COOLDOWN
end

function Story:update(dt)
	Entity.update(self, dt)
	for player, bubble in pairs(self.bubbles) do
		if bubble.cooldownTimer and bubble.cooldownTimer > 0 then
			bubble.cooldownTimer = math.max(0, bubble.cooldownTimer - dt)
		end

		if bubble.visible then
			bubble.revealElapsed = bubble.revealElapsed + dt
			if not playerOverlaps(world, self.collider, player.collider) then
				bubble.visible = false
				bubble.cooldownTimer = COOLDOWN
			end
		end
	end
end

-- draw every visible bubble in screen space: project the entity to screen,
-- size the box from the currently revealed lines, then render the rounded
-- box, border, tail, and centred text. Called from InGameState:draw after
-- map:drawEntities and before the HUD, so bubbles follow the entity through
-- pan/zoom while the text stays readable at any zoom.
function Story:drawBubbleScreen(viewRect)
	if love == nil then
		return
	end

	local tx, ty, sx, sy = viewRect.tx, viewRect.ty, viewRect.sx, viewRect.sy

	for player, bubble in pairs(self.bubbles) do
		if bubble.visible then
			local font = self.font or love.graphics.getFont()
			local lineHeight = font:getHeight()
			local spacing = lineHeight * 1.5
			local measure = function(line) return font:getWidth(line) end
			local visible = wrapLines(visibleText(self.lines, bubble.revealElapsed), measure, MAX_WIDTH)

			-- screenPoint takes a world-space translation; the camera's
			-- tx/ty are screen-space, so fold the scale in first
			local anchorX, anchorY = screenPoint(
				self.collider:getX(),
				self.collider:getY() - self.collider.height * 0.5,
				tx / sx, ty / sy, sx, sy)

			local width = boxWidth(visible, measure)
			local height = boxHeight(#visible, spacing)
			local boxX = anchorX - width / 2
			local boxY = anchorY - height - TAIL_HEIGHT - BOX_GAP
			local sw, sh = love.graphics.getDimensions()
			boxX, boxY = clampToScreen(boxX, boxY, width, height, sw, sh, SCREEN_MARGIN)
			local tail = tailPoints(boxX, boxY, width, height, anchorX, anchorY - BOX_GAP)

			love.graphics.push()
			love.graphics.setFont(font)
			love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
			love.graphics.rectangle('fill', boxX, boxY, width, height, CORNER_RADIUS, CORNER_RADIUS)
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.rectangle('line', boxX, boxY, width, height, CORNER_RADIUS, CORNER_RADIUS)
			love.graphics.polygon('fill', tail[1].x, tail[1].y, tail[2].x, tail[2].y, tail[3].x, tail[3].y)
			love.graphics.setColor(1, 1, 1, 1)
			local textTop = boxY + PADDING
			for i, line in ipairs(visible) do
				-- print's y is the top of the font's line box; with the box sized
				-- to that same line height, ink is centred in each slot
				love.graphics.print(line, boxX + (width - measure(line)) / 2, textTop + (i - 1) * spacing)
			end
			love.graphics.pop()
		end
	end
end

return Story
