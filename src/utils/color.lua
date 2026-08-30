-- Pure color math shared by the tint pipeline (src/components/tint.lua).
-- Kept separate from love.graphics so the conversions are unit-testable
-- headless and the shader path only ever sees numbers.
local Color = {}

-- r, g, b in 0..1. Returns h (0..1, red=0), s (0..1), v (0..1).
function Color.rgbToHsv(r, g, b)
	local max = math.max(r, g, b)
	local min = math.min(r, g, b)
	local d = max - min

	local h = 0
	if d ~= 0 then
		if max == r then
			h = ((g - b) / d) % 6
		elseif max == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h = h / 6
	end

	local s = max == 0 and 0 or d / max
	return h, s, max
end

return Color