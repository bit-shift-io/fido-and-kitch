local ParallaxRenderer = {}
ParallaxRenderer.__index = ParallaxRenderer

local mapParallax = require('src.map.map_parallax')
local lg = love.graphics

function ParallaxRenderer:new()
	return setmetatable({}, ParallaxRenderer)
end

local function clamp(v, lo, hi)
	if lo > hi then return (lo + hi) / 2 end
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

function ParallaxRenderer:drawBackground(map, tx, ty, sx, sy, playerTargets)
	if not lg then return end
	if not map.backgroundMap then return end

	local screenW, screenH = lg.getWidth(), lg.getHeight()

	-- Slide reference: the players' average position (union-bounds midpoint),
	-- which keeps parallax alive even at the zoomed-out view where the camera
	-- center is clamped to map-center. Fall back to the recovered camera
	-- center when no player rects are supplied.
	local cx, cy = mapParallax.computePlayersCenter(playerTargets)
	if not cx then
		cx, cy = mapParallax.computeCameraCenter(tx, ty, sx, sy, screenW, screenH)
	end

	lg.origin()
	lg.setColor(1, 1, 1, 1)

	local mapW = map.map.width * map.map.tilewidth
	local mapH = map.map.height * map.map.tileheight
	local mapDrawW = mapW * sx
	local mapDrawH = mapH * sy

	-- Reference zooms for zoomT, matching Camera.computeFraming semantics:
	-- the full-map view scale (whole map flush to screen) and the closest
	-- view scale (the minimum minViewTiles-tile span).
	local minViewTiles = 6
	local tileSize = 32
	local fullMapScale = math.min(screenW / mapW, screenH / mapH)
	local closestScale = math.min(screenW / (minViewTiles * tileSize), screenH / (minViewTiles * tileSize))
	local zoomT = mapParallax.computeZoomT(sx, fullMapScale, closestScale)
	local allowance = mapParallax.computeAllowance(zoomT)

	local mapCenterX = math.floor(tx) + mapDrawW * 0.5
	local mapCenterY = math.floor(ty) + mapDrawH * 0.5

	-- Parallax backgrounds are "for view in the player world, not outside of
	-- it": clip them to the projected world rect (floored, matching the
	-- drawMainLayers translate) so they never bleed into the Diorama void
	-- strips outside the world. Scissor is set under origin() so its coords
	-- are plain screen coords; restored before returning.
	lg.setScissor(math.floor(tx), math.floor(ty), mapDrawW, mapDrawH)

	for _, layer in ipairs(map.backgroundMap.layers) do
		if layer.visible and layer.type == 'imagelayer' and layer.image and layer.opacity > 0 then
			local parallaxx = layer.parallaxx or 1
			local parallaxy = layer.parallaxy or 1

			local imgW, imgH = layer.image:getWidth(), layer.image:getHeight()
			local s = (1 + allowance) * mapParallax.computeCover(mapW, mapH, imgW, imgH) * sx
			local drawW, drawH = imgW * s, imgH * s

			-- Anchor to world-center-on-screen, then slide proportionally to
			-- the reference position (players' average, or the camera center
			-- fallback; world units → screen via sx/sy). Authored
			-- offsetx/offsety are intentionally discarded.
			local centerX = mapCenterX + mapParallax.computeSlide(allowance, parallaxx, cx, mapW) * sx
			local centerY = mapCenterY + mapParallax.computeSlide(allowance, parallaxy, cy, mapH) * sy

			-- Hard-clamp so the drawn rect always contains the world rect: a
			-- texture edge can never show inside the world. Zero/negative
			-- slack locks the layer to world-center.
			local slackX = (drawW - mapDrawW) * 0.5
			local slackY = (drawH - mapDrawH) * 0.5
			if slackX > 0 then
				centerX = clamp(centerX, mapCenterX - slackX, mapCenterX + slackX)
			else
				centerX = mapCenterX
			end
			if slackY > 0 then
				centerY = clamp(centerY, mapCenterY - slackY, mapCenterY + slackY)
			else
				centerY = mapCenterY
			end

			local drawX = centerX - drawW * 0.5
			local drawY = centerY - drawH * 0.5

			lg.setColor(1, 1, 1, layer.opacity)
			lg.draw(layer.image, drawX, drawY, 0, s, s)
			lg.setColor(1, 1, 1, 1)
		end
	end

	lg.setScissor()
end

function ParallaxRenderer:drawMainLayers(map, tx, ty, sx, sy)
	lg.push()
	lg.origin()
	lg.translate(math.floor(tx or 0), math.floor(ty or 0))
	lg.scale(sx or 1, sy or sx or 1)
	lg.setColor(1, 1, 1, 1)

	for _, layer in ipairs(map.layers) do
		if layer.visible and layer.opacity > 0 then
			if layer.type == 'tilelayer' or layer.type == 'imagelayer' then
				map:drawLayer(layer)
			elseif layer.type == 'objectgroup' and layer.batches and #layer.entities == 0 then
				-- tile-gid imagery in a decorative object layer (images placed
				-- as tile objects in Tiled). Draw only the STI sprite batches
				-- built by setObjectSpriteBatches -- never the grey debug
				-- shapes drawObjectLayer renders. Layers that spawned runtime
				-- entities (e.g. cages/keys authored as gid objects) are drawn
				-- by Map:drawEntities, so skip them to avoid double-drawing
				-- the same gid art.
				for _, batch in pairs(layer.batches) do
					lg.setColor(1, 1, 1, layer.opacity)
					lg.draw(batch, 0, 0)
					lg.setColor(1, 1, 1, 1)
				end
			end
		end
	end

	lg.pop()
end

function ParallaxRenderer:draw(map, tx, ty, sx, sy, playerTargets)
	self:drawBackground(map, tx, ty, sx, sy, playerTargets)
	self:drawMainLayers(map, tx, ty, sx, sy)
end

return ParallaxRenderer