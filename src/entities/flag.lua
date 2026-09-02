-- A purely decorative flag. It has no collider and no behaviour -- its whole
-- purpose is to be tinted to a key's color (res/entities/flag.tj's `color`
-- string prop, resolved through key_colors.lua -- the SAME palette as keys,
-- so players read "which key/flag are which" at a glance). Single-frame art
-- for now; waving/fluttering animation is a later concern and the template
-- already carries the frames/duration/loop spec so it can animate without a
-- code change.
--
-- Tint must be added BEFORE the Sprite (see the ordering discipline in
-- Entity:draw's two-pass loop): the Tint draw()/postDraw() brackets every
-- Sprite added after it. One Sprite on one renderOrder means this entity is
-- always a single atomic draw unit -- no render-order split, so the tint
-- never trips the unsupported-split warning.
local Tint = require("src.components.tint")
local SpriteProps = require("src.entities.sprite_props")
local KeyColors = require("src.entities.key_colors")

local Flag = Class({ __includes = Entity })

function Flag:init(object)
	Entity.init(self, object, "flag")

	local props = object.properties or {}
	local colorName = props.color or "red"
	local position = Rect.centreOfMapObject(object)
	local shape_arguments = Rect.shapeArgs(object.width, object.height)
	-- `spriteOffsetY` (px, positive = down) nudges only the art, tuned from
	-- the piece's authored box, exactly the cage/exit_door/blocker pattern.
	local spriteOffsetY = tonumber(props.spriteOffsetY) or 0

	self:addComponent(Tint({ color = KeyColors.color(colorName) or KeyColors.colors.red }), "tint")

	local art = SpriteProps.fromObject(object)
	art.position = position + Vector(0, spriteOffsetY)
	art.shape_arguments = shape_arguments
	self:addComponent(Sprite(art), "sprite")
end

return Flag
