-- src/ui/sprite_outline_overlay.lua — F2 debug mode: draws a wireframe box
-- around every entity sprite's rendered art, mirroring how F1 (drawphysics)
-- outlines colliders. The box is the actual image quad each Sprite draws
-- (position + scale + offset math copied from Sprite:draw_*), so it tracks
-- the art even for sprites fitted to a Tiled shape via shape_arguments.
-- Toggled by F2 in src/game.lua; gated on conf.draw_sprite_outlines so it is
-- off by default and only engages under real rendering.
local SpriteOutlineOverlay = {}
SpriteOutlineOverlay.__index = SpriteOutlineOverlay

local lg = love.graphics

function SpriteOutlineOverlay:new()
	return setmetatable({ enabled = false }, SpriteOutlineOverlay)
end

-- World-space box of the art a Sprite is about to draw this frame: the
-- current frame's image quad placed at sprite.position with scale/offset.
-- Returns nil when there is nothing to measure (headless placeholders).
local function spriteBox(sprite)
	if not (sprite and sprite.position) then
		return nil
	end
	local frame = sprite.frames and sprite.frames[sprite.frameNum]
	if not frame then
		return nil
	end
	local w, h
	if sprite.image and frame.getViewport then
		-- sheet mode: the frame is a Quad cut out of the shared image
		local _, _, fw, fh = frame:getViewport()
		w, h = fw, fh
	elseif frame.getWidth then
		w, h = frame:getWidth(), frame:getHeight()
	else
		return nil
	end
	local sx, sy = sprite.scale.x, sprite.scale.y
	local ox, oy = sprite.offset.x, sprite.offset.y
	local px, py = sprite.position.x, sprite.position.y
	local x0 = px - ox * sx
	local x1 = px + (w - ox) * sx
	local y0 = py - oy * sy
	local y1 = py + (h - oy) * sy
	return {
		left = math.min(x0, x1),
		top = math.min(y0, y1),
		width = math.abs(x1 - x0),
		height = math.abs(y1 - y0),
	}
end

function SpriteOutlineOverlay:draw(map, players, viewRect)
	if not self.enabled or not conf.draw_sprite_outlines then
		return
	end

	lg.push()
	lg.origin()

	local tx, ty, sx, sy = viewRect.tx or 0, viewRect.ty or 0, viewRect.sx or 1, viewRect.sy or 1
	lg.translate(math.floor(tx), math.floor(ty))
	lg.scale(sx, sy)
	lg.setLineWidth(2 / math.max(sx, sy))

	lg.setColor(0.3, 1, 0.3, 0.8)

	if map and map.layers then
		for _, layer in ipairs(map.layers) do
			if layer.type == "objectgroup" and layer.entities then
				for _, entity in ipairs(layer.entities) do
					local box = spriteBox(entity.sprite)
					if box then
						lg.rectangle("line", box.left, box.top, box.width, box.height)
					end
				end
			end
		end
	end

	if players then
		for _, player in ipairs(players) do
			local box = spriteBox(player.sprite)
			if box then
				lg.setColor(1, 0.6, 0.2, 0.9)
				lg.rectangle("line", box.left, box.top, box.width, box.height)
			end
		end
	end

	lg.pop()
	lg.setColor(1, 1, 1, 1)
end

return SpriteOutlineOverlay
