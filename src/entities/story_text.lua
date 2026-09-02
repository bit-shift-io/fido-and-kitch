-- src/entities/story_text.lua
-- Pure decision helpers (and constants) for the Story speech-bubble hotspot,
-- extracted from src/entities/story.lua so the typewriter ramp, cooldown gate,
-- overlap check, bubble geometry, and word wrap live apart from the entity
-- methods. No love.graphics/entity dependencies: the measure(line) callback is
-- injected, world lookups pass the world in explicitly. Exposed to
-- tests/unit/story_test.lua through Story._internal (which references these
-- same functions).
local StoryText = {}

StoryText.CONST = {
	LETTER_COUNT = 4,
	LETTER_RATE = 25.6,
	WORD_PHASE = 0.234375,
	COOLDOWN = 0.5,
	PADDING = 12,
	CORNER_RADIUS = 3,
	MAX_WIDTH = 500,
	TAIL_HEIGHT = 8,
	TAIL_WIDTH = 16,
	BOX_GAP = 4,
	SCREEN_MARGIN = 4,
}

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
	if len <= StoryText.CONST.LETTER_COUNT then
		return len / StoryText.CONST.LETTER_RATE
	end
	return StoryText.CONST.LETTER_COUNT / StoryText.CONST.LETTER_RATE + StoryText.CONST.WORD_PHASE
end

-- how many characters of `line` are visible at time `t` (per-line clock):
-- 1 char at t=0, letter-by-letter through the letter phase, then the rest of
-- the line over the word phase
local function revealedCount(line, t)
	local len = #line
	if len <= StoryText.CONST.LETTER_COUNT then
		return math.min(math.floor(t * StoryText.CONST.LETTER_RATE) + 1, len)
	end

	local letterPhase = StoryText.CONST.LETTER_COUNT / StoryText.CONST.LETTER_RATE
	if t < letterPhase then
		return math.min(math.floor(t * StoryText.CONST.LETTER_RATE) + 1, StoryText.CONST.LETTER_COUNT)
	end

	-- word phase: the word holding the LETTER_COUNT-th character completes at
	-- the start of the phase, then the remaining characters reveal linearly
	local firstWordEnd = 0
	local cumulative = 0
	for word in string.gmatch(line, '%S+') do
		cumulative = cumulative + #word
		if firstWordEnd == 0 and cumulative >= StoryText.CONST.LETTER_COUNT then
			firstWordEnd = cumulative
			break
		end
	end

	local tail = len - firstWordEnd
	if tail <= 0 then
		return len
	end

	local tailRevealed = math.min(math.floor(((t - letterPhase) / StoryText.CONST.WORD_PHASE) * tail), tail)
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
	return width + 2 * StoryText.CONST.PADDING
end

local function boxHeight(lineCount, lineHeight)
	return lineCount * lineHeight + 2 * StoryText.CONST.PADDING
end

-- three tail points connecting the box's bottom centre down to the anchor
local function tailPoints(x, y, w, h, anchorX, anchorY)
	local cx = x + w / 2
	local baseY = y + h
	local tailWidth = StoryText.CONST.TAIL_WIDTH
	return {
		{ x = cx - tailWidth / 2, y = baseY },
		{ x = cx + tailWidth / 2, y = baseY },
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

StoryText.typewriter = {
	splitLines = splitLines,
	lineDuration = lineDuration,
	revealedCount = revealedCount,
	totalDuration = totalDuration,
	isFullyRevealed = isFullyRevealed,
	visibleText = visibleText,
}
StoryText.cooldown = {
	canShow = canShow,
}
StoryText.playerOverlaps = playerOverlaps
StoryText.wrap = {
	wrapLine = wrapLine,
	wrapLines = wrapLines,
}
StoryText.bubble = {
	screenPoint = screenPoint,
	boxWidth = boxWidth,
	boxHeight = boxHeight,
	tailPoints = tailPoints,
	clampToScreen = clampToScreen,
}

return StoryText
