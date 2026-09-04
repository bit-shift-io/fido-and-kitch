-- Auto-zoom camera: frames all players (plus transient extra targets like a
-- dying player's respawn point), zooming/panning smoothly between a min 6x6
-- tile view (DEFAULT_MIN_VIEW_TILES) and the full map. Pure Lua (no love.*
-- calls) so the framing and smoothing math run under the headless test
-- runner; InGameState supplies screen/map size and reads back draw params
-- each frame.
local Camera = {}
Camera.__index = Camera

--- A structured record bundling the4 values that describe the current
--- camera projection. Every draw call that needs to position world-space
--- content on screen accepts a single ViewRect instead of four loose
--- positional args, eliminating order-slip bugs.
---   tx, ty  — top-left corner of the projected world rect (screen px)
---   sx, sy  — scale factors (always equal; stored as a pair for API compat)
local ViewRect = { tx = 0, ty = 0, sx = 1, sy = 1 }
ViewRect.__index = ViewRect

function ViewRect.new(tx, ty, sx, sy)
	return setmetatable({ tx = tx or 0, ty = ty or 0, sx = sx or 1, sy = sy or sx or 1 }, ViewRect)
end

local DEFAULT_MARGIN_TILES = 6
local DEFAULT_MIN_VIEW_TILES = 6
local DEFAULT_TILE_SIZE = 32
-- exponential decay rate; ~5 half-lives (1 - e^-6 ~= 0.9975) settle inside 0.5s
local DEFAULT_DECAY = 12

-- Shared constants for modules that mirror camera framing semantics
-- (parallax_renderer, etc.) so the values never silently diverge.
Camera.DEFAULT_MIN_VIEW_TILES = DEFAULT_MIN_VIEW_TILES
Camera.DEFAULT_TILE_SIZE = DEFAULT_TILE_SIZE

local function unionBounds(targets)
	local minX, minY, maxX, maxY

	for _, t in ipairs(targets) do
		local x1, y1 = t.x, t.y
		local x2, y2 = t.x + t.w, t.y + t.h

		if not minX or x1 < minX then
			minX = x1
		end
		if not minY or y1 < minY then
			minY = y1
		end
		if not maxX or x2 > maxX then
			maxX = x2
		end
		if not maxY or y2 > maxY then
			maxY = y2
		end
	end

	return minX, minY, maxX, maxY
end

local NumberUtils = require("src.utils.number")
local clamp = NumberUtils.clamp

-- Pure framing math: given world-space target rects ({x, y, w, h}), the map's
-- pixel size, the screen's pixel size, and options, returns the view rect
-- {x, y, w, h, scale, cx, cy} that should be shown on screen.
--
-- `opts.padding` (world px, default 0) is a gutter of void the camera keeps
-- visible around every map edge whenever a map edge is on screen: at the
-- zoom-out limit the view spans the map plus `padding` on each side instead
-- of fitting the map edge flush to the screen, so the diorama frame always
-- has room to show.
function Camera.computeFraming(targets, mapW, mapH, screenW, screenH, opts)
	opts = opts or {}
	local marginTiles = opts.marginTiles or DEFAULT_MARGIN_TILES
	local minViewTiles = opts.minViewTiles or DEFAULT_MIN_VIEW_TILES
	local tileW = opts.tileW or DEFAULT_TILE_SIZE
	local tileH = opts.tileH or tileW
	local pad = opts.padding or 0
	-- When false, the view is left centred on the targets even near the map
	-- edges (used by per-player Voronoi panes so a player is never dragged
	-- off-centre at the border). Default true clamps the view inside the map.
	local clampToMap = opts.clampToMap == nil or opts.clampToMap

	local minX, minY, maxX, maxY = unionBounds(targets)
	if not minX then
		minX, minY, maxX, maxY = 0, 0, mapW, mapH
	end

	local marginX = marginTiles * tileW
	local marginY = marginTiles * tileH
	minX = minX - marginX
	minY = minY - marginY
	maxX = maxX + marginX
	maxY = maxY + marginY

	local cx = (minX + maxX) / 2
	local cy = (minY + maxY) / 2
	local bw = maxX - minX
	local bh = maxY - minY

	local minW = minViewTiles * tileW
	local minH = minViewTiles * tileH
	if bw < minW then
		bw = minW
	end
	if bh < minH then
		bh = minH
	end

	-- Never show less of the world than the whole map plus `padding` of void
	-- on every side. When the targets already span the map (full-map view,
	-- overview, game-over, or players spread to the map edges), widen the
	-- desired view to the padded size so the edge never sits flush.
	local paddedW = mapW + 2 * pad
	local paddedH = mapH + 2 * pad
	if bw >= mapW then
		bw = paddedW
	end
	if bh >= mapH then
		bh = paddedH
	end

	local scale = math.min(screenW / bw, screenH / bh)

	local viewW = screenW / scale
	local viewH = screenH / scale

	local viewX = cx - viewW / 2
	local viewY = cy - viewH / 2

	-- A view wider than the map is centred, which leaves `padding` of void
	-- either side (more when the screen aspect is wider than the map's). A
	-- view narrower than the map is clamped inside it (no map edge is on
	-- screen, so no padding is owed) unless clampToMap is false (per-player
	-- Voronoi panes keep their player centred even at the map border).
	if viewW > mapW then
		viewX = (mapW - viewW) / 2
	elseif clampToMap then
		viewX = clamp(viewX, 0, mapW - viewW)
	end

	if viewH > mapH then
		viewY = (mapH - viewH) / 2
	elseif clampToMap then
		viewY = clamp(viewY, 0, mapH - viewH)
	end

	return {
		x = viewX,
		y = viewY,
		w = viewW,
		h = viewH,
		scale = scale,
		cx = viewX + viewW / 2,
		cy = viewY + viewH / 2,
	}
end

-- The "whole level" framing used for overview, level-start, and game-over.
-- Optional `padding` (world px) keeps that much void around every map edge.
function Camera.fullMapView(mapW, mapH, screenW, screenH, padding)
	return Camera.computeFraming(
		{ { x = 0, y = 0, w = mapW, h = mapH } },
		mapW,
		mapH,
		screenW,
		screenH,
		{ marginTiles = 0, minViewTiles = 0, tileW = 1, tileH = 1, padding = padding }
	)
end

function Camera.new(opts)
	opts = opts or {}

	local self = setmetatable({}, Camera)
	self.screenW = opts.screenW or 800
	self.screenH = opts.screenH or 600
	self.mapW = opts.mapW or self.screenW
	self.mapH = opts.mapH or self.screenH
	self.tileW = opts.tileW or DEFAULT_TILE_SIZE
	self.tileH = opts.tileH or self.tileW
	self.marginTiles = opts.marginTiles or DEFAULT_MARGIN_TILES
	self.minViewTiles = opts.minViewTiles or DEFAULT_MIN_VIEW_TILES
	self.decay = opts.decay or DEFAULT_DECAY
	self.padding = opts.padding or 0
	self.clampToMap = opts.clampToMap == nil or opts.clampToMap

	self.mode = "follow"
	self.extraTargets = {}

	-- levels open at the full-map view and ease in on the players
	local full = Camera.fullMapView(self.mapW, self.mapH, self.screenW, self.screenH, self.padding)
	self.cx, self.cy, self.scale = full.cx, full.cy, full.scale

	return self
end

function Camera:setScreenSize(w, h)
	self.screenW = w
	self.screenH = h
end

function Camera:setMapSize(w, h)
	self.mapW = w
	self.mapH = h
end

function Camera:setMode(mode)
	self.mode = mode
end

function Camera:getMode()
	return self.mode
end

-- Press-to-toggle between follow and the full-map overview. A no-op while
-- game-over owns the view.
function Camera:toggleOverview()
	if self.mode == "gameover" then
		return
	elseif self.mode == "overview" then
		self.mode = "follow"
	else
		self.mode = "overview"
	end
end

function Camera:addExtraTarget(key, rect)
	self.extraTargets[key] = rect
end

function Camera:removeExtraTarget(key)
	self.extraTargets[key] = nil
end

-- Computes (without applying) the view the camera is currently easing
-- toward, given this frame's player target rects.
function Camera:computeTargetView(playerTargets)
	if self.mode == "overview" or self.mode == "gameover" then
		return Camera.fullMapView(self.mapW, self.mapH, self.screenW, self.screenH, self.padding)
	end

	local targets = {}
	for _, t in ipairs(playerTargets or {}) do
		table.insert(targets, t)
	end
	for _, t in pairs(self.extraTargets) do
		table.insert(targets, t)
	end

	return Camera.computeFraming(targets, self.mapW, self.mapH, self.screenW, self.screenH, {
		marginTiles = self.marginTiles,
		minViewTiles = self.minViewTiles,
		tileW = self.tileW,
		tileH = self.tileH,
		padding = self.padding,
		clampToMap = self.clampToMap,
	})
end

-- Frame-rate-independent exponential ease of centre/zoom toward the target
-- view; never overshoots and settles in ~0.5s with the default decay.
function Camera:update(dt, playerTargets)
	local target = self:computeTargetView(playerTargets)
	local factor = 1 - math.exp(-self.decay * dt)

	self.cx = self.cx + (target.cx - self.cx) * factor
	self.cy = self.cy + (target.cy - self.cy) * factor
	self.scale = self.scale + (target.scale - self.scale) * factor

	return target
end

-- tx, ty, sx, sy for Map:draw2 -- centres (cx, cy) on screen at the current zoom.
-- Returns a ViewRect record instead of four loose positional args.
function Camera:getDrawParams()
	local tx = self.screenW / 2 - self.cx * self.scale
	local ty = self.screenH / 2 - self.cy * self.scale
	return ViewRect.new(tx, ty, self.scale, self.scale)
end

Camera.ViewRect = ViewRect

-- ===========================================================================
-- CameraManager: the Voronoi split-screen camera.
--
-- Owns the shared "merged" camera (which frames all players together, exactly
-- like the standalone Camera) plus per-player "pane" cameras. When the toggle
-- (conf.voronoi) is OFF, InGameState calls only updateMerged/getDrawParams and
-- the manager behaves exactly like the old single auto-zoom camera. When ON,
-- the manager also decides the split (Euclidean distance between the two
-- players with hysteresis), tracks the Voronoi line angle, and exposes
-- per-pane draw params for the two-canvas shader compositing.
--
-- Disabled-by-default constants; InGameState decides whether to actually use
-- the split path based on conf.voronoi.
-- ===========================================================================

local DEFAULT_D_MERGED_MULT = 2 -- d_merged = 2 * tileW
local DEFAULT_D_SPLIT_MULT = 4 -- d_split = 4 * tileW
local SPLIT_DIVERGENCE_FLOOR = 4 -- pane-separation needed before the line grows
local SPLIT_FULL_DIVERGENCE = 256 -- pane-separation where the split is "fully" grown
-- split factor / angle easing decay; 1 - e^-6 ~= 0.9975 settles inside ~0.5s
local SPLIT_DECAY = 12
local ANGLE_DECAY = 20
local ANGLE_MIN = 5 * math.pi / 180 -- 5 deg: ignore tiny deltas to avoid jitter
local ANGLE_MAX_ROT = 150 * math.pi / 180 -- max ~150 deg/s rotation
local PANE_MIN_VIEW_TILES = 4

local CameraManager = {}
CameraManager.__index = CameraManager

function CameraManager.new(opts)
	opts = opts or {}
	local tileW = opts.tileW or DEFAULT_TILE_SIZE
	local self = setmetatable({
		screenW = opts.screenW or 800,
		screenH = opts.screenH or 600,
		mapW = opts.mapW or 800,
		mapH = opts.mapH or 600,
		tileW = tileW,
		tileH = opts.tileH or tileW,
		padding = opts.padding or 0,
		d_merged = opts.d_merged or (DEFAULT_D_MERGED_MULT * tileW),
		d_split = opts.d_split or (DEFAULT_D_SPLIT_MULT * tileW),
		mode = "follow",
		splitState = false,
		splitFactor = 0,
		splitAngle = 0,
		splitAngleTarget = 0,
		panes = {},
		paneExtraTargets = {},
	}, CameraManager)

	self.merged = Camera.new({
		screenW = self.screenW,
		screenH = self.screenH,
		mapW = self.mapW,
		mapH = self.mapH,
		tileW = self.tileW,
		tileH = self.tileH,
		padding = self.padding,
		clampToMap = true,
	})

	return self
end

function CameraManager:setScreenSize(w, h)
	self.screenW = w
	self.screenH = h
	if self.merged then
		self.merged:setScreenSize(w, h)
	end
	for _, pane in pairs(self.panes) do
		pane:setScreenSize(w, h)
	end
end

function CameraManager:setMapSize(w, h)
	self.mapW = w
	self.mapH = h
	if self.merged then
		self.merged:setMapSize(w, h)
	end
	for _, pane in pairs(self.panes) do
		pane:setMapSize(w, h)
	end
end

function CameraManager:setMode(mode)
	self.mode = mode
	if self.merged then
		self.merged:setMode(mode)
	end
	for _, pane in pairs(self.panes) do
		pane:setMode(mode)
	end
end

function CameraManager:getMode()
	return self.mode
end

function CameraManager:isOverview()
	return self.mode == "overview" or self.mode == "gameover"
end

function CameraManager:toggleOverview()
	if self.mode == "gameover" then
		return
	end
	self.mode = (self.mode == "overview") and "follow" or "overview"
end

-- Delegated extra targets go to the merged camera (keeps the old behaviour for
-- a dying player's respawn framing in the non-split path).
function CameraManager:addExtraTarget(key, rect)
	if self.merged then
		self.merged:addExtraTarget(key, rect)
	end
end

function CameraManager:removeExtraTarget(key)
	if self.merged then
		self.merged:removeExtraTarget(key)
	end
end

-- Per-pane extra targets frame only that pane's camera.
function CameraManager:addPaneExtraTarget(index, key, rect)
	local pane = self:ensurePane(index)
	pane:addExtraTarget(key, rect)
end

function CameraManager:ensurePane(index)
	local pane = self.panes[index]
	if not pane then
		pane = Camera.new({
			screenW = self.screenW,
			screenH = self.screenH,
			mapW = self.mapW,
			mapH = self.mapH,
			tileW = self.tileW,
			tileH = self.tileH,
			padding = self.padding,
			minViewTiles = PANE_MIN_VIEW_TILES,
			clampToMap = false,
		})
		pane.primed = false
		self.panes[index] = pane
	end
	return pane
end

function CameraManager:setPaneScreenSize(index, w, h)
	local pane = self:ensurePane(index)
	pane:setScreenSize(w, h)
end

function CameraManager:paneCount()
	local n = 0
	for _ in pairs(self.panes) do
		n = n + 1
	end
	return n
end

-- The main per-frame entry for Voronoi mode: eases the merged camera, recomputes
-- the split, then eases each per-player pane.
function CameraManager:update(dt, targets)
	self:updateMerged(dt, targets)
	if self.mode == "follow" then
		self:updateSplit(dt, targets)
		for i = 1, #targets do
			self:updatePane(dt, i, targets)
		end
	end
end

function CameraManager:updateMerged(dt, targets)
	self.merged:update(dt, targets)
end

-- Euclidean-distance split decision with hysteresis. D = centre-to-centre
-- distance between the two players. Above d_split we split; below d_merged we
-- merge; between them the current state holds (dead zone → no flicker).
function CameraManager:updateSplit(dt, targets)
	local p1, p2 = targets and targets[1], targets and targets[2]
	if p1 and p2 then
		local c1x = p1.x + p1.w / 2
		local c1y = p1.y + p1.h / 2
		local c2x = p2.x + p2.w / 2
		local c2y = p2.y + p2.h / 2
		local dx, dy = c2x - c1x, c2y - c1y
		local D = math.sqrt(dx * dx + dy * dy)

		if self.mode == "follow" then
			if not self.splitState and D > self.d_split then
				self.splitState = true
			elseif self.splitState and D < self.d_merged then
				self.splitState = false
			end

			local target = self.splitState and 1 or 0
			local factor = 1 - math.exp(-SPLIT_DECAY * dt)
			self.splitFactor = self.splitFactor + (target - self.splitFactor) * factor

			-- Angle of the dividing line, following the players' separation.
			local angTarget = math.atan2(dy, dx)
			if math.abs(angTarget - self.splitAngleTarget) > ANGLE_MIN then
				self.splitAngleTarget = angTarget
			end
			self:_easeSplitAngle(dt)
		end
	end
end

function CameraManager:_easeSplitAngle(dt)
	local diff = self.splitAngleTarget - self.splitAngle
	while diff > math.pi do
		diff = diff - 2 * math.pi
	end
	while diff < -math.pi do
		diff = diff + 2 * math.pi
	end
	local maxRot = ANGLE_MAX_ROT * dt
	diff = clamp(diff, -maxRot, maxRot)
	local factor = 1 - math.exp(-ANGLE_DECAY * dt)
	self.splitAngle = self.splitAngle + diff * factor
end

-- Ease a single per-player pane camera. The pane is seeded to the merged view
-- on its first update so the split onset glides from the still-merged view
-- rather than jumping from the initial full-map state.
function CameraManager:updatePane(dt, index, targets)
	local pane = self:ensurePane(index)
	if not pane.primed then
		pane.cx, pane.cy, pane.scale = self.merged.cx, self.merged.cy, self.merged.scale
		pane.primed = true
	end

	-- Combine this pane's player target with that pane's extra targets. The
	-- oneshot targets list only holds this player; use computeTargetView on the
	-- pane which already merges pane.extraTargets.
	local playerTarget = targets and targets[index]
	local paneTargets = {}
	if playerTarget then
		table.insert(paneTargets, playerTarget)
	end
	for _, t in pairs(pane.extraTargets) do
		table.insert(paneTargets, t)
	end

	local target = pane:computeTargetView(paneTargets)
	local factor = 1 - math.exp(-pane.decay * dt)
	pane.cx = pane.cx + (target.cx - pane.cx) * factor
	pane.cy = pane.cy + (target.cy - pane.cy) * factor
	pane.scale = pane.scale + (target.scale - pane.scale) * factor
end

function CameraManager:getSplitFactor()
	return self.splitFactor
end

function CameraManager:isSplit()
	return self.mode == "follow" and self.splitState
end

function CameraManager:getSplitAngle()
	return self.splitAngle
end

-- How far the panes have actually diverged (pixel separation of their camera
-- centres). 0 when there aren't two panes yet.
function CameraManager:getSplitDivergence()
	local p1, p2 = self.panes[1], self.panes[2]
	if p1 and p2 then
		return math.abs(p1.cx - p2.cx)
	end
	return 0
end

-- 0 at split onset (both canvases still show the merged view) → 1 when fully
-- split. Drives the line thickness and anchor offsets so the split/join reads
-- as one continuous, aligned glide.
function CameraManager:getSplitZoomBlend()
	local div = self:getSplitDivergence()
	if div < SPLIT_DIVERGENCE_FLOOR then
		return 0
	end
	return clamp((div - SPLIT_DIVERGENCE_FLOOR) / (SPLIT_FULL_DIVERGENCE - SPLIT_DIVERGENCE_FLOOR), 0, 1)
end

-- Draw params for the shared merged camera (also the fallback single-camera
-- path when Voronoi is off).
function CameraManager:getDrawParams()
	return self:getMergedDrawParams()
end

function CameraManager:getMergedDrawParams()
	return self.merged:getDrawParams()
end

function CameraManager:getMergedCamera()
	return self.merged
end

function CameraManager:computeTargetView(targets)
	return self.merged:computeTargetView(targets)
end

-- Draw params for a per-player pane. `offsetX/offsetY` are the pane's top-left
-- in window coords (0 for a full-window canvas). `zoomBlend` (default 1 = the
-- pane's own close-up zoom) lerps the rendered scale between the merged zoom
-- (0) and the pane's own zoom (1). The pane's world centre is derived from its
-- eased camera position, so the pane stays pinned to its player through the
-- transitions; the pane is seeded to the merged view on its first update, so
-- rendering at its own zoom still matches the shared view at onset.
function CameraManager:getPaneDrawParams(index, offsetX, offsetY, zoomBlend)
	local pane = self:ensurePane(index)
	local blend = zoomBlend
	if blend == nil then
		blend = 1
	end

	local scale = self.merged.scale + (pane.scale - self.merged.scale) * blend
	local offX, offY = offsetX or 0, offsetY or 0
	local tx = pane.screenW / 2 - pane.cx * scale + offX
	local ty = pane.screenH / 2 - pane.cy * scale + offY
	return ViewRect.new(tx, ty, scale, scale)
end

Camera.CameraManager = CameraManager

return Camera
