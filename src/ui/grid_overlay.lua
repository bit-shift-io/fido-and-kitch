-- src/ui/grid_overlay.lua — F4 debug mode: draws a world-space grid over the
-- map, one gridline every `tile` (default 32) world units, helping to read
-- tile/Tiled placement at a glance. Only the gridlines intersecting the
-- visible viewport are drawn (clamped to the map bounds), so large maps stay
-- cheap. Toggled by F4 in src/game.lua; gated on conf.draw_grid so it is off
-- by default and only engages under real rendering.
local GridOverlay = {}
GridOverlay.__index = GridOverlay

local lg = love.graphics

local DEFAULT_TILE = 32

function GridOverlay:new(props)
	props = props or {}
	return setmetatable({ enabled = false, tile = props.tile or DEFAULT_TILE }, GridOverlay)
end

function GridOverlay:toggle()
	self.enabled = not self.enabled
end

-- Pure geometry: the list of gridlines covering the visible portion of the
-- map, clamped to the map rect. Each line is {x0, y0, x1, y1} in world
-- space. screenW/screenH come from the caller so this stays headless-testable.
local function computeGridLines(mapW, mapH, tx, ty, sx, sy, screenW, screenH, tile)
	tile = tile or DEFAULT_TILE
	if not (mapW and mapH and mapW > 0 and mapH > 0) then
		return {}
	end
	local lines = {}
	if not (tx and ty and sx and sy and screenW and screenH) or screenW <= 0 or screenH <= 0 then
		return lines
	end
	local wx0 = math.max(0, (0 - tx) / sx)
	local wx1 = math.min(mapW, (screenW - tx) / sx)
	local wy0 = math.max(0, (0 - ty) / sy)
	local wy1 = math.min(mapH, (screenH - ty) / sy)

	local x = math.floor(wx0 / tile) * tile
	while x <= wx1 do
		if x >= 0 then
			lines[#lines + 1] = { x, wy0, x, wy1 }
		end
		x = x + tile
	end

	local y = math.floor(wy0 / tile) * tile
	while y <= wy1 do
		if y >= 0 then
			lines[#lines + 1] = { wx0, y, wx1, y }
		end
		y = y + tile
	end
	return lines
end

GridOverlay._internal = {
	computeGridLines = computeGridLines,
}

function GridOverlay:draw(mapW, mapH, viewRect)
	if not self.enabled or not conf.draw_grid then return end
	if not lg then return end

	lg.push()
	lg.origin()

	local tx, ty, sx, sy = viewRect.tx or 0, viewRect.ty or 0, viewRect.sx or 1, viewRect.sy or 1
	lg.translate(math.floor(tx), math.floor(ty))
	lg.scale(sx, sy)
	lg.setLineWidth(1 / math.max(sx, sy))

	local screenW, screenH = lg.getDimensions()
	local lines = computeGridLines(mapW, mapH, tx, ty, sx, sy, screenW, screenH, self.tile)

	lg.setColor(0.6, 0.6, 0.6, 0.35)
	for _, line in ipairs(lines) do
		lg.line(line[1], line[2], line[3], line[4])
	end

	lg.pop()
	lg.setColor(1, 1, 1, 1)
end

return GridOverlay
