-- Tint component: recolor an entity's sprite art to a target color the
-- "colorize" way (hue/saturation) instead of LÖVE's plain multiply, so a
-- grayscale texture shaded to the target hue renders vibrant rather than
-- washed half-way to black by texture * color. Slots into the same
-- draw()/postDraw() color-state discipline as FlashEffect: Tint sets the
-- graphics color (and the recolor shader), every Sprite added AFTER this
-- component (see Entity:draw's two-pass loop and the ordering comments in
-- pickup_prop.lua / player.lua / npc_base.lua) draws inside that span, and
-- postDraw() resets both.
--
-- The fragment shader replaces each texel's hue with the target hue,
-- boosts saturation to the target's, and keeps the texel's own luminance
-- (value) so the cloth/key shading survives -- exactly GIMP's Colorize, and
-- what "match the keys" needs (entity_key.png is authored grayscale for this).
-- Falls back to the old love.graphics.setColor multiply when no GPU shader
-- is available (headless tests, ancient GL) -- same colors, just duller.
local Color = require('src.utils.color')

local Tint = Class{}

local function isHeadless()
	return not (love and love.graphics)
end

local SHADER_SOURCE = [[
extern vec3 uTargetHSV;

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
	vec4 texel = Texel(texture, texture_coords);
	float luma = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rgb = hsv2rgb(vec3(uTargetHSV.x, uTargetHSV.y, clamp(luma * uTargetHSV.z, 0.0, 1.0)));
	return vec4(rgb, texel.a) * color;
}
]]

function Tint:init(props)
	self.type = 'tint'
	self.color = props.color or {1, 1, 1, 1}

	self.hsv = {}
	self.hsv[1], self.hsv[2], self.hsv[3] = Color.rgbToHsv(self.color[1], self.color[2], self.color[3])

	self.shader = nil
	if not isHeadless() and love.graphics.newShader then
		local ok, shader = pcall(love.graphics.newShader, SHADER_SOURCE)
		if ok then
			self.shader = shader
			shader:send('uTargetHSV', self.hsv)
		end
	end
end

function Tint:update(dt)
	-- no-op
end

function Tint:draw()
	if self.shader then
		-- The shader does the recolor; keep the global color white so its
		-- alpha still multiplies (a setColor(1,1,1,x) fade style would work).
		love.graphics.setShader(self.shader)
		love.graphics.setColor(1, 1, 1, 1)
	else
		love.graphics.setColor(self.color)
	end
end

function Tint:postDraw()
	if self.shader then
		love.graphics.setShader()
	end
	love.graphics.setColor(1, 1, 1, 1)
end

return Tint