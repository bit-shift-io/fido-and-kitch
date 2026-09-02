-- The one shared tint palette for colour-coded props that telegraph to the
-- player which key goes with which lock/flag. Both src/entities/key.lua and
-- src/entities/flag.lua read from here, so a `color` name always maps to the
-- exact same RGBA everywhere -- "flags match the keys" is guaranteed by
-- construction, not by authoring discipline. The values stay in the same
-- low-saturation RGBA form Tint already consumed; the Tint shader converts
-- them to hue for its vibrant recolor.
local KEY_COLORS = {
	red = { 1, 0.2, 0.2, 1 },
	blue = { 0.2, 0.4, 1, 1 },
	yellow = { 1, 0.9, 0.2, 1 },
	green = { 0.2, 0.8, 0.3, 1 },
	purple = { 0.7, 0.3, 1, 1 },
}

local KeyColors = {
	colors = KEY_COLORS,
}

-- Returns the RGBA table for a color name, or nil when unknown (callers
-- decide their own fallback, as key.lua and flag.lua intentionally differ).
function KeyColors.color(name)
	return KEY_COLORS[name]
end

return KeyColors
