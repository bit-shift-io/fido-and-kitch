local ParallaxRenderer = {}
ParallaxRenderer.__index = ParallaxRenderer

local mapParallax = require('src.map.map_parallax')
local lg = love.graphics

function ParallaxRenderer:new()
	return setmetatable({}, ParallaxRenderer)
end

function ParallaxRenderer:drawBackground(map, tx, ty, sx, sy)
	if not map.backgroundMap then return end

	local screenW, screenH = lg.getWidth(), lg.getHeight()
	local cx, cy = mapParallax.computeCameraCenter(tx, ty, sx, sy, screenW, screenH)

	lg.origin()
	lg.setColor(1, 1, 1, 1)

	local mapDrawW = map.map.width * map.map.tilewidth * sx
	local mapDrawH = map.map.height * map.map.tileheight * sy

	for _, layer in ipairs(map.backgroundMap.layers) do
		if layer.visible and layer.type == 'imagelayer' and layer.image and layer.opacity > 0 then
			local parallaxx = layer.parallaxx or 1
			local parallaxy = layer.parallaxy or 1

			local mapCenterX = tx + mapDrawW * 0.5
			local mapCenterY = ty + mapDrawH * 0.5
			local offsetX = (1 - parallaxx) * screenW * 0.5 + parallaxx * mapCenterX + (layer.offsetx or 0) * sx
			local offsetY = (1 - parallaxy) * screenH * 0.5 + parallaxy * mapCenterY + (layer.offsety or 0) * sy

			local imgW, imgH = layer.image:getWidth(), layer.image:getHeight()
			local s = math.max(screenW / imgW, screenH / imgH)
			local drawW, drawH = imgW * s, imgH * s

			local drawX = offsetX - drawW * 0.5
			local drawY = offsetY - drawH * 0.5

			lg.setColor(1, 1, 1, layer.opacity)
			lg.draw(layer.image, drawX, drawY, 0, s, s)
			lg.setColor(1, 1, 1, 1)
		end
	end
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

function ParallaxRenderer:draw(map, tx, ty, sx, sy)
	self:drawBackground(map, tx, ty, sx, sy)
	self:drawMainLayers(map, tx, ty, sx, sy)
end

return ParallaxRenderer