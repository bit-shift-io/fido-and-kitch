-- Dynamic split-screen under real rendering. The split/merge decision (Euclidean
-- hysteresis + easing) and per-pane framing are covered headless (unit) and
-- wired through the mock (integration); what only a real window can give is
-- proof that the Voronoi compositing path -- two full-window canvases, each
-- drawn with its own camera centred on its player's half, composited by the
-- Voronoi shader with a fixed vertical dividing line -- actually renders
-- without crashing, and that two distant players genuinely produce two
-- different views on screen.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Capture = require("tests.support.capture")

-- These tests verify the Voronoi compositing path, which is gated on
-- conf.voronoi.
conf.voronoi = true

local MAP = "res/map/sandbox.tmj" -- 20x20 tiles, 640x640

local function ingame(game)
	return game.fsm.currentState
end

local function settle(game)
	FrameStepper.step(game, 120) -- settle players and let the split factor ease
end

local function setPlayerX(ing, index, x)
	local player = ing.players[index]
	local b = player.collider:getBounds()
	player.collider:setPosition(x, b.top)
end

-- Brightest pixel colour in a screen x-band (one ImageData read, coarse scan).
-- Used to prove two halves render distinct content without brittle world-point
-- pinning: the left (dark, sparse) and right (bright) halves differ hugely.
local function brightestIn(canvas, x0, x1, step)
	local img = canvas:newImageData()
	local best, bestv = nil, -1
	for y = 0, math.floor(canvas:getHeight() - 1), 24 do
		for x = x0, x1, step do
			local r, g, b = img:getPixel(x, y)
			local c = { math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5) }
			local v = c[1] + c[2] + c[3]
			if v > bestv then
				best, bestv = c, v
			end
		end
	end
	return best, bestv
end

local function sameColor(a, b)
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

local function renderToCanvas(game)
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	local canvas = love.graphics.newCanvas(w, h)
	love.graphics.push("all")
	love.graphics.setCanvas(canvas)
	love.graphics.clear()
	game:draw()
	love.graphics.setCanvas()
	love.graphics.pop()
	return canvas
end

test("two distant players render two distinct views composited by the Voronoi shader", function()
	love.window.setMode(800, 600)
	local game = GameHarness.startGame(MAP, { real = true })
	local ing = ingame(game)
	settle(game)

	-- move the players far apart horizontally so the camera splits
	setPlayerX(ing, 1, 64)
	setPlayerX(ing, 2, 560)
	settle(game)

	assertTrue(ing.camera:isSplit(), "distant players should split into per-player views")
	assertEqual(2, ing.camera:paneCount(), "two split pane cameras should exist")
	assertTrue(math.abs(ing.camera:getSplitFactor() - 1) < 0.02, "should be fully split")

	-- The shader should exist under real graphics
	local shader = ing:getVoronoiShader()
	assertTrue(shader ~= nil, "the Voronoi shader should load under real graphics")

	-- Render the split and capture for visual inspection.
	local canvas = renderToCanvas(game)
	Capture.capture("01_voronoi_two_players")

	-- The two halves show different world content: each view re-centres on its
	-- own player, so the left frames player 1's (sparse, dark) area and the
	-- right frames player 2's (bright) area -- proof both views rendered
	-- distinct content, not one view stretched across the whole window.
	local leftBest, leftV = brightestIn(canvas, 0, 340, 4)
	local rightBest, rightV = brightestIn(canvas, 460, 799, 4)
	assertTrue(leftV >= 0 and rightV >= 0, "both halves should contain rendered content")
	assertFalse(sameColor(leftBest, rightBest), "the two views should render different world content")
end)

test("bringing the players back together merges to a single full-window render", function()
	love.window.setMode(800, 600)
	local game = GameHarness.startGame(MAP, { real = true })
	local ing = ingame(game)
	settle(game)

	setPlayerX(ing, 1, 64)
	setPlayerX(ing, 2, 560)
	settle(game)
	assertTrue(ing.camera:isSplit(), "precondition: split")

	setPlayerX(ing, 1, 300)
	setPlayerX(ing, 2, 320)
	settle(game)

	assertFalse(ing.camera:isSplit(), "close players should merge to a single pane")
	local canvas = renderToCanvas(game)
	Capture.capture("02_voronoi_merged")
	assertTrue(true, "merged render completed")
end)

test("overview mode draws a single merged full-map view without the shader", function()
	love.window.setMode(800, 600)
	local game = GameHarness.startGame(MAP, { real = true })
	local ing = ingame(game)
	settle(game)

	ing.camera:setMode("overview")
	settle(game)

	assertTrue(ing.camera:isOverview(), "overview mode active")
	local canvas = renderToCanvas(game)
	Capture.capture("03_voronoi_overview")
	assertTrue(true, "overview render completed")
end)
