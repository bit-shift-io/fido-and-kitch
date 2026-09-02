-- Unit tests for the F4 world-grid debug overlay (src/ui/grid_overlay.lua).
-- Only the pure geometry is tested headless; draw() is exercised against the
-- love.graphics mock.
local LoveMock = require("tests.support.love_mock")
love = LoveMock.new()

local GridOverlay = require("src.ui.grid_overlay")
local _internal = GridOverlay._internal
local computeGridLines = _internal.computeGridLines

test("default tile is 32 and overlay starts disabled", function()
	local o = GridOverlay:new()
	assertEqual(32, o.tile, "default gridline spacing is 32 world units")
	assertEqual(false, o.enabled, "overlay is off until toggled")
end)

test("empty or missing map size yields no lines", function()
	assertEqual(0, #computeGridLines(nil, nil, 0, 0, 1, 1, 800, 600), "nil map size -> no lines")
	assertEqual(0, #computeGridLines(0, 0, 0, 0, 1, 1, 800, 600), "zero map size -> no lines")
	assertEqual(0, #computeGridLines(800, 600, 0, 0, 1, 1, 0, 0), "no screen size -> no lines")
end)

test("gridlines every 32 units over the visible map area", function()
	-- A 96x96 world fully visible at 1x zoom from the origin on a 800x600
	-- screen: vertical lines at x=0,32,64,96 and horizontal at y=0,32,64,96.
	local lines = computeGridLines(96, 96, 0, 0, 1, 1, 800, 600, 32)
	assertEqual(8, #lines, "4 vertical + 4 horizontal gridlines")
	for _, line in ipairs(lines) do
		if line[1] == line[3] then
			assertEqual(0, line[1] % 32, "vertical line sits on a 32-unit boundary")
		else
			assertEqual(0, line[2] % 32, "horizontal line sits on a 32-unit boundary")
		end
	end
end)

test("lines are clamped to the map bounds", function()
	-- Viewport wider than the map: no vertical line beyond mapW=64, and the
	-- horizontal lines only span the map width, not the whole screen.
	local lines = computeGridLines(64, 100, 0, 0, 1, 1, 800, 600, 32)
	local verticals, horizontals = 0, 0
	for _, line in ipairs(lines) do
		if line[1] == line[3] then
			verticals = verticals + 1
			assertEqual(true, line[1] <= 64, "vertical line within map width")
		else
			horizontals = horizontals + 1
			assertEqual(0, line[1], "horizontal line starts at map left edge")
			assertEqual(64, line[3], "horizontal line ends at map right edge")
		end
	end
	assertEqual(3, verticals, "vertical lines at x=0,32,64")
	assertEqual(4, horizontals, "horizontal lines at y=0,32,64,96 (last <= mapH=100)")
end)

test("custom tile spacing is respected", function()
	local o = GridOverlay:new({ tile = 16 })
	local lines = computeGridLines(32, 32, 0, 0, 1, 1, 800, 600, o.tile)
	assertEqual(6, #lines, "3 vertical + 3 horizontal lines at 16-unit spacing")
end)
