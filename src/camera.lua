-- Auto-zoom camera: frames all players (plus transient extra targets like a
-- dying player's respawn point), zooming/panning smoothly between a min 5x5
-- tile view and the full map. Pure Lua (no love.* calls) so the framing and
-- smoothing math run under the headless test runner; InGameState supplies
-- screen/map size and reads back draw params each frame.
local Camera = {}
Camera.__index = Camera

local DEFAULT_MARGIN_TILES = 5
local DEFAULT_MIN_VIEW_TILES = 5
local DEFAULT_TILE_SIZE = 32
-- exponential decay rate; ~5 half-lives (1 - e^-6 ~= 0.9975) settle inside 0.5s
local DEFAULT_DECAY = 12

local function unionBounds(targets)
	local minX, minY, maxX, maxY

	for _, t in ipairs(targets) do
		local x1, y1 = t.x, t.y
		local x2, y2 = t.x + t.w, t.y + t.h

		if not minX or x1 < minX then minX = x1 end
		if not minY or y1 < minY then minY = y1 end
		if not maxX or x2 > maxX then maxX = x2 end
		if not maxY or y2 > maxY then maxY = y2 end
	end

	return minX, minY, maxX, maxY
end

local function clamp(v, lo, hi)
	if lo > hi then return (lo + hi) / 2 end
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

-- Pure framing math: given world-space target rects ({x, y, w, h}), the map's
-- pixel size, the screen's pixel size, and options, returns the view rect
-- {x, y, w, h, scale, cx, cy} that should be shown on screen.
function Camera.computeFraming(targets, mapW, mapH, screenW, screenH, opts)
	opts = opts or {}
	local marginTiles = opts.marginTiles or DEFAULT_MARGIN_TILES
	local minViewTiles = opts.minViewTiles or DEFAULT_MIN_VIEW_TILES
	local tileW = opts.tileW or DEFAULT_TILE_SIZE
	local tileH = opts.tileH or tileW

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
	if bw < minW then bw = minW end
	if bh < minH then bh = minH end

	-- never zoom out further than the whole map
	if bw > mapW then bw = mapW end
	if bh > mapH then bh = mapH end

	local scale = math.min(screenW / bw, screenH / bh)

	local viewW = screenW / scale
	local viewH = screenH / scale

	local viewX = cx - viewW / 2
	local viewY = cy - viewH / 2

	if viewW >= mapW then
		viewX = (mapW - viewW) / 2
	else
		viewX = clamp(viewX, 0, mapW - viewW)
	end

	if viewH >= mapH then
		viewY = (mapH - viewH) / 2
	else
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
function Camera.fullMapView(mapW, mapH, screenW, screenH)
	return Camera.computeFraming(
		{{x = 0, y = 0, w = mapW, h = mapH}},
		mapW, mapH, screenW, screenH,
		{marginTiles = 0, minViewTiles = 0, tileW = 1, tileH = 1}
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

	self.mode = 'follow'
	self.extraTargets = {}

	-- levels open at the full-map view and ease in on the players
	local full = Camera.fullMapView(self.mapW, self.mapH, self.screenW, self.screenH)
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
	if self.mode == 'gameover' then
		return
	elseif self.mode == 'overview' then
		self.mode = 'follow'
	else
		self.mode = 'overview'
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
	if self.mode == 'overview' or self.mode == 'gameover' then
		return Camera.fullMapView(self.mapW, self.mapH, self.screenW, self.screenH)
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

function Camera:getCenter()
	return self.cx, self.cy
end

function Camera:getZoom()
	return self.scale
end

-- tx, ty, sx, sy for Map:draw2 -- centres (cx, cy) on screen at the current zoom.
function Camera:getDrawParams()
	local tx = self.screenW / 2 - self.cx * self.scale
	local ty = self.screenH / 2 - self.cy * self.scale
	return tx, ty, self.scale, self.scale
end

return Camera
