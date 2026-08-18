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

-- Ornament scale is authored as an `{x, y}` pair (negative flips that axis,
-- arbitrary values stretch); this is the fallback when a piece omits `scale`.
local UNIT_SCALE = { x = 1, y = 1 }

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
			-- Interstitial ornaments per edge, one list entry per piece, never
			-- tiled. Each entry is `{img, pos, scale?}` where `pos` is the
			-- PERCENTAGE position along the edge (0 = left/top corner,
			-- 1 = right/bottom corner), so authors get exact placement instead
			-- of a derived even interval. `scale` is an `{x, y}` pair (default
			-- `{x=1, y=1}`): negative values flip along that axis, arbitrary
			-- values stretch, and pieces can be sized independently. `corners`
			-- is a subsection inside `ornaments` (they are ornaments too):
			-- four fixed pieces centred on the corners of the frame line, each
			-- with its own optional `scale`.
			ornaments = {
				corners = {
					topLeft = { img = 'res/img/diorama/corner_purple.png', scale = { x = 0.7, y = 0.7 } },
					topRight = { img = 'res/img/diorama/corner_yellow.png', scale = { x = 0.7, y = 0.7 } },
					bottomLeft = { img = 'res/img/diorama/corner_blue.png', scale = { x = 0.7, y = 0.7 } },
					bottomRight = { img = 'res/img/diorama/corner_red.png', scale = { x = 0.7, y = 0.7 } },
				},
				top = {
					{ img = 'res/img/diorama/ornament_top_hero.png', pos = 0.5, scale = { x = 0.5, y = 0.5 } },
					{ img = 'res/img/diorama/diorama_orn_top_c.png', pos = 2 / 3, scale = { x = 1.25, y = 1.25 } },
				},
				bottom = {
					{ img = 'res/img/diorama/diorama_orn_bot_a.png', pos = 1 / 3 },
					{ img = 'res/img/diorama/diorama_orn_bot_b.png', pos = 2 / 3 },
				},
                left = {
    				{ img = 'res/img/diorama/ornament_blue.png', pos = 1 / 4, scale = { x = 0.5, y = 0.5 } },
                    { img = 'res/img/diorama/ornament_smile.png', pos = 0.5,   scale = { x = 0.5, y = 0.5 } },
					{ img = 'res/img/diorama/ornament_blue.png', pos = 3 / 4, scale = { x = 0.5, y = 0.5 } },
				},
                right = {
                    { img = 'res/img/diorama/ornament_blue.png', pos = 1 / 4, scale = { x = 0.5, y = 0.5 } },
					{ img = 'res/img/diorama/ornament_smile.png', pos = 0.5, scale = { x = -0.5, y = 0.5 } },
					{ img = 'res/img/diorama/ornament_blue.png', pos = 3 / 4, scale = { x = 0.5, y = 0.5 } },
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
-- time); ornament slots sit centred on the frame line at their configured
-- percentage (`pos` 0..1) along the edge -- discrete ornaments, never a
-- tiled row.
local function computeFrame(mapW, mapH, config)
	local f = config.frame
	local tile = f.tileSize or 16
	local outset = f.outset or 0

	local cornerOrnaments = {
		topLeft = { x = -outset, y = -outset, img = f.ornaments.corners.topLeft.img, scale = f.ornaments.corners.topLeft.scale },
		topRight = { x = mapW + outset, y = -outset, img = f.ornaments.corners.topRight.img, scale = f.ornaments.corners.topRight.scale },
		bottomLeft = { x = -outset, y = mapH + outset, img = f.ornaments.corners.bottomLeft.img, scale = f.ornaments.corners.bottomLeft.scale },
		bottomRight = { x = mapW + outset, y = mapH + outset, img = f.ornaments.corners.bottomRight.img, scale = f.ornaments.corners.bottomRight.scale },
	}

	local edges = {
		top = { fixed = -outset, from = 0, to = mapW },
		bottom = { fixed = mapH + outset, from = 0, to = mapW },
		left = { fixed = -outset, from = 0, to = mapH },
		right = { fixed = mapW + outset, from = 0, to = mapH },
	}

	-- Interstitial ornaments sit centred on the frame line, one per configured
	-- entry, at `pos * edgeLen` along the edge (`pos` is 0..1 along the edge,
	-- 0 = left/top corner, 1 = right/bottom corner). Each entry carries its
	-- own `img` and `scale` straight through to the draw pass.
	local ornamentSlots = {}
	local function buildSlots(edgeLen, list, fixedAxis, fixedValue)
		local slots = {}
		for _, orn in ipairs(list or {}) do
			local coord = (orn.pos or 0) * edgeLen
			if fixedAxis == 'x' then
				table.insert(slots, { x = fixedValue, y = coord, img = orn.img, scale = orn.scale })
			else
				table.insert(slots, { x = coord, y = fixedValue, img = orn.img, scale = orn.scale })
			end
		end
		return slots
	end
	ornamentSlots.top = buildSlots(mapW, f.ornaments.top, 'y', -outset)
	ornamentSlots.bottom = buildSlots(mapW, f.ornaments.bottom, 'y', mapH + outset)
	ornamentSlots.left = buildSlots(mapH, f.ornaments.left, 'x', -outset)
	ornamentSlots.right = buildSlots(mapH, f.ornaments.right, 'x', mapW + outset)

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
			local scale = corner.scale or UNIT_SCALE
			lg.draw(img, corner.x - img:getWidth() * scale.x / 2, corner.y - img:getHeight() * scale.y / 2, 0, scale.x, scale.y)
		end
	end

	-- Interstitial ornaments, over the tiles. Discrete pieces -- one per
	-- configured entry, never tiled, each carrying its own `img` and `scale`.
	for side, slots in pairs(frame.ornamentSlots) do
		for i, slot in ipairs(slots) do
			local img = loadImage(slot.img)
			if img then
				local scale = slot.scale or UNIT_SCALE
				lg.draw(img, slot.x - img:getWidth() * scale.x / 2, slot.y - img:getHeight() * scale.y / 2, 0, scale.x, scale.y)
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
}

return Diorama
