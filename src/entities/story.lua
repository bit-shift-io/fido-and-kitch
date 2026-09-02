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
-- bubble geometry, word wrap) live in src/entities/story_text.lua and are
-- reached by tests/unit/story_test.lua through the `_internal` white-box seam
-- below -- same pattern as src/entities/drawbridge.lua. Only
-- drawBubbleScreen touches love.graphics.

local Story = Class{__includes = Entity}
local SpriteProps = require('src.entities.sprite_props')
local StoryText = require('src.entities.story_text')

local CONST = StoryText.CONST
local splitLines = StoryText.typewriter.splitLines
local totalDuration = StoryText.typewriter.totalDuration
local isFullyRevealed = StoryText.typewriter.isFullyRevealed
local visibleText = StoryText.typewriter.visibleText
local canShow = StoryText.cooldown.canShow
local playerOverlaps = StoryText.playerOverlaps
local screenPoint = StoryText.bubble.screenPoint
local boxWidth = StoryText.bubble.boxWidth
local boxHeight = StoryText.bubble.boxHeight
local clampToScreen = StoryText.bubble.clampToScreen
local tailPoints = StoryText.bubble.tailPoints
local wrapLines = StoryText.wrap.wrapLines

Story._internal = {
	CONST = StoryText.CONST,
	typewriter = StoryText.typewriter,
	cooldown = StoryText.cooldown,
	playerOverlaps = StoryText.playerOverlaps,
	wrap = StoryText.wrap,
	bubble = StoryText.bubble,
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
	bubble.cooldownTimer = CONST.COOLDOWN
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
				bubble.cooldownTimer = CONST.COOLDOWN
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
			local visible = wrapLines(visibleText(self.lines, bubble.revealElapsed), measure, CONST.MAX_WIDTH)

			-- screenPoint takes a world-space translation; the camera's
			-- tx/ty are screen-space, so fold the scale in first
			local anchorX, anchorY = screenPoint(
				self.collider:getX(),
				self.collider:getY() - self.collider.height * 0.5,
				tx / sx, ty / sy, sx, sy)

			local width = boxWidth(visible, measure)
			local height = boxHeight(#visible, spacing)
			local boxX = anchorX - width / 2
			local boxY = anchorY - height - CONST.TAIL_HEIGHT - CONST.BOX_GAP
			local sw, sh = love.graphics.getDimensions()
			boxX, boxY = clampToScreen(boxX, boxY, width, height, sw, sh, CONST.SCREEN_MARGIN)
			local tail = tailPoints(boxX, boxY, width, height, anchorX, anchorY - CONST.BOX_GAP)

			love.graphics.push()
			love.graphics.setFont(font)
			love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
			love.graphics.rectangle('fill', boxX, boxY, width, height, CONST.CORNER_RADIUS, CONST.CORNER_RADIUS)
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.rectangle('line', boxX, boxY, width, height, CONST.CORNER_RADIUS, CONST.CORNER_RADIUS)
			love.graphics.polygon('fill', tail[1].x, tail[1].y, tail[2].x, tail[2].y, tail[3].x, tail[3].y)
			love.graphics.setColor(1, 1, 1, 1)
			local textTop = boxY + CONST.PADDING
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
