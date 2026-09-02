-- Stretched, solid-colour beam-segment renderer for src/entities/laser.lua's
-- power-up telegraph (slice 04).
--
-- Deliberately NOT src/fx/mesh_ribbon_emitter.lua: that module is built for
-- a fading, velocity-extruded trail with a lifetime/trim model -- a laser
-- beam is a static segment between two known, possibly-instantly-changing
-- points, held indefinitely while 'on'. This is a small dedicated
-- stretched-rectangle draw instead.
--
-- No real sprite-sheet texture exists for the beam (see laser.lua's file
-- header for why) -- `frame` is a plain {width, color} data table, not a
-- Quad/Image, so this draws a solid-colour rectangle sized/coloured
-- entirely from that frame rather than a tiled/wrapped texture. Width and
-- colour both come from the caller's frame -- no lerp, no computation here.
local Headless = require('src.utils.headless')

local LaserBeam = {}

-- x1,y1 -> x2,y2: the beam's two endpoints. frame: {width, color={r,g,b}},
-- one entry from laser.lua's POWER_FRAMES, indexed by the current power
-- timeline position.
function LaserBeam.draw(x1, y1, x2, y2, frame)
	if Headless.isGraphics() then
		return
	end
	if frame == nil then
		return
	end

	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)
	if length <= 0 then
		return
	end
	local angle = math.atan2(dy, dx)

	-- Additive blend while drawing, restored immediately after -- see the
	-- guard below for tests/support/love_mock.lua, which defines neither
	-- setBlendMode nor getBlendMode.
	local blendSupported = love.graphics.setBlendMode ~= nil
	local previousBlendMode
	if blendSupported then
		previousBlendMode = love.graphics.getBlendMode()
		love.graphics.setBlendMode('add')
	end

	local r, g, b, a = love.graphics.getColor()
	love.graphics.setColor(frame.color[1], frame.color[2], frame.color[3], 1)

	love.graphics.push()
	love.graphics.translate(x1, y1)
	love.graphics.rotate(angle)
	love.graphics.rectangle('fill', 0, -frame.width * 0.5, length, frame.width)
	love.graphics.pop()

	love.graphics.setColor(r, g, b, a)
	if blendSupported then
		love.graphics.setBlendMode(previousBlendMode)
	end
end

-- Draws every segment of a (possibly mirror-bounced) resolved beam path as
-- one continuous bent beam -- each segment is already additive-blended and
-- reset independently by LaserBeam.draw above, so overlapping segment
-- joints (a bounce point) just look like more of the same beam. `segments`
-- is src/entities/laser_beam_resolver.lua's ordered {x1,y1,x2,y2} array,
-- from the emitter outward.
function LaserBeam.drawSegments(segments, frame)
	if segments == nil then
		return
	end
	for _, segment in ipairs(segments) do
		LaserBeam.draw(segment.x1, segment.y1, segment.x2, segment.y2, frame)
	end
end

return LaserBeam
