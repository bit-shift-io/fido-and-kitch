-- Headless coverage for the ladder off toggle: a real merged Ladder entity
-- plus a collider standing in for a player overlapping its column, driven
-- through the real LadderState/FallState FSM. Hiding the ladder (a switch
-- with state == 'off') removes its climbing sensor from the world, so the
-- next LadderState update finds no overlap and falls through to FallState via
-- shouldFallOffLadder (src/player/player_states.lua:73). Toggling back on
-- restores the sensor, keeping any grown height.
require("tests.support.headless_bootstrap")

local HeadlessBootstrap = require("tests.support.headless_bootstrap")
local Ladder = require("src.entities.ladder")
local PlayerSensors = require("src.player.player_sensors")
local PlayerStates = require("src.player.player_states")
local StateMachine = require("src.components.state_machine")

local TILE = 32

-- Same rung construction as ladder_entity_test: bottom-anchored rungs tagged
-- with a merged ladderFamily rect and the lead on the lowest (largest y) rung.
local function makeFamilyRungs(height)
	local rungs = {}
	for i = 1, height do
		local y = 160 + i * TILE
		table.insert(rungs, {
			id = 100 + i,
			type = "ladder",
			x = 64,
			y = y,
			width = TILE,
			height = TILE,
			properties = {},
		})
	end
	local family = Rect({ x = 64, y = 160 + height * TILE, width = TILE, height = height * TILE })
	for i, rung in ipairs(rungs) do
		rung.ladderFamily = family
		rung.leadRung = (rung.y == family.y)
	end
	return rungs, family
end

local function makeLead(rungs)
	HeadlessBootstrap.resetWorld()
	local map = { map = { tileheight = TILE, tilewidth = TILE }, tileheight = TILE, tilewidth = TILE }
	return Ladder(rungs[#rungs], map), map
end

-- A player-shaped body whose collider overlaps the ladder column, wired to a
-- real StateMachine running real LadderState/FallState classes. The
-- animation/sound/input stubs are surfaces LadderState touches cosmetically.
local function makePlayer(x, y)
	local p = {
		speed = 100,
		slideSpeed = 30,
		climbSpeed = 30,
		verticalHeld = false,
		horizontalHeld = false,
		verticalNewlyPressed = false,
		horizontalNewlyPressed = false,
		previousLadderAxis = "vertical",
		animations = {
			currentState = {
				playing = false,
				setFrameNum = function() end,
			},
		},
		sound = { play = function() end },
		setAnimation = function() end,
		isDown = function()
			return false
		end,
	}
	p.collider = Collider({
		shape_type = "rectangle",
		shape_arguments = { 30, 40 },
		position = Vector(x, y),
	})
	p.fsm = StateMachine({
		stateClasses = PlayerStates,
		entity = p,
		currentState = "LadderState",
	})
	return p
end

test("a player overlapping an enabled ladder stays mounted", function()
	local rungs = makeFamilyRungs(3)
	local lead = makeLead(rungs)
	local player = makePlayer(80, 230)

	assertEqual(
		1,
		#PlayerSensors.queryAllLadders(world, player.collider),
		"fixture sanity: the player overlaps the ladder volume"
	)
	assertEqual("LadderState", player.fsm.currentState.name)
	player.fsm:update(1 / 60)
	assertEqual("LadderState", player.fsm.currentState.name, "overlap present -> no fall-off")
end)

test("hiding the ladder while the player overlaps falls through to FallState", function()
	local rungs = makeFamilyRungs(3)
	local lead = makeLead(rungs)
	local player = makePlayer(80, 200)

	assertEqual("LadderState", player.fsm.currentState.name)

	lead:switch({ state = "off" })
	assertEqual(
		0,
		#PlayerSensors.queryAllLadders(world, player.collider),
		"hide removed the climb sensor from the world"
	)

	player.fsm:update(1 / 60)
	assertEqual("FallState", player.fsm.currentState.name, "no overlap left -> shouldFallOffLadder -> FallState")
end)

test("toggling the ladder back on restores climbing, keeping any grown height", function()
	local rungs = makeFamilyRungs(2)
	local lead = makeLead(rungs)

	lead:grow(1)
	assertEqual(3 * TILE, lead.rect.height, "grown before the off/on cycle")

	lead:switch({ state = "off" })
	local player = makePlayer(80, 200)
	player.fsm:update(1 / 60)
	assertEqual("FallState", player.fsm.currentState.name, "off makes the player fall off")

	lead:switch({ state = "on" })
	assertEqual(1, #PlayerSensors.queryAllLadders(world, player.collider), "on restores the climb sensor")
	assertEqual(3 * TILE, lead.rect.height, "grown height survives the off/on cycle")
end)

local function assertOrder(expected, actual, message)
	assertEqual(#expected, #actual, tostring(message) .. " (length)")
	for i = 1, #expected do
		assertEqual(expected[i], actual[i], tostring(message) .. " at index " .. i)
	end
end

test("reveal order grows outward from the switch-targeted tile, alternating up/down", function()
	local rungs = makeFamilyRungs(5)
	local lead = makeLead(rungs)

	-- origin at sprite 2, five tiles -> 2,1,3,4,5
	assertOrder({ 2, 1, 3, 4, 5 }, lead:buildRevealOrder(2, 5), "outward order from a middle origin")

	-- no origin -> falls back to bottom (lead) tile; bottom-up sweep
	assertOrder({ 5, 4, 3, 2, 1 }, lead:buildRevealOrder(nil, 5), "default origin is the bottom tile")

	-- origin out of range clamps to the bottom
	assertOrder({ 3, 2, 1 }, lead:buildRevealOrder(99, 3), "out-of-range origin clamps to the bottom")
end)

test("tileIndexForY maps a switch-targeted rung bottom edge onto its tile band", function()
	local rungs = makeFamilyRungs(3)
	local lead = makeLead(rungs)
	-- family rect: x=64, y=160+3*TILE=256, height=96 -> top edge at 160.
	-- sprite 1 spans [160,192), 2 spans [192,224), 3 spans [224,256).
	assertEqual(1, lead:tileIndexForY(170), "rung in the top tile band")
	assertEqual(3, lead:tileIndexForY(240), "rung in the bottom tile band")
	assertEqual(3, lead:tileIndexForY(256), "rung bottom flush with ladder bottom -> last band")
	assertEqual(1, lead:tileIndexForY(100), "rung above the ladder clamps to the top")
end)

test("an enabled reveal makes tiles appear outward from the origin, one per delay", function()
	local rungs = makeFamilyRungs(5)
	local lead = makeLead(rungs)
	lead.revealDelay = 1

	-- origin at sprite 1 (top): order 1,2,3,4,5
	lead:startSpriteReveal({ y = 170 }, true)
	assertTrue(lead.revealActive, "reveal kicks off immediately")
	for _, s in ipairs(lead.sprites) do
		assertFalse(s.visible, "sprites start invisible when appearing")
	end

	lead:update(2.5) -- two delay steps elapse -> tiles 1,2 revealed
	local vis = {}
	for i, s in ipairs(lead.sprites) do
		vis[i] = s.visible
	end
	assertOrder({ true, true, false, false, false }, vis, "tiles appear outward from the origin")
	assertTrue(lead.revealActive, "not finished yet")
end)

test("a disabled reveal hides tiles outward from the origin while the volume is already gone", function()
	local rungs = makeFamilyRungs(5)
	local lead = makeLead(rungs)
	lead.revealDelay = 1

	lead:switch({ state = "off" })
	assertEqual(nil, lead.collider, "volume removed immediately on switch off")
	assertTrue(lead.revealActive, "sprites stagger out after the volume drops")
	for _, s in ipairs(lead.sprites) do
		assertTrue(s.visible, "sprites start visible when disappearing")
	end

	-- no origin -> outward order 5,4,3,2,1 reversed to 1,2,3,4,5: the top
	-- (farthest) tile hides first, converging inward toward the origin.
	lead:update(1.5)
	local vis = {}
	for i, s in ipairs(lead.sprites) do
		vis[i] = s.visible
	end
	assertOrder({ false, true, true, true, true }, vis, "tiles hide farthest-first, converging toward the origin")
end)

test("hiding converges inward toward the switch-targeted rung, not outward from it", function()
	local rungs = makeFamilyRungs(5)
	local lead = makeLead(rungs)
	lead.revealDelay = 1

	-- origin at sprite 3 (middle, y=240); outward appear order 3,2,4,1,5.
	-- Hide runs that in reverse: 5,1,4,2,3 -- the farthest tiles vanish first.
	lead:startSpriteReveal({ y = 240 }, false)
	assertOrder({ 5, 1, 4, 2, 3 }, lead.revealOrder, "hide traverses the outward order backwards")

	lead:update(1.5) -- first hide step
	local vis = {}
	for i, s in ipairs(lead.sprites) do
		vis[i] = s.visible
	end
	assertOrder({ true, true, true, true, false }, vis, "farthest tile hides first, origin stays visible")
end)
