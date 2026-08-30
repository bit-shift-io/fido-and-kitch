-- Utility math functions for the game.

local NumberUtils = {}

--- Clamp v between lo and hi, tolerant of lo > hi.
--- @param v number
--- @param lo number
--- @param hi number
--- @return number clamped value
local function clamp(v, lo, hi)
    if lo > hi then
        return (lo + hi) / 2
    end
    if v < lo then
        return lo
    end
    if v > hi then
        return hi
    end
    return v
end

NumberUtils.clamp = clamp

return NumberUtils
