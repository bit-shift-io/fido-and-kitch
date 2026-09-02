-- Shared formatting helpers.

local Format = {}

-- Shared medal color palette used by LevelCompleteState and MapCard.
Format.MEDAL_COLORS = {
	bronze = {0.80, 0.50, 0.20, 1},
	silver = {0.75, 0.75, 0.78, 1},
	gold = {1, 0.86, 0.22, 1},
}

-- Floors seconds (no rounding surprises) and formats as mm:ss.
function Format.time(totalSeconds)
	local seconds = math.floor(totalSeconds or 0)
	local minutes = math.floor(seconds / 60)
	local remainingSeconds = seconds % 60
	return string.format('%02d:%02d', minutes, remainingSeconds)
end

return Format
