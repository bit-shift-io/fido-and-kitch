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
-- Follow-mode zoom-out cap: the auto-zoom camera in "follow" mode never shows
-- a view wider than this many tiles, however far apart the framing targets
-- spread. Overview, level-start, and game-over all use Camera.fullMapView
-- directly (or via computeTargetView's early-return branch), which never
-- passes maxViewTiles to computeFraming, so they stay uncapped.
local MAX_VIEW_TILES = 20

-- Shared constants for modules that mirror camera framing semantics
-- (parallax_renderer, etc.) so the values never silently diverge.
Camera.DEFAULT_MIN_VIEW_TILES = DEFAULT_MIN_VIEW_TILES
Camera.DEFAULT_TILE_SIZE = DEFAULT_TILE_SIZE
Camera.MAX_VIEW_TILES = MAX_VIEW_TILES

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

	-- Follow-mode zoom-out cap: a floor on scale, not a ceiling on bw/bh.
	-- Clamping bw/bh directly would interact badly with the bw >= mapW padding
	-- branch above (it treats "spans the whole map" as a distinct case from
	-- "spans more than the map"), so the cap is applied after scale is derived
	-- instead. Raising scale here only ever shrinks the resulting view.
	if opts.maxViewTiles then
		local maxW = opts.maxViewTiles * tileW
		local maxH = opts.maxViewTiles * tileH
		scale = math.max(scale, screenW / maxW, screenH / maxH)
	end

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
	self.maxViewTiles = opts.maxViewTiles or MAX_VIEW_TILES
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
		maxViewTiles = self.maxViewTiles,
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
-- the manager also decides the split — from whether the follow-mode zoom cap
-- (Camera.MAX_VIEW_TILES) can still frame both players, with hysteresis —
-- tracks the Voronoi line angle, and exposes per-pane draw params for the
-- two-canvas shader compositing.
--
-- Disabled-by-default constants; InGameState decides whether to actually use
-- the split path based on conf.voronoi.
-- ===========================================================================

-- Split trigger: the *crossover point* — the moment the merged view already
-- draws each player exactly where the split view would put them.
--
-- In split mode a player sits at the centroid of their own region (half-plane
-- ∩ screen rect; for a vertical line that's the centre of their half, W/4 and
-- 3W/4). In merged mode the two players sit symmetrically about screen centre,
-- their on-screen separation being worldSeparation * the merged camera's zoom.
-- When those two separations are equal, both renderings place both players at
-- exactly the same pixels, so the split can begin (or end) with nothing moving
-- at all: the screen simply appears to part as the players keep walking away
-- from each other, and to close back up as they walk together. Trigger on
-- either side of that equality and the split instead snaps players toward or
-- away from the divider at the moment it appears.
--
-- Deliberately compared in *screen* pixels, and deliberately not against the
-- zoom cap. Both sides of this comparison are screen-space distances, so the
-- comparison is consistent by construction (unlike an earlier version, which
-- compared a required framing scale of min(screenW/bw, screenH/bh) against a
-- cap floor scale of max(screenW,screenH)/(capTiles*tile) — two ratios
-- governed by *different* screen dimensions, so their relationship silently
-- depended on the window's aspect ratio, and at the real 1280x720 window the
-- split fired for every player arrangement). The zoom cap
-- (Camera.MAX_VIEW_TILES) still decides how far the merged camera may zoom
-- out, and so indirectly how far apart the players get before they reach the
-- crossover — but it is no longer part of the trigger itself.
--
-- The dead band exists only to stop the state thrashing frame to frame while
-- the separation hovers on the boundary (each onset re-primes the panes, so a
-- flicker is not free). It is deliberately small: at the crossover the two
-- renderings agree, so a wide band would merely delay a transition that is
-- already seamless, and reintroduce a visible step at the far edge of it.
local SPLIT_TRIGGER_SEPARATION_MARGIN = 1.0 -- split right at the crossover
local SPLIT_RELEASE_SEPARATION_MARGIN = 0.98 -- merge 2% inside it, to stop boundary thrash
-- Sole owner of these two: they drive both the pane zoom blend
-- (getSplitZoomBlend) and, via InGameState, the dividing line's thickness, so
-- both halves of the split/merge transition agree on when it starts and ends.
local SPLIT_DIVERGENCE_FLOOR = 4 -- pane-separation needed before the line grows
local SPLIT_FULL_DIVERGENCE = 256 -- pane-separation where the split is "fully" grown
-- split factor / angle easing decay; 1 - e^-6 ~= 0.9975 settles inside ~0.5s
local SPLIT_DECAY = 12
-- Below this, an exponentially-decaying eased value (splitFactor or the
-- growth blend) is treated as "arrived" -- both asymptote toward 0/1 but
-- never reach either exactly, so the compositing-active gate (below) needs a
-- threshold to call them converged.
local SPLIT_TRANSITION_RELEASE_EPSILON = 0.01
local ANGLE_DECAY = 20
-- Below this player separation (world pixels), the raw separation angle is
-- degenerate -- atan2 of a near-zero vector -- rather than a genuine change in
-- direction, so the target holds instead of chasing it.
local ANGLE_DEGENERATE_SEPARATION = 4
local ANGLE_MAX_ROT = 150 * math.pi / 180 -- max ~150 deg/s rotation
local PANE_MIN_VIEW_TILES = 4
-- Pane anchor easing: how fast a pane's on-screen anchor point (the centroid
-- of that pane's split region) chases the raw geometric centroid as the
-- dividing line rotates. Easing the anchor (not the camera centre) keeps the
-- containment guarantee -- the anchor is always the centroid of *some* frame's
-- region, just not necessarily this instant's, so it never strays outside the
-- convex region the eased angle itself produces on the way there.
local ANCHOR_DECAY = 10
-- Degenerate-input fallback centroid (screen centre) shares this epsilon for
-- "normal too short to define a side" and "area too small to divide safely".
local DEGENERATE_EPSILON = 1e-6

local CameraManager = {}
CameraManager.__index = CameraManager

-- Shared with InGameState, which drives the dividing line's thickness from
-- the same divergence-based blend the pane zoom uses -- exposed here so the
-- two values are defined exactly once (see the definitions above).
CameraManager.SPLIT_DIVERGENCE_FLOOR = SPLIT_DIVERGENCE_FLOOR
CameraManager.SPLIT_FULL_DIVERGENCE = SPLIT_FULL_DIVERGENCE

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
		mode = "follow",
		splitState = false,
		splitFactor = 0,
		splitAngle = 0,
		splitAngleTarget = 0,
		growthBlend = 0,
		panes = {},
		paneExtraTargets = {},
		paneAnchors = {},
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
	-- Routed through setMode, not a direct self.mode assignment: self.merged
	-- (the Camera instance that actually computes the merged view) makes its
	-- own "show the full map" decision from its *own* .mode, set independently
	-- in Camera:computeTargetView. A direct assignment here left self.merged
	-- permanently in "follow" mode, which was invisible before the follow
	-- zoom cap existed (an uncapped follow view reaches the full-map scale on
	-- its own once players spread out) but became a real bug once it didn't:
	-- overview stopped being able to zoom out past the cap at all.
	self:setMode((self.mode == "overview") and "follow" or "overview")
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
		self:updateGrowthBlend(dt)
	end
end

function CameraManager:updateMerged(dt, targets)
	self.merged:update(dt, targets)
end

-- The representation of `target` (an angle) closest to `current`. atan2 wraps
-- at +/-pi but the dividing line does not, so without this a line rotating
-- through the seam would read as a full turn backwards -- to the easing in
-- _easeSplitAngle, and to anything comparing successive angles.
local function nearestEquivalentAngle(target, current)
	local diff = target - current
	while diff > math.pi do
		diff = diff - 2 * math.pi
	end
	while diff < -math.pi do
		diff = diff + 2 * math.pi
	end
	return current + diff
end

-- Crossover split decision with hysteresis. Compares the two
-- players' on-screen separation against the crossover distance — the on-screen
-- separation of the two split regions' centroids, which is where the split
-- view would draw those same two players. Splitting exactly there means
-- neither player moves on screen as the divider appears; the screen just
-- parts as they keep walking away from each other, and closes back up as they
-- walk together. See the SPLIT_TRIGGER_SEPARATION_MARGIN /
-- SPLIT_RELEASE_SEPARATION_MARGIN comment above for the (deliberately narrow)
-- dead band and for why this is measured in screen pixels.
--
-- Only runs in follow mode: this only decides whether a single shared camera
-- *could* frame both players, which is meaningless in overview (already
-- full-map) or game-over (view isn't player-driven at all).
function CameraManager:updateSplit(dt, targets)
	local p1, p2 = targets and targets[1], targets and targets[2]
	if p1 and p2 and self.mode == "follow" then
		-- Angle of the dividing line, following the players' separation.
		-- Resolved *before* the split decision: the crossover distance below
		-- is the separation of this line's two region centroids, so it has to
		-- be measured against the line this frame actually uses.
		local c1x = p1.x + p1.w / 2
		local c1y = p1.y + p1.h / 2
		local c2x = p2.x + p2.w / 2
		local c2y = p2.y + p2.h / 2
		local dx, dy = c2x - c1x, c2y - c1y
		-- Below this separation, atan2(dy, dx) is numerically unstable (a few
		-- world pixels of jitter swing it wildly) rather than meaningfully
		-- different, so hold the previous target instead of chasing noise.
		-- This gates on separation, not on how much the raw angle moved since
		-- last frame -- gating on the angle delta (the previous approach)
		-- holds the target through any change smaller than the threshold and
		-- then jumps once the accumulated change finally clears it, which
		-- turns ordinary continuous rotation into a visible staircase.
		if dx * dx + dy * dy > ANGLE_DEGENERATE_SEPARATION * ANGLE_DEGENERATE_SEPARATION then
			self.splitAngleTarget = nearestEquivalentAngle(math.atan2(dy, dx), self.splitAngle)
		end

		if self:isCompositingActive() then
			self:_easeSplitAngle(dt)
		else
			-- Nothing on screen is drawn from the line while the compositing
			-- path is released, so the angle can be taken instantly instead of
			-- eased around to. This is what stops the divider spinning a half
			-- turn when the players swap sides: they can only swap by passing
			-- each other, which means passing through a separation small
			-- enough to have merged, and by the time they are far enough apart
			-- to split again the line is already at its new orientation. Easing
			-- through that flip would rotate the divider 180 degrees for a
			-- change that is really just the two halves trading places.
			self.splitAngle = self.splitAngleTarget
		end

		-- Crossover trigger (see the SPLIT_*_SEPARATION_MARGIN comment above):
		-- the players' on-screen separation at the merged camera's current
		-- zoom, against the on-screen separation of the two split regions'
		-- centroids -- the pixels the split view would place those same two
		-- players at. Equal means both renderings agree, so the transition
		-- costs no movement in either direction.
		--
		-- Uses the merged camera's *eased* scale, not a freshly computed
		-- target: what has to line up is what is actually on screen this
		-- frame. (Clamped at a map edge the merged camera is not centred on
		-- the players' midpoint, so the two players are no longer symmetric
		-- about screen centre and only their separation still matches -- the
		-- crossover stays seamless in aggregate, fractionally less so per
		-- player.)
		local worldSep = math.sqrt(dx * dx + dy * dy)
		local screenSep = worldSep * self.merged.scale
		local crossover = self:getRegionCentroidSeparation()

		if crossover > DEGENERATE_EPSILON then
			if not self.splitState and screenSep > crossover * SPLIT_TRIGGER_SEPARATION_MARGIN then
				self.splitState = true
				-- Onset: force every existing pane to reseed from the merged
				-- camera this frame (see updatePane), rather than carrying over
				-- whatever position/scale it drifted to while hidden behind the
				-- merged view during the last split (or a previous one, in a
				-- level with more than one split).
				for _, pane in pairs(self.panes) do
					pane.primed = false
				end
			elseif self.splitState and screenSep < crossover * SPLIT_RELEASE_SEPARATION_MARGIN then
				self.splitState = false
			end
		end

		local target = self.splitState and 1 or 0
		local factor = 1 - math.exp(-SPLIT_DECAY * dt)
		self.splitFactor = self.splitFactor + (target - self.splitFactor) * factor
	end
end

-- How far apart, in screen pixels, the two split regions' centroids sit for
-- the current dividing line -- i.e. where the split view would put the two
-- players. W/2 for a vertical line, H/2 for a horizontal one, and the
-- interpolating values between for the angles in between. This is the
-- distance the players' own on-screen separation has to reach for the split
-- to begin (and to fall back below for it to end).
function CameraManager:getRegionCentroidSeparation()
	local line = self:getSplitLine()
	local a = CameraManager.computeRegionCentroid(self.screenW, self.screenH, line, -1)
	local b = CameraManager.computeRegionCentroid(self.screenW, self.screenH, line, 1)
	local dx, dy = b.x - a.x, b.y - a.y
	return math.sqrt(dx * dx + dy * dy)
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
-- on its first-ever update, and re-seeded on every split onset (see
-- updateSplit, which clears pane.primed there) so a pane reused across a
-- second split in the same level doesn't carry over a stale scale/position
-- from the previous split. The seeding frame itself applies no ease step --
-- the pane renders exactly the shared view that frame and only starts easing
-- away from it on the next, which is what lets the split open with nothing
-- moving.
--
-- A pane frames its own player only while splitState is true. Merged, it is
-- held on the shared view instead (paneMergedViewCentre), because two real
-- players can never occupy the same point -- collision keeps them some tens
-- of pixels apart -- so a pane that always tracked only its own player would
-- leave a permanent residual divergence even once genuinely merged, and
-- getSplitZoomBlend()/isCompositingActive() would stay above their release
-- epsilon forever (see the "eventually releases ... but not perfectly
-- overlapping" regression test).
function CameraManager:updatePane(dt, index, targets)
	local pane = self:ensurePane(index)
	-- Anchor first: the seed below is expressed relative to it.
	self:updatePaneAnchor(dt, index)

	-- Hold the pane exactly on the shared view whenever nothing on screen is
	-- being drawn from it: on its seeding frame (first update ever, and every
	-- split onset), and throughout any frame the compositing path is released.
	--
	-- Seeded on paneMergedViewCentre rather than merged.cx/cy because the pane
	-- draws its world centre at its anchor rather than at screen centre --
	-- copying the merged centre across would shift the whole view by
	-- (anchor - screen centre), a quarter-screen jump at the very frame the
	-- split appears, which is exactly what the crossover trigger exists to
	-- avoid. Seeded on the matching view, the split opens from a still image.
	--
	-- Held (not eased) while released, because the line's angle and the
	-- anchors derived from it are snapped while invisible -- when the players
	-- swap sides each pane's region crosses to the other half of the screen.
	-- A pane left easing toward that would still be in flight at the next
	-- onset, and its distance from the shared view is exactly what
	-- getSplitDivergence reports, so it would switch the compositing path back
	-- on mid-flight and show the jump it was meant to prevent.
	if not pane.primed or not self:isCompositingActive() then
		pane.cx, pane.cy = self:paneMergedViewCentre(index)
		pane.scale = self.merged.scale
		pane.primed = true
		return
	end

	local target
	if self.splitState then
		-- Combine this pane's player target with that pane's extra targets.
		-- The oneshot targets list only holds this player; use
		-- computeTargetView on the pane which already merges
		-- pane.extraTargets.
		local playerTarget = targets and targets[index]
		local paneTargets = {}
		if playerTarget then
			table.insert(paneTargets, playerTarget)
		end
		for _, t in pairs(pane.extraTargets) do
			table.insert(paneTargets, t)
		end
		target = pane:computeTargetView(paneTargets)
	else
		local mx, my = self:paneMergedViewCentre(index)
		target = { cx = mx, cy = my, scale = self.merged.scale }
	end

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

-- Whether the Voronoi compositing path (two canvases + shader blend) should
-- still be drawing this frame. Unlike isSplit() (a raw hysteresis boolean,
-- which can flip in either direction on a single frame), this is derived
-- entirely from eased quantities -- splitFactor and the divergence-driven
-- zoom blend -- so flipping splitState alone never changes which path draws.
--
-- Stays true as long as either eased quantity hasn't converged: splitFactor
-- above its release epsilon (still easing toward 0 or 1), or the panes still
-- genuinely diverged (zoom blend, and so line thickness, still above 0). Only
-- once both have settled does it release to the single merged-camera path --
-- that's the frame the dividing line has actually reached zero thickness and
-- the two panes have actually converged, so there's no jump at the cut.
--
-- Explicitly gated on follow mode: overview and game-over are deliberate cuts
-- to a full-map view, not a species of the split/merge glide, so entering
-- either releases the compositing path immediately regardless of how far
-- splitFactor or the pane divergence still have to ease down.
function CameraManager:isCompositingActive()
	if self.mode ~= "follow" then
		return false
	end
	return self.splitFactor > SPLIT_TRANSITION_RELEASE_EPSILON
		or self:getSplitZoomBlend() > SPLIT_TRANSITION_RELEASE_EPSILON
end

function CameraManager:getSplitAngle()
	return self.splitAngle
end

-- Pure split-line geometry: the dividing line as a point + unit normal, in
-- screen pixels. `angle` is the (already-eased, jitter-held) split angle;
-- `offset` is a signed scalar that slides the point along the normal, away
-- from screen centre. Static/pure so it's directly testable without an
-- instance.
function CameraManager.computeSplitLine(screenW, screenH, angle, offset)
	offset = offset or 0
	local nx, ny = math.cos(angle), math.sin(angle)
	return {
		x = screenW / 2 + nx * offset,
		y = screenH / 2 + ny * offset,
		nx = nx,
		ny = ny,
	}
end

-- Sutherland-Hodgman clip of a convex polygon (list of {x,y}, in order) by a
-- single half-plane: `side * ((x-px)*nx + (y-py)*ny) >= 0` is kept. `side` is
-- 1 or -1 -- see computeRegionCentroid for the convention (matches the
-- shader's sd<=0 / sd>=0 split of CanvasA/CanvasB). Returns a new vertex list;
-- may be empty if the half-plane misses the polygon entirely.
local function clipPolygonByHalfplane(poly, px, py, nx, ny, side)
	local out = {}
	local n = #poly
	for i = 1, n do
		local cur = poly[i]
		local nxt = poly[i % n + 1]
		local dCur = side * ((cur.x - px) * nx + (cur.y - py) * ny)
		local dNxt = side * ((nxt.x - px) * nx + (nxt.y - py) * ny)

		if dCur >= 0 then
			table.insert(out, cur)
			if dNxt < 0 then
				local t = dCur / (dCur - dNxt)
				table.insert(out, { x = cur.x + (nxt.x - cur.x) * t, y = cur.y + (nxt.y - cur.y) * t })
			end
		elseif dNxt >= 0 then
			local t = dCur / (dCur - dNxt)
			table.insert(out, { x = cur.x + (nxt.x - cur.x) * t, y = cur.y + (nxt.y - cur.y) * t })
		end
	end
	return out
end

-- Area-weighted (shoelace) centroid of a convex polygon -- NOT the average of
-- its vertices, which is only correct for a regular polygon. This is the
-- formula that guarantees the centroid lies inside the polygon regardless of
-- whether clipping produced a triangle, quadrilateral, or pentagon. Returns
-- nil, nil if the polygon is degenerate (fewer than 3 vertices, or an area
-- too small to divide by safely).
local function polygonCentroid(poly)
	local n = #poly
	if n < 3 then
		return nil, nil
	end

	local area, cx, cy = 0, 0, 0
	for i = 1, n do
		local p1 = poly[i]
		local p2 = poly[i % n + 1]
		local cross = p1.x * p2.y - p2.x * p1.y
		area = area + cross
		cx = cx + (p1.x + p2.x) * cross
		cy = cy + (p1.y + p2.y) * cross
	end
	area = area / 2
	if math.abs(area) < DEGENERATE_EPSILON then
		return nil, nil
	end

	return cx / (6 * area), cy / (6 * area)
end

-- Pure convex-region centroid: the centroid of (half-plane ∩ screen rect),
-- where the half-plane is one side of `line` (a {x, y, nx, ny} point+normal,
-- as returned by computeSplitLine). `side` is 1 or -1, matching the shader's
-- `sd = dot(screenCoord - line_point, line_normal)` sign test: side=-1 is P1's
-- region (sd<=0, CanvasA), side=1 is P2's region (sd>=0, CanvasB).
--
-- Clipping a rect by a half-plane can yield a triangle, quadrilateral, or
-- pentagon depending on the line's angle -- this always uses the general
-- convex-polygon centroid above rather than a per-shape special case, which
-- is what guarantees the result lies strictly inside the region (a convex
-- region's area-weighted centroid always does) for every angle, not just the
-- ones a special case happened to cover.
--
-- Degenerate inputs (a zero-length normal, or a zero-area screen rect) return
-- the screen centre rather than a NaN/inf.
function CameraManager.computeRegionCentroid(screenW, screenH, line, side)
	if not screenW or not screenH or screenW <= 0 or screenH <= 0 then
		return { x = 0, y = 0 }
	end

	local fallback = { x = screenW / 2, y = screenH / 2 }

	local nx, ny = (line and line.nx) or 0, (line and line.ny) or 0
	local nlen = math.sqrt(nx * nx + ny * ny)
	if nlen < DEGENERATE_EPSILON then
		return fallback
	end

	local rect = {
		{ x = 0, y = 0 },
		{ x = screenW, y = 0 },
		{ x = screenW, y = screenH },
		{ x = 0, y = screenH },
	}
	local clipped = clipPolygonByHalfplane(rect, line.x, line.y, nx, ny, side)
	local cx, cy = polygonCentroid(clipped)
	if not cx then
		return fallback
	end

	return { x = cx, y = cy }
end

-- Documented seam: the line's off-centre travel along its own normal. Always
-- 0 today -- the line stays centred on screen at every separation. This is
-- the single caller of the offset; a later slice may drive it (e.g. to keep
-- a pane's player from sitting on the wrong side of a centred line), but
-- nothing does yet.
function CameraManager:_splitLineOffset()
	return 0
end

-- The line CameraManager reports for the shader/consumers this frame: a point
-- and unit normal, in screen pixels, computed once here and shared by
-- InGameState and the Voronoi shader.
function CameraManager:getSplitLine()
	return CameraManager.computeSplitLine(self.screenW, self.screenH, self.splitAngle, self:_splitLineOffset())
end

-- Side convention for pane index -> half-plane sign, matching the shader's
-- sd<=0 (CanvasA / pane 1) vs sd>=0 (CanvasB / pane 2) split.
local function paneSide(index)
	return index == 1 and -1 or 1
end

-- The raw (unsmoothed) geometric centroid of this frame's split region for
-- pane `index`, in screen pixels. Recomputed fresh every call from the
-- current split line -- callers that want the eased, jitter-safe anchor
-- should use getPaneAnchor instead.
function CameraManager:getRegionCentroid(index)
	return CameraManager.computeRegionCentroid(self.screenW, self.screenH, self:getSplitLine(), paneSide(index))
end

-- Seeds a pane's anchor to its raw centroid the first time it's asked for, so
-- there's no snap-from-zero on the first frame a pane exists.
function CameraManager:ensurePaneAnchor(index)
	local anchor = self.paneAnchors[index]
	if not anchor then
		local raw = self:getRegionCentroid(index)
		anchor = { x = raw.x, y = raw.y }
		self.paneAnchors[index] = anchor
	end
	return anchor
end

-- The eased anchor point getPaneDrawParams anchors that pane's player to.
function CameraManager:getPaneAnchor(index)
	return self:ensurePaneAnchor(index)
end

-- Eases a pane's anchor toward this frame's raw region centroid. Easing the
-- anchor (not the camera centre it's combined with in getPaneDrawParams)
-- means every eased value the anchor passes through is itself the centroid of
-- an actual region for some angle -- the containment guarantee holds
-- throughout the ease, not just at rest.
function CameraManager:updatePaneAnchor(dt, index)
	local anchor = self:ensurePaneAnchor(index)
	local raw = self:getRegionCentroid(index)
	if not self:isCompositingActive() then
		-- Nothing is drawn from the anchor while the compositing path is
		-- released, so take it instantly rather than gliding to it -- same
		-- reasoning as the split angle in updateSplit. It matters for the
		-- same case: when the players swap sides, each pane's region (and so
		-- its centroid) crosses to the other half, and easing that while
		-- invisible would leave the anchor mid-flight at the next onset.
		anchor.x, anchor.y = raw.x, raw.y
		return
	end
	local factor = 1 - math.exp(-ANCHOR_DECAY * dt)
	anchor.x = anchor.x + (raw.x - anchor.x) * factor
	anchor.y = anchor.y + (raw.y - anchor.y) * factor
end

-- The world centre a pane would need for its projection to match the merged
-- camera's exactly. A pane draws its centre at its anchor (its region's
-- centroid) rather than at screen centre, so matching the merged view means
-- offsetting from merged.cx/cy by that displacement, converted to world units.
-- Sole definition of "this pane is showing the shared view": the seed, the
-- merged-state ease target, and the divergence measure all read it, so they
-- cannot disagree about where that is.
function CameraManager:paneMergedViewCentre(index)
	local merged = self.merged
	local anchor = self:getPaneAnchor(index)
	return merged.cx + (anchor.x - merged.screenW / 2) / merged.scale,
		merged.cy + (anchor.y - merged.screenH / 2) / merged.scale
end

-- How far the panes have actually diverged *from the shared view*, in screen
-- pixels: the worst per-pane distance between what that pane draws and what
-- the merged camera would draw. 0 when no pane exists yet.
--
-- Deliberately measured against the merged view rather than between the two
-- panes' camera centres. Each pane is anchored at its own region's centroid,
-- so two panes both showing the shared view sit a fixed anchor-separation
-- apart in world space -- a centre-to-centre measure reads that as permanent
-- divergence and never releases the compositing path. Measured this way, the
-- quantity is exactly "how different does this look from just showing the
-- merged view", which is what the line thickness and the compositing gate
-- both actually want to know.
function CameraManager:getSplitDivergence()
	local worst = 0
	for index = 1, 2 do
		local pane = self.panes[index]
		if pane then
			local mx, my = self:paneMergedViewCentre(index)
			local dx = (pane.cx - mx) * self.merged.scale
			local dy = (pane.cy - my) * self.merged.scale
			worst = math.max(worst, math.sqrt(dx * dx + dy * dy))
		end
	end
	return worst
end

-- Raw (instantaneous) growth target derived straight from this frame's
-- divergence: 0 below the floor, 1 at or beyond full divergence. Not exposed
-- directly -- getSplitZoomBlend eases toward this every frame instead of
-- snapping to it (see updateGrowthBlend), because divergence itself can swing
-- a long way in a single frame (e.g. right at a split's onset, when both
-- panes start from the same primed position and immediately begin easing
-- apart toward targets that may be very far apart) and reflecting that swing
-- straight into the line-thickness-driving blend would read as a jump rather
-- than a glide.
function CameraManager:_rawGrowthTarget()
	local div = self:getSplitDivergence()
	if div < SPLIT_DIVERGENCE_FLOOR then
		return 0
	end
	return clamp((div - SPLIT_DIVERGENCE_FLOOR) / (SPLIT_FULL_DIVERGENCE - SPLIT_DIVERGENCE_FLOOR), 0, 1)
end

-- Eases the growth blend toward this frame's raw target. Shares SPLIT_DECAY
-- with splitFactor's own ease (the plan's "transition duration is a single
-- named constant") rather than introducing a second, competing decay knob --
-- the factor/thickness halves of the transition settle on the same timescale.
function CameraManager:updateGrowthBlend(dt)
	local target = self:_rawGrowthTarget()
	local factor = 1 - math.exp(-SPLIT_DECAY * dt)
	self.growthBlend = self.growthBlend + (target - self.growthBlend) * factor
end

-- 0 at split onset (both canvases still show the merged view) → 1 when fully
-- split. Drives the line thickness and pane zoom blend so the split/join
-- reads as one continuous, aligned glide -- an eased quantity in its own
-- right (see updateGrowthBlend), not an instantaneous readout of divergence.
function CameraManager:getSplitZoomBlend()
	return self.growthBlend
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
	-- The player anchors at the centroid of their own split region, not at
	-- the pane's midpoint -- that's what keeps them off the far side of the
	-- dividing line at any separation or angle.
	local anchor = self:getPaneAnchor(index)
	local tx = anchor.x - pane.cx * scale + offX
	local ty = anchor.y - pane.cy * scale + offY
	return ViewRect.new(tx, ty, scale, scale)
end

Camera.CameraManager = CameraManager

return Camera
