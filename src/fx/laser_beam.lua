-- UV-scrolling beam-segment renderer for src/entities/laser.lua's power-up
-- telegraph (slice 04).
--
-- Deliberately NOT src/fx/mesh_ribbon_emitter.lua: that module is built for
-- a fading, velocity-extruded trail with a lifetime/trim model -- a laser
-- beam is a static segment between two known, possibly-instantly-changing
-- points, held indefinitely while 'on'. This is a small dedicated
-- scrolling-UV draw instead.
--
-- The beam texture (res/img/fx/fx_laser_beam.png) is a horizontal energy
-- strip. The beam is ONE quad (one draw call, no per-copy tiling) spanning
-- the whole segment, and its u-coordinate slides with a scroll phase:
--
--   world point w on the beam samples texture pixel
--     (w / scaleX + u0texel) mod imageW
--
-- where scaleX = TILE_LENGTH / imageW (world px per texture pixel) and the
-- texture's wrap mode is 'repeat', so u past the image width samples
-- seamlessly through the art's period. This is standard scrolling-UV tiling:
-- because sampling wraps by the GPU, a scroll offset of one full period IS
-- the same sample -- there is no re-anchoring, no discrete copies, and no
-- instant at which "a whole texture length" pops in or out. The art simply
-- flows past any fixed point, texel by texel, and what crosses a texture
-- boundary is the art's own seam (the user fixes that by making the art
-- tile in the texture itself). u0texel = (phase * SCROLL_SPEED / scaleX) mod
-- imageW -- the mod keeps the floating-point u coordinate bounded; it is
-- content-invisible because sampling is periodic.
--
-- Mirror-bounced segments receive a cumulative world-length offset from
-- drawSegments, so a multi-segment beam is one continuous texture ribbon:
-- the pattern carries across each bounce, never resampling.
--
-- One texture copy spans TILE_LENGTH world px along the beam (scaleX chosen
-- so a full image occupies TILE_LENGTH world px: TILE_LENGTH scaled down
-- from imageW so a room-scale beam shows several repeats), height squished
-- onto the caller's frame.width. Tune TILE_LENGTH (density) and
-- SCROLL_SPEED (flow speed) to taste.
--
-- `frame` stays a plain {width, color={r,g,b}} data table, one entry from
-- laser.lua's POWER_FRAMES; the renderer never computes a width or colour
-- itself (the acceptance criterion is about not procedurally lerping, not
-- about requiring a solid rect).
local AssetManager = require("src.utils.asset_manager")
local Headless = require("src.utils.headless")

local TEXTURE_PATH = "res/img/fx/fx_laser_beam.png"

-- World px each texture copy spans along the beam. 546px of art per copy at
-- 1:1 means a ~640px room-scale beam shows barely over one copy -- reads as
-- a stretched texture -- so the art is re-scaled down to repeat often
-- enough to obviously tile. ~107 = ~3.3 game tiles per repeat -- up from
-- 128 (4 tiles) for ~20% denser tiling.
local TILE_LENGTH = 106.67

-- World px per second the art flows along the beam (toward x2, away from
-- the emitter -- reversed so it follows the beam's travel direction). At
-- 64px/s the whole texture recycles through the beam every TILE_LENGTH /
-- SCROLL_SPEED ~= 1.67s, texel by texel -- no pop.
local SCROLL_SPEED = 64

local LaserBeam = { TILE_LENGTH = TILE_LENGTH, SCROLL_SPEED = SCROLL_SPEED }

-- World px per texture pixel for an image imageW wide occupying a tile
-- TILE_LENGTH world px. Pure math so it stays unit-testable.
function LaserBeam.scaleXFor(imageW, tileLength)
	if tileLength <= 0 or imageW <= 0 then
		return 0
	end
	return tileLength / imageW
end

-- The scrolling u coordinate, as a texture pixel: where the muzzle of the
-- beam samples in the source image after `phase` seconds at `speed` px/s.
-- Negated -- as the phase grows the sample moves DOWN the texture, which
-- pushes a texture feature's world position OUTWARD (+w), i.e. art flows
-- toward x2. Wrapped to one image width -- under 'repeat' sampling a
-- wrapped offset is bit-for-bit the same sample, so the mod only keeps the
-- float bounded; it causes no visual event (unlike a discrete-copy system,
-- where re-anchoring a tile boundary is exactly where a whole texture pops).
function LaserBeam.u0Texel(phase, speed, scaleX, imageW)
	if scaleX <= 0 or imageW <= 0 then
		return 0
	end
	return (-((phase * speed) / scaleX)) % imageW
end

-- Texture pixels the beam's `length` world px wants to show, i.e. the
-- horizontal extent of the quad's u coordinate. Always > 0 for a beam, and
-- > imageW for any beam longer than TILE_LENGTH -- that is the repeat; the
-- quad spans it and wrap-mode sampling tiles it.
function LaserBeam.texelSpan(length, scaleX)
	if scaleX <= 0 then
		return 0
	end
	return length / scaleX
end

-- The texture pixel shown at a point `worldX` along the beam (0 = muzzle)
-- by a window scrolled to u0: (worldX / scaleX + u0) mod imageW. This is
-- exactly what the GPU samples. Contiguity properties (how a fixed point's
-- content changes as u0 advances, how full periods give identical samples)
-- are asserted on this in the unit tests -- they are the "no pop" contract.
function LaserBeam.sampledTexel(worldX, u0, scaleX, imageW)
	if scaleX <= 0 or imageW <= 0 then
		return 0
	end
	return (worldX / scaleX + u0) % imageW
end

-- x1,y1 -> x2,y2: the beam's two endpoints. frame: {width, color={r,g,b}},
-- one entry from laser.lua's POWER_FRAMES, indexed by the current power
-- timeline position. phase: elapsed seconds of scrolling, advanced by
-- laser.lua every update. baseWorld: cumulative world px along the beam
-- polyline before this segment, so the pattern continues across bounces.
function LaserBeam.draw(x1, y1, x2, y2, frame, phase, baseWorld)
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
		love.graphics.setBlendMode("add")
	end

	local r, g, b, a = love.graphics.getColor()
	love.graphics.setColor(frame.color[1], frame.color[2], frame.color[3], 1)

	local image = AssetManager.getImage(TEXTURE_PATH)
	if image == nil then
		-- Missing art falls back to the historic solid-colour rectangle so
		-- the game still runs before the asset lands.
		love.graphics.push()
		love.graphics.translate(x1, y1)
		love.graphics.rotate(angle)
		love.graphics.rectangle("fill", 0, -frame.width * 0.5, length, frame.width)
		love.graphics.pop()
	else
		-- Wrap the texture so u past imageW tiles; on real LÖVE this is a
		-- texture sampler setting. The mock image has no setWrap (and is
		-- never really drawn), so guard it.
		if image.setWrap then
			image:setWrap("repeat", "repeat")
		end

		local imageW, imageH = image:getDimensions()
		local scaleX = LaserBeam.scaleXFor(imageW, TILE_LENGTH)
		local u0 = LaserBeam.u0Texel(phase or 0, SCROLL_SPEED, scaleX, imageW)
		-- the beam continues the polyline's texture from baseWorld
		u0 = u0 + (baseWorld or 0) / scaleX
		local span = LaserBeam.texelSpan(length, scaleX)

		-- One quad spanning the whole segment: u covers u0..u0+span (span
		-- may exceed imageW several times over, which is the tiling), and
		-- horizontal draw scale scaleX maps texels back to world px.
		local quad = love.graphics.newQuad(u0, 0, span, imageH, imageW, imageH)

		love.graphics.push()
		love.graphics.translate(x1, y1)
		love.graphics.rotate(angle)
		love.graphics.draw(image, quad, 0, -frame.width * 0.5, 0, scaleX, frame.width / imageH)
		love.graphics.pop()
	end

	love.graphics.setColor(r, g, b, a)
	if blendSupported then
		love.graphics.setBlendMode(previousBlendMode)
	end
end

-- Draws every segment of a (possibly mirror-bounced) resolved beam path as
-- one continuous bent beam -- each segment carries the cumulative world
-- length before it into the UV window, so the pattern flows seamlessly
-- across a bounce instead of resampling. `segments` is
-- src/entities/laser_beam_resolver.lua's ordered {x1,y1,x2,y2} array, from
-- the emitter outward. Each segment is already additive-blended and reset
-- independently by LaserBeam.draw above, so overlapping joints just look
-- like more of the same beam.
function LaserBeam.drawSegments(segments, frame, phase)
	if segments == nil then
		return
	end
	local baseWorld = 0
	for _, segment in ipairs(segments) do
		LaserBeam.draw(segment.x1, segment.y1, segment.x2, segment.y2, frame, phase, baseWorld)
		local dx, dy = segment.x2 - segment.x1, segment.y2 - segment.y1
		baseWorld = baseWorld + math.sqrt(dx * dx + dy * dy)
	end
end

return LaserBeam