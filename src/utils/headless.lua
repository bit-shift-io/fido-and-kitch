-- Headless environment detection: returns true when a LÖVE subsystem is
-- absent (headless integration tests, CI, export_png mode). Each variant
-- checks the specific subsystem the caller needs.
local Headless = {}

function Headless.isGraphics()
	return not (love and love.graphics)
end

function Headless.isAudio()
	return not (love and love.audio)
end

return Headless
