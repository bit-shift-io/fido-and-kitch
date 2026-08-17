-- Diorama: world-edge frame & void fill.
--
-- When the camera's view rect extends past the map bounds (wide/tall
-- screens), the screen shows empty strips outside the projected world rect.
-- Diorama draws a generic tiling background in those strips (screen space,
-- scissored to the 4 strips) and a decorative world-space frame -- edge
-- tiles + 4 corner ornaments + interstitial ornaments -- sitting on a frame
-- line pushed `frame.outset` out from the world boundary, so the playfield
-- reads as a framed diorama. Fully deterministic: one global config, no
-- seeds, no randomization.
--
-- Render layering (InGameState:draw): void tiling -> parallax background
-- (scissored to the world rect) -> world tiles -> frame -> entities.
--
-- All pure geometry lives behind Diorama._internal for headless unit tests
-- (no love.* at module scope); draw methods no-op gracefully without
-- love.graphics, and missing art is skipped with a memoized Log.warn so the
-- game runs before the assets land.
local AssetManager = require('src.utils.asset_manager')
local Log = require('src.utils.log')

local Diorama = {}

Diorama.config = {
		void = { img = 'res/img/diorama/diorama_void.png' },
		frame = {
			-- Width of the tiling band (world px). A tile texture is mapped so
			-- its thickness dimension fills this width 1:1 (scale == 1 when the
			-- art is authored at exactly this width) and its long dimension runs
			-- along the edge, repeating until the whole edge is tiled.
			tileSize = 32,
			-- How far out from the world boundary the frame line is pushed
			-- (world px). The band sits centred on that line, so a default of
			-- tileSize/2 parks the frame flush on the border without overlapping
			-- the playfield much.
			outset = 14,
			tiles = {
				top = 'res/img/diorama/diorama_frame_horizontal.png',
				bottom = 'res/img/diorama/diorama_frame_horizontal.png',
				left = 'res/img/diorama/diorama_frame_vertical.png',
				right = 'res/img/diorama/diorama_frame_vertical.png',
			},
			-- A small FIXED number of interstitial ornaments per edge (not a
			-- spacing-driven row): `count` pieces at even intervals along the
			-- edge, inset from the corners, each drawn from the weighted `items`
			-- pool deterministically. No tiling -- each side places exactly
			-- `count` discrete ornaments. Each item may carry a per-ornament
			-- `scale` (default 1) so individual pieces can be sized independently.
			-- `corners` is a subsection inside `ornaments` (they are ornaments
			-- too): four fixed pieces centred on the corners of the frame line,
			-- each with its own optional `scale`.
			ornaments = {
				corners = {
					topLeft = { img = 'res/img/diorama/corner_purple.png', scale = 0.7 },
					topRight = { img = 'res/img/diorama/corner_yellow.png', scale = 0.7 },
					bottomLeft = { img = 'res/img/diorama/corner_blue.png', scale = 0.7 },
					bottomRight = { img = 'res/img/diorama/corner_red.png', scale = 0.7 },
				},
				top = {
					count = 2,
					items = {
						{ img = 'res/img/diorama/ornament_top_hero.png', weight = 0.5, scale = 0.5 },
						{ img = 'res/img/diorama/diorama_orn_top_b.png', weight = 0.3, scale = 0.2 },
						{ img = 'res/img/diorama/diorama_orn_top_c.png', weight = 0.3, scale = 1.25 },
					},
				},
				bottom = {
					count = 2,
					items = {
						{ img = 'res/img/diorama/diorama_orn_bot_a.png', weight = 0.5, scale = 1 },
						{ img = 'res/img/diorama/diorama_orn_bot_b.png', weight = 0.5, scale = 1 },
					},
				},
				left = {
					count = 1,
                    items = {
                        { img = 'res/img/diorama/ornament_blue.png',  weight = 0.25, scale = 0.5 },
                        { img = 'res/img/diorama/ornament_smile.png', weight = 0.5, scale = 0.5 },
						{ img = 'res/img/diorama/ornament_blue.png', weight = 0.75, scale = 0.5 },
					},
				},
				right = {
					count = 2,
					items = {
						{ img = 'res/img/diorama/ornament_blue.png', weight = 0.25, scale = 0.5 },
                        { img = 'res/img/diorama/ornament_smile.png', weight = 0.5, scale = 0.5 },
						{ img = 'res/img/diorama/ornament_blue.png', weight = 0.75, scale = 0.5 },
					},
				},
			},
		},
	}

-- The projected world rect in screen coordinates. Must match how the world is
-- actually drawn: ParallaxRenderer:drawMainLayers translates by
-- floor(tx), floor(ty) then scales, so the rect origin is FLOORED (a hairline
-- strip would otherwise show through at fractional tx/ty).
local function worldScreenRect(tx, ty, sx, sy, mapW, mapH)
	return {
		x = math.floor(tx),
		y = math.floor(ty),
		w = mapW * sx,
		h = mapH * sy,
	}
end

-- The 4 screen-space strips outside the world rect: full-height left/right
-- strips plus width-restricted top/bottom strips. Union == screen minus
-- world rect, with no overlap and no zero-size entries.
local function computeVoidRects(screenW, screenH, wr)
	local rects = {}

	local rightX = wr.x + wr.w
	local bottomY = wr.y + wr.h

	if wr.x > 0 then
		table.insert(rects, { x = 0, y = 0, w = wr.x, h = screenH })
	end
	if rightX < screenW then
		table.insert(rects, { x = rightX, y = 0, w = screenW - rightX, h = screenH })
	end
	if wr.y > 0 then
		table.insert(rects, { x = wr.x, y = 0, w = wr.w, h = wr.y })
	end
	if bottomY < screenH then
		table.insert(rects, { x = wr.x, y = bottomY, w = wr.w, h = screenH - bottomY })
	end

	return rects
end

-- Deterministic weighted ornament distribution for one edge. slotCount slots
-- are handed out proportionally to the pool weights (largest-remainder), then
-- interleaved evenly by fractional position so the pattern looks natural.
-- Same input always yields the same output -- no seed, no randomization.
local function assignOrnaments(pool, slotCount)
	local out = {}
	if slotCount <= 0 or not pool or #pool == 0 then
		return out
	end

	local total = 0
	for _, p in ipairs(pool) do
		total = total + p.weight
	end
	if total <= 0 then
		return out
	end

	local counts = {}
	local remainders = {}
	local allocated = 0
	for i, p in ipairs(pool) do
		local exact = slotCount * p.weight / total
		local c = math.floor(exact)
		counts[i] = c
		remainders[i] = exact - c
		allocated = allocated + c
	end

	local order = {}
	for i = 1, #pool do
		order[i] = i
	end
	table.sort(order, function(a, b)
		return remainders[a] > remainders[b]
	end)
	local k = 1
	while allocated < slotCount do
		counts[order[k]] = counts[order[k]] + 1
		k = k + 1
		allocated = allocated + 1
	end

	local placements = {}
	for i, p in ipairs(pool) do
		local c = counts[i]
		if c > 0 then
			local step = slotCount / c
			for j = 0, c - 1 do
				table.insert(placements, { pos = (j + 0.5) * step, index = i })
			end
		end
	end
	table.sort(placements, function(a, b)
		if math.abs(a.pos - b.pos) > 1e-9 then
			return a.pos < b.pos
		end
		return a.index < b.index
	end)
	for i, pl in ipairs(placements) do
		out[i] = pool[pl.index]
	end
	return out
end

-- How many tile repeats cover an edge span. Tiles the WHOLE length: the
-- count is ceil'd so the last repeat overruns the far corner and is covered
-- by the corner ornament drawn on top (no gap at the end of the edge).
local function computeTileCount(edgeLen, tileLen)
	if tileLen <= 0 then
		return 0
	end
	return math.ceil(edgeLen / tileLen)
end

-- Frame geometry in world space. The frame band sits on a line pushed
-- `outset` px out from the world boundary (into the void), so the frame
-- hugs the border instead of overlapping the playfield. Corner ornaments sit
-- centred on the 4 corners of that line; edge tiles run the full edge span
-- (the repeat step is the tile texture's long dimension, decided at draw
-- time); ornament slots are a fixed small `count` per edge at even intervals,
-- inset from the corners, centred on the frame line -- discrete ornaments,
-- never a tiled row.
local function computeFrame(mapW, mapH, config)
	local f = config.frame
	local tile = f.tileSize or 16
	local outset = f.outset or 0

	local cornerOrnaments = {
		topLeft = { x = -outset, y = -outset, img = f.ornaments.corners.topLeft.img, scale = f.ornaments.corners.topLeft.scale or 1 },
		topRight = { x = mapW + outset, y = -outset, img = f.ornaments.corners.topRight.img, scale = f.ornaments.corners.topRight.scale or 1 },
		bottomLeft = { x = -outset, y = mapH + outset, img = f.ornaments.corners.bottomLeft.img, scale = f.ornaments.corners.bottomLeft.scale or 1 },
		bottomRight = { x = mapW + outset, y = mapH + outset, img = f.ornaments.corners.bottomRight.img, scale = f.ornaments.corners.bottomRight.scale or 1 },
	}

	local edges = {
		top = { fixed = -outset, from = 0, to = mapW },
		bottom = { fixed = mapH + outset, from = 0, to = mapW },
		left = { fixed = -outset, from = 0, to = mapH },
		right = { fixed = mapW + outset, from = 0, to = mapH },
	}

	-- `count` ornament slots at even intervals along an edge, inset from the
	-- corners (positions edgeLen/(count+1), 2*edgeLen/(count+1), ...).
	local ornamentSlots = {}
	local function buildSlots(edgeLen, count, fixedAxis, fixedValue)
		local slots = {}
		for i = 1, count do
			local coord = i * edgeLen / (count + 1)
			if fixedAxis == 'x' then
				table.insert(slots, { x = fixedValue, y = coord })
			else
				table.insert(slots, { x = coord, y = fixedValue })
			end
		end
		return slots
	end
	ornamentSlots.top = buildSlots(mapW, f.ornaments.top.count, 'y', -outset)
	ornamentSlots.bottom = buildSlots(mapW, f.ornaments.bottom.count, 'y', mapH + outset)
	ornamentSlots.left = buildSlots(mapH, f.ornaments.left.count, 'x', -outset)
	ornamentSlots.right = buildSlots(mapH, f.ornaments.right.count, 'x', mapW + outset)

	return {
		cornerOrnaments = cornerOrnaments,
		edges = edges,
		ornamentSlots = ornamentSlots,
	}
end

local warned = {}

-- Load a config image, skipping gracefully (memoized Log.warn once per path)
-- when the art does not exist yet. A pre-seeded AssetManager.textures entry
-- (e2e placeholders) wins so geometry can be verified before real art lands.
local function loadImage(path)
	if not love or not love.graphics then
		return nil
	end
	if AssetManager.textures[path] then
		return AssetManager.textures[path]
	end
	if not love.filesystem or love.filesystem.getInfo(path) == nil then
		if not warned[path] then
			warned[path] = true
			Log.warn('Diorama image not found: ' .. path)
		end
		return nil
	end
	return AssetManager.getImage(path)
end

-- Screen-space void fill: the tiling background drawn only in the strips
-- outside the projected world rect. Tiled from the screen origin (fixed to
-- the screen, not scrolling, not aligned to the world grid), scissored per
-- strip. Call under no pushed transform (the world rect is in plain screen
-- coords).
function Diorama.drawVoid(tx, ty, sx, sy, mapW, mapH)
	local lg = love and love.graphics
	if not lg then
		return
	end

	local screenW, screenH = lg.getWidth(), lg.getHeight()
	local wr = worldScreenRect(tx, ty, sx, sy, mapW, mapH)
	local rects = computeVoidRects(screenW, screenH, wr)
	if #rects == 0 then
		return
	end

	local img = loadImage(Diorama.config.void.img)
	if not img then
		return
	end
	local iw, ih = img:getWidth(), img:getHeight()

	lg.push()
	lg.origin()
	lg.setColor(1, 1, 1, 1)
	for _, r in ipairs(rects) do
		lg.setScissor(r.x, r.y, r.w, r.h)
		local startX = math.floor(r.x / iw) * iw
		local startY = math.floor(r.y / ih) * ih
		for y = startY, r.y + r.h - 1, ih do
			for x = startX, r.x + r.w - 1, iw do
				lg.draw(img, x, y)
			end
		end
	end
	lg.setScissor()
	lg.pop()
end

-- World-space frame: tiled edges first (behind the ornaments), then corner
-- ornaments, then interstitial ornaments, all centred on the frame line
-- (pushed `outset` out from the world boundary). Mirrors
-- ParallaxRenderer:drawMainLayers' transform (push / origin / translate
-- floor(tx),floor(ty) / scale) so the frame zooms with the world.
--
-- Each edge's texture is drawn with its short dimension mapped to
-- frame.tileSize (the tiling section's width) and its long dimension running
-- along the edge, repeating until the whole edge span is covered -- so a
-- texture authored at tileSize maps 1:1 and tiles the FULL edge, no partial
-- leftover. Textures are authored landscape for top/bottom edges and portrait
-- for left/right edges.
function Diorama.drawFrame(tx, ty, sx, sy, mapW, mapH)
	local lg = love and love.graphics
	if not lg then
		return
	end

	local frame = computeFrame(mapW, mapH, Diorama.config)
	local config = Diorama.config.frame
	local tile = config.tileSize or 16

	lg.push()
	lg.origin()
	lg.translate(math.floor(tx), math.floor(ty))
	lg.scale(sx, sy)
	lg.setColor(1, 1, 1, 1)

	-- Tiled edges, behind the ornaments.
	for side, edge in pairs(frame.edges) do
		local img = loadImage(config.tiles[side])
		if img then
			local iw, ih = img:getWidth(), img:getHeight()
			local vertical = side == 'left' or side == 'right'
			local thickness = vertical and iw or ih
			local along = vertical and ih or iw
			local scale = tile / thickness
			local tileLen = along * scale
			local count = computeTileCount(edge.to - edge.from, tileLen)
			for i = 0, count - 1 do
				local pos = edge.from + i * tileLen
				if vertical then
					lg.draw(img, edge.fixed - iw * scale / 2, pos, 0, scale, scale)
				else
					lg.draw(img, pos, edge.fixed - ih * scale / 2, 0, scale, scale)
				end
			end
		end
	end

	-- Corner ornaments (they are ornaments too), over the tiles. Each carries
	-- its own scale like the interstitial ornaments.
	for _, corner in pairs(frame.cornerOrnaments) do
		local img = loadImage(corner.img)
		if img then
			local scale = corner.scale or 1
			lg.draw(img, corner.x - img:getWidth() * scale / 2, corner.y - img:getHeight() * scale / 2, 0, scale, scale)
		end
	end

	-- Interstitial ornaments, over the tiles. Discrete pieces -- one per slot,
	-- never tiled. Each item carries its own scale.
	for side, slots in pairs(frame.ornamentSlots) do
		local items = config.ornaments[side].items
		local chosen = assignOrnaments(items, #slots)
		for i, slot in ipairs(slots) do
			local item = chosen[i]
			local img = loadImage(item.img)
			if img then
				local scale = item.scale or 1
				lg.draw(img, slot.x - img:getWidth() * scale / 2, slot.y - img:getHeight() * scale / 2, 0, scale, scale)
			end
		end
	end

	lg.pop()
end

-- White-box seam for tests/unit/diorama_test.lua only -- see drawbridge.lua's
-- equivalent comment. Not for use by production code.
Diorama._internal = {
	worldScreenRect = worldScreenRect,
	computeVoidRects = computeVoidRects,
	computeTileCount = computeTileCount,
	computeFrame = computeFrame,
	assignOrnaments = assignOrnaments,
}

return Diorama
