-- Frame capture API for the e2e tier: writes a real rendered frame to disk
-- as debugging evidence a human or an AI agent can read afterward, without
-- having been present when the test ran. Shared across tiers so scenario
-- code references Capture.capture(name) uniformly, but only the e2e runner
-- (tests/e2e/run.lua) ever installs a live rendering context -- calling it
-- from the unit/integration tiers is a loud, explicit error naming the e2e
-- tier as the requirement, never a silent no-op (DECISIONS.md Q6/Q13).
local Capture = {}

local context = nil

-- Called only by tests/e2e/run.lua, once per game started under the e2e
-- tier, before any capture can happen. `game` is the object to render;
-- `outputDir` is where this test file's captures land.
function Capture.setContext(game, outputDir)
	context = { game = game, outputDir = outputDir, frameCount = 0 }
	os.execute(string.format('mkdir -p "%s"', outputDir))
end

function Capture.clearContext()
	context = nil
end

function Capture.hasContext()
	return context ~= nil
end

-- Renders the current game state into an offscreen canvas and writes it as
-- a PNG to <outputDir>/<name>.png, returning the path written.
--
-- LÖVE's filesystem writes are normally confined to a save directory, so
-- writing anywhere in the project tree needs a different route: encode the
-- frame's image data in memory (no filename passed to ImageData:encode)
-- and write the raw bytes out with plain Lua file I/O instead
-- (see DECISIONS.md Key Assumptions).
function Capture.capture(name)
	if not context then
		error(
			"Capture.capture() called outside the e2e tier: frame capture needs real rendering, "
				.. "which the unit/integration tiers cannot provide. Move this scenario to tests/e2e/ to use captures.",
			2
		)
	end

	local width = love.graphics.getWidth()
	local height = love.graphics.getHeight()
	local canvas = love.graphics.newCanvas(width, height)

	love.graphics.push("all")
	love.graphics.setCanvas(canvas)
	love.graphics.clear()
	context.game:draw()
	love.graphics.setCanvas()
	love.graphics.pop()

	local imageData = canvas:newImageData()
	local fileData = imageData:encode("png")

	local path = context.outputDir .. "/" .. name .. ".png"
	local file = assert(io.open(path, "wb"))
	file:write(fileData:getString())
	file:close()

	return path
end

return Capture
