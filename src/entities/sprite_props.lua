-- Shared reader that turns an entity's merged Tiled object properties (the
-- template + instance merge from src/map/tmj.lua) into the art fields a
-- Sprite{} constructor expects. Res/entities/<type>.tj templates now carry
-- the sprite data (image, frames, duration, loop, playing, scaleX/scaleY), so
-- entity lua files no longer hard-code art paths -- they splice the result of
-- SpriteProps.fromObject(object) into their Sprite{...} while keeping their
-- own position/shape_arguments/facing/finish computation.
--
-- Only keys present in the properties are returned, so Sprite's own defaults
-- (scale 1,1; playing true; duration 1.0 for a single-frame sheet) keep
-- applying when a template omits a field. scaleX/scaleY (Tiled has no
-- float-pair type) become a Vector.
local SpriteProps = {}

function SpriteProps.fromObject(object)
	local props = (object and object.properties) or {}
	local art = {}

	if props.image ~= nil then
		art.image = props.image
	end
	if props.frames ~= nil then
		art.frames = props.frames
	end
	if props.duration ~= nil then
		art.duration = props.duration
	end
	if props.loop ~= nil then
		art.loop = props.loop
	end
	if props.playing ~= nil then
		art.playing = props.playing
	end
	if props.scaleX ~= nil or props.scaleY ~= nil then
		art.scale = Vector(props.scaleX or 1, props.scaleY or 1)
	end

	return art
end

return SpriteProps
