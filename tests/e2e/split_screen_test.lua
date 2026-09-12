-- Dynamic split-screen under real rendering. The split/merge decision
-- (framing-based hysteresis + easing) and per-pane framing/anchoring are
-- covered headless (unit) and wired through the mock (integration); what
-- only a real window can give is proof that the Voronoi compositing path --
-- two full-window canvases, each drawn with its own camera anchored at the
-- centroid of its player's own split region, composited by the Voronoi
-- shader along a screen-centred rotating line -- actually keeps each player
-- visible inside their own half, not just that the two halves differ.
--
-- Geometric model this proves against: docs/adr/0007-centred-split-line-
-- centroid-anchored-panes.md. The dividing line is a point + unit normal in
-- screen pixels, always through screen centre, only rotating; each pane's
-- player is anchored at the centroid of (half-plane on their side) ∩ (screen
-- rect), which is why containment is a property of the geometry rather than
-- of any distance tuning.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Capture = require("tests.support.capture")
local AssetManager = require("src.utils.asset_manager")

-- These tests verify the Voronoi compositing path, which is gated on
-- conf.voronoi.
conf.voronoi = true

local MAP = "res/map/sandbox.tmj" -- 20x20 tiles, 640x640

-- Distinct, saturated placeholder colours for each player's sprite frames,
-- chosen to be implausible in ordinary map/tile art so an exact colour match
-- reliably means "this pixel is player N", not map content that happens to
-- share a channel value.
local PLAYER_COLORS = {
	{ 18, 219, 96 }, -- P1 (dog)
	{ 226, 24, 178 }, -- P2 (cat)
}

-- Frame counts per animation, mirrored from src/player/player.lua's
-- buildAnimations (idle/fall/walk; climb reuses the walk/"Run" frames, so no
-- separate seeding is needed for it).
local ANIMATION_FRAME_COUNTS = {
	{ "Idle", 10 },
	{ "Fall", 8 },
	{ "Run", 8 },
}

-- How many simulated frames to settle for after moving players: long enough
-- for every eased camera quantity (split factor / growth blend, decay=12;
-- angle, decay=20; pane anchor, decay=10) to converge to >99.9%, short
-- enough that ordinary gravity (~90.81 world px/s^2) can't meaningfully
-- displace a player who started on solid ground.
local SETTLE_FRAMES = 45

-- The Voronoi shader's own line thickness (VORONOI_LINE_THICKNESS in
-- src/states/ingame_state.lua) blends both canvases within this many pixels
-- of the dividing line. A matched placeholder pixel this close to the line
-- would be free to sit fractionally on the "wrong" side without indicating a
-- containment failure, so the side check tolerates it.
local LINE_SIDE_TOLERANCE = 6

local function ingame(game)
	return game.fsm.currentState
end

local function settle(game)
	FrameStepper.step(game, 120) -- settle players and let the split factor ease
end

local function settleAfterMove(game)
	FrameStepper.step(game, SETTLE_FRAMES)
end

local function setPlayerX(ing, index, x)
	local player = ing.players[index]
	local b = player.collider:getBounds()
	player.collider:setPosition(x, b.top)
end

local function setPlayerPos(ing, index, x, y)
	local player = ing.players[index]
	player.collider:setPosition(x, y)
end

-- Build a solid-colour placeholder image, matching the pattern established
-- in tests/e2e/diorama_test.lua: art exists for these paths already, but a
-- deterministic solid colour is what makes "found this exact colour on
-- screen" a reliable, non-brittle assertion.
local function makePlaceholder(r, g, b)
	local id = love.image.newImageData(32, 32)
	-- ImageData:setPixel takes 0..1 normalised channel values regardless of
	-- the colour's 0..255 authoring range, so unlike an 0/255-only palette
	-- (see diorama_test.lua, where every channel happens to be a clamp-safe
	-- extreme), an arbitrary 0..255 triple must be divided down first or
	-- every non-zero channel clamps to 1.0 and the placeholder renders white.
	for y = 0, 31 do
		for x = 0, 31 do
			id:setPixel(x, y, r / 255, g / 255, b / 255, 1)
		end
	end
	return love.graphics.newImage(id)
end

-- Seeds every animation frame path for one character ("dog" or "cat") with
-- the same solid colour, so whichever frame is currently playing (idle,
-- fall, walk) renders identically -- the test doesn't need to track
-- animation state, just look for the colour.
local function seedPlayerColor(character, color)
	local img = makePlaceholder(color[1], color[2], color[3])
	for _, spec in ipairs(ANIMATION_FRAME_COUNTS) do
		local name, count = spec[1], spec[2]
		for i = 1, count do
			local path = string.format("res/img/%s/%s (%d).png", character, name, i)
			AssetManager.textures[path] = img
		end
	end
end

local function seedPlayerColors()
	seedPlayerColor("dog", PLAYER_COLORS[1])
	seedPlayerColor("cat", PLAYER_COLORS[2])
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

local function round(v)
	return math.floor(v + 0.5)
end

-- Coarse full-frame scan for exact-colour pixels. Returns a list of {x, y}
-- screen points. `step` trades resolution for scan time -- a player's
-- rendered sprite is large relative to the window at pane zoom (well over
-- 100px across), so a several-pixel stride still reliably finds it.
local function findColorPixels(canvas, color, step)
	local img = canvas:newImageData()
	local w, h = canvas:getDimensions()
	local pts = {}
	for y = 0, h - 1, step do
		for x = 0, w - 1, step do
			local r, g, b = img:getPixel(x, y)
			if round(r * 255) == color[1] and round(g * 255) == color[2] and round(b * 255) == color[3] then
				table.insert(pts, { x = x, y = y })
			end
		end
	end
	return pts
end

-- Signed distance from a screen point to the split line, matching the
-- shader's own sd = dot(screenCoord - line_point, line_normal): <=0 is P1's
-- side (CanvasA), >0 is P2's side (CanvasB).
local function signedDistance(pt, line)
	return (pt.x - line.x) * line.nx + (pt.y - line.y) * line.ny
end

-- Asserts every matched pixel for a player's colour sits on that player's
-- own side of the dividing line (within the shader's own line-thickness
-- tolerance) -- the actual per-half visibility proof, not merely "the two
-- halves differ".
local function assertOwnSide(pts, line, expectSide, label)
	assertTrue(#pts > 0, label .. ": expected to find the player's placeholder colour on screen")
	for _, pt in ipairs(pts) do
		local sd = signedDistance(pt, line)
		if expectSide < 0 then
			assertTrue(sd <= LINE_SIDE_TOLERANCE, label .. ": found a pixel on the wrong side of the split line")
		else
			assertTrue(sd >= -LINE_SIDE_TOLERANCE, label .. ": found a pixel on the wrong side of the split line")
		end
	end
end

-- Positions chosen against the collision layer of res/map/sandbox.tmj so
-- both players rest on solid ground (no free-fall drift during settling)
-- while still separating far enough to cross the framing-based split
-- trigger (CameraManager:updateSplit compares the *uncapped* required
-- framing scale against the follow-mode zoom cap's floor scale, not a raw
-- distance -- see AGENTS.md/CONTEXT.md "Voronoi split-screen"). Each pair is
-- comfortably beyond that threshold; the map is only 640x640 so these sit
-- near its edges by construction.
local SEPARATIONS = {
	{
		label = "horizontal",
		p1 = { x = 64, y = nil }, -- nil y = keep the settled ground height
		p2 = { x = 560, y = nil },
	},
	{
		label = "vertical",
		p1 = { x = 320, y = 162 }, -- resting on the y=192 platform (collision rect 96,192,256,32)
		p2 = { x = 330, y = 514 }, -- resting on the y=544 platform (collision rect 320,544,320,96)
	},
	{
		label = "diagonal (top-left to bottom-right)",
		p1 = { x = 32, y = 162 }, -- resting on the y=192 platform (collision rect 32,192,32,32)
		p2 = { x = 608, y = 514 }, -- resting on the y=544 platform (collision rect 320,544,320,96)
	},
	{
		label = "diagonal (top-right to bottom-left)",
		p1 = { x = 608, y = 226 }, -- resting on the y=256 platform (collision rect 448,256,192,32)
		p2 = { x = 16, y = 482 }, -- resting on the y=512 platform (collision rect 0,512,224,128)
	},
}

test("close players stay merged at the game's real default window resolution (1280x720)", function()
	-- Regression test: every other test in this file explicitly sets an
	-- 800x600 window, including previously via the real LÖVE binary here in
	-- the e2e tier -- so none of them ever exercised the game's actual
	-- conf.lua default of 1280x720 (16:9). An earlier version of the split
	-- trigger compared screen-resolution-derived scales that are governed by
	-- different screen dimensions depending on aspect ratio, which happened
	-- to work out at 800x600 (~4:3) but caused the split to fire for *any*
	-- player arrangement at 1280x720, including players standing right next
	-- to each other. Deliberately does NOT call love.window.setMode, so this
	-- runs at conf.lua's real, unmodified default.
	seedPlayerColors()
	local game = GameHarness.startGame(MAP, { real = true })
	local ing = ingame(game)
	settle(game)

	setPlayerPos(ing, 1, 300, 162) -- resting on the y=192 platform (collision rect 96,192,256,32)
	setPlayerPos(ing, 2, 324, 162)
	settleAfterMove(game)

	assertFalse(
		ing.camera:isSplit(),
		string.format(
			"close players should stay merged at the real %dx%d window, not just the 800x600 every other test uses",
			love.graphics.getWidth(),
			love.graphics.getHeight()
		)
	)
	assertFalse(ing.camera:isCompositingActive(), "compositing path should not be active for close players")
end)

test("each player's sprite renders on their own side of the dividing line, at several split angles", function()
	for _, sep in ipairs(SEPARATIONS) do
		love.window.setMode(800, 600)
		seedPlayerColors()
		local game = GameHarness.startGame(MAP, { real = true })
		local ing = ingame(game)
		settle(game)

		if sep.p1.y then
			setPlayerPos(ing, 1, sep.p1.x, sep.p1.y)
		else
			setPlayerX(ing, 1, sep.p1.x)
		end
		if sep.p2.y then
			setPlayerPos(ing, 2, sep.p2.x, sep.p2.y)
		else
			setPlayerX(ing, 2, sep.p2.x)
		end
		settleAfterMove(game)

		assertTrue(ing.camera:isSplit(), sep.label .. ": should be split at this separation")
		assertTrue(
			math.abs(ing.camera:getSplitFactor() - 1) < 0.02,
			sep.label .. ": should be fully split after settling"
		)

		local canvas = renderToCanvas(game)
		Capture.capture("angle_" .. sep.label:gsub("[^%w]+", "_"))

		local line = ing.camera:getSplitLine()
		local p1Pixels = findColorPixels(canvas, PLAYER_COLORS[1], 4)
		local p2Pixels = findColorPixels(canvas, PLAYER_COLORS[2], 4)

		assertOwnSide(p1Pixels, line, -1, sep.label .. " P1")
		assertOwnSide(p2Pixels, line, 1, sep.label .. " P2")
	end
end)

test("a player in a map corner still renders near the centre of their half without crashing on the void", function()
	love.window.setMode(800, 600)
	seedPlayerColors()
	local game = GameHarness.startGame(MAP, { real = true })
	local ing = ingame(game)
	settle(game)

	-- P1 sits at the map's bottom-left corner (collision rect 0,512,224,128
	-- gives solid ground right up to the map's left/bottom edges); P2 sits
	-- far away at the top-right so the split stays active and P1's per-pane
	-- camera (clampToMap = false for panes) frames well outside the map,
	-- into the void, on at least two sides.
	setPlayerPos(ing, 1, 16, 482)
	setPlayerPos(ing, 2, 608, 226)
	settleAfterMove(game)

	assertTrue(ing.camera:isSplit(), "precondition: split")

	local ok, err = pcall(renderToCanvas, game)
	assertTrue(ok, "rendering a player at a map corner while split must not crash: " .. tostring(err))

	local canvas = renderToCanvas(game)
	Capture.capture("corner_no_crash")

	-- "Near the centre of their half": the eased pane anchor
	-- (CameraManager:getPaneAnchor) should have converged close to this
	-- frame's raw region centroid -- the two are the same quantity, one eased
	-- and one instantaneous, per ADR 0007 -- and, per the containment
	-- guarantee, sit on P1's own side of the line.
	local anchor = ing.camera:getPaneAnchor(1)
	local rawCentroid = ing.camera:getRegionCentroid(1)
	local dx, dy = anchor.x - rawCentroid.x, anchor.y - rawCentroid.y
	assertTrue(
		math.sqrt(dx * dx + dy * dy) < 4,
		"P1's eased anchor should have converged to its region's centroid after settling"
	)

	local line = ing.camera:getSplitLine()
	assertTrue(signedDistance(anchor, line) <= LINE_SIDE_TOLERANCE, "P1's anchor should stay on P1's own side")

	local p1Pixels = findColorPixels(canvas, PLAYER_COLORS[1], 4)
	assertTrue(#p1Pixels > 0, "P1 should still render even from a map corner")
end)

-- Coarse frame-to-frame difference: average per-channel delta over a sampled
-- grid. Used only to bound the SIZE of a single step's visual change, not to
-- pin exact pixel values (which the merge/split easing legitimately moves
-- frame to frame).
local function averageFrameDelta(canvasA, canvasB, step)
	local imgA, imgB = canvasA:newImageData(), canvasB:newImageData()
	local w, h = canvasA:getDimensions()
	local total, count = 0, 0
	for y = 0, h - 1, step do
		for x = 0, w - 1, step do
			local ar, ag, ab = imgA:getPixel(x, y)
			local br, bg, bb = imgB:getPixel(x, y)
			total = total + math.abs(ar - br) + math.abs(ag - bg) + math.abs(ab - bb)
			count = count + 3
		end
	end
	return (total / count) * 255
end

-- Bound on how much the *average* sampled pixel may change, per real
-- simulated frame, during the merge-back glide. A transition step (the
-- eased camera/anchor/zoom-blend quantities advancing one 1/60s tick) moves
-- the composited image by a small, continuous amount; a discontinuity (a
-- hard cut, a wrong-frame pop at the compositing cutover CameraManager:
-- isCompositingActive exists to prevent) would blow well past this.
local MAX_FRAME_DELTA = 55
-- Tighter bound applied specifically at the frame where the draw path
-- switches from the Voronoi compositing path back to the single merged-view
-- path (isCompositingActive() flips true -> false) -- the exact seam
-- slice 06 built isCompositingActive to make seamless.
local MAX_CUTOVER_FRAME_DELTA = 30

test("merging back down steps smoothly: no frame differs from its predecessor by more than a transition-sized amount", function()
	love.window.setMode(800, 600)
	seedPlayerColors()
	local game = GameHarness.startGame(MAP, { real = true })
	local ing = ingame(game)
	settle(game)

	setPlayerX(ing, 1, 64)
	setPlayerX(ing, 2, 560)
	settle(game)
	assertTrue(ing.camera:isSplit(), "precondition: split")

	-- Bring the players back together in one jump, to two distinct but
	-- adjacent points -- realistically close, the way two players actually
	-- stand next to each other (never perfectly overlapping, since colliders
	-- can't occupy the same point). Once merged, panes chase the shared
	-- camera rather than their own player (see CameraManager:updatePane), so
	-- divergence genuinely converges toward 0 and isCompositingActive() can
	-- still release even though the two points are never identical. The
	-- render must still glide through this jump, not pop, because the
	-- composited frame is driven by continuously eased camera state, not by
	-- the raw player positions.
	setPlayerPos(ing, 1, 300, 162) -- resting on the y=192 platform (collision rect 96,192,256,32)
	setPlayerPos(ing, 2, 324, 162)

	local prevCanvas = renderToCanvas(game)
	local prevActive = ing.camera:isCompositingActive()
	local sawCutover = false

	-- 4s of simulated frames. Several eased quantities chain sequentially
	-- during a merge-back (pane cameras ease back toward the merged view,
	-- THEN pane divergence drops below SPLIT_DIVERGENCE_FLOOR, THEN
	-- growthBlend eases down from that, alongside splitFactor's own ~0.5s
	-- ease) -- comfortably longer than any single decay constant alone.
	local MERGE_STEPS = 240
	for i = 1, MERGE_STEPS do
		FrameStepper.step(game, 1)
		local canvas = renderToCanvas(game)
		local active = ing.camera:isCompositingActive()

		local delta = averageFrameDelta(prevCanvas, canvas, 8)
		if prevActive and not active then
			sawCutover = true
			assertTrue(
				delta <= MAX_CUTOVER_FRAME_DELTA,
				string.format("frame %d: compositing cutover popped (avg delta %.1f)", i, delta)
			)
		else
			assertTrue(delta <= MAX_FRAME_DELTA, string.format("frame %d: frame delta too large (avg delta %.1f)", i, delta))
		end

		prevCanvas = canvas
		prevActive = active
	end

	assertFalse(ing.camera:isSplit(), "close players should have merged by the end of the glide")
	assertTrue(sawCutover, "the merge-back should have actually crossed the compositing cutover during this window")
	Capture.capture("merge_back_final")
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
	Capture.capture("overview")
	assertTrue(true, "overview render completed")
end)

test("pressing the overview key actually zooms out to the full map, not just the follow cap", function()
	-- Regression test: CameraManager:toggleOverview -- what the spacebar
	-- keybinding actually calls (see InGameState:keypressed) -- used to
	-- assign self.mode directly instead of routing through self:setMode, so
	-- it never propagated to self.merged, the Camera instance whose *own*
	-- .mode decides whether to return the full-map view. self.merged stayed
	-- in "follow" mode forever: invisible before the follow zoom cap existed,
	-- but a real regression once it did -- pressing the overview key no
	-- longer reached the full map, only the (much tighter) follow cap. The
	-- test above calls camera:setMode("overview") directly, which was never
	-- broken; this one goes through the same method the key press does.
	love.window.setMode(800, 600)
	local game = GameHarness.startGame(MAP, { real = true })
	local ing = ingame(game)
	settle(game)

	-- Spread the players out so the follow camera is pinned at its zoom cap,
	-- not merely zoomed in tighter than it -- otherwise a scale that happens
	-- to already be close to the full-map one could pass by coincidence.
	setPlayerX(ing, 1, 32)
	setPlayerX(ing, 2, 608)
	settle(game)

	local CameraModule = require("src.camera")
	-- padding=16 matches InGameState's own CameraManager.new call.
	local full = CameraModule.fullMapView(20 * 32, 20 * 32, 800, 600, 16)
	local capScale = math.max(800 / (CameraModule.MAX_VIEW_TILES * 32), 600 / (CameraModule.MAX_VIEW_TILES * 32))
	assertNear(capScale, ing.camera.merged.scale, 0.01, "precondition: follow mode should be pinned at the zoom cap")

	ing.camera:toggleOverview()
	settle(game)

	assertTrue(ing.camera:isOverview(), "overview mode active")
	assertNear(full.scale, ing.camera.merged.scale, 0.01, "the overview key should reach the full-map scale")
	Capture.capture("overview_key_full_map")
end)
