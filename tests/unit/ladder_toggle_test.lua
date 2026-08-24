-- Headless coverage for the ladder off toggle: a real merged Ladder entity
-- plus a collider standing in for a player overlapping its column, driven
-- through the real LadderState/FallState FSM. Hiding the ladder (a switch
-- with state == 'off') removes its climbing sensor from the world, so the
-- next LadderState update finds no overlap and falls through to FallState via
-- shouldFallOffLadder (src/player/player_states.lua:73). Toggling back on
-- restores the sensor, keeping any grown height.
require('tests.support.headless_bootstrap')

local HeadlessBootstrap = require('tests.support.headless_bootstrap')
local Ladder = require('src.entities.ladder')
local PlayerSensors = require('src.player.player_sensors')
local PlayerStates = require('src.player.player_states')
local StateMachine = require('src.components.state_machine')

local TILE = 32

-- Same rung construction as ladder_entity_test: bottom-anchored rungs tagged
-- with a merged ladderFamily rect and the lead on the lowest (largest y) rung.
local function makeFamilyRungs(height)
	local rungs = {}
	for i = 1, height do
		local y = 160 + i * TILE
		table.insert(rungs, {
			id = 100 + i,
			type = 'ladder',
			x = 64,
			y = y,
			width = TILE,
			height = TILE,
			properties = {},
		})
	end
	local family = Rect{ x = 64, y = 160 + height * TILE, width = TILE, height = height * TILE }
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
		previousLadderAxis = 'vertical',
		animations = {
			currentState = {
				playing = false,
				setFrameNum = function() end,
			},
		},
		sound = { play = function() end },
		setAnimation = function() end,
		isDown = function() return false end,
	}
	p.collider = Collider{
		shape_type = 'rectangle',
		shape_arguments = { 30, 40 },
		position = Vector(x, y),
	}
	p.fsm = StateMachine{
		stateClasses = PlayerStates,
		entity = p,
		currentState = 'LadderState',
	}
	return p
end

test('a player overlapping an enabled ladder stays mounted', function()
	local rungs = makeFamilyRungs(3)
	local lead = makeLead(rungs)
	local player = makePlayer(80, 230)

	assertEqual(1, #PlayerSensors.queryAllLadders(world, player.collider),
		'fixture sanity: the player overlaps the ladder volume')
	assertEqual('LadderState', player.fsm.currentState.name)
	player.fsm:update(1 / 60)
	assertEqual('LadderState', player.fsm.currentState.name,
		'overlap present -> no fall-off')
end)

test('hiding the ladder while the player overlaps falls through to FallState', function()
	local rungs = makeFamilyRungs(3)
	local lead = makeLead(rungs)
	local player = makePlayer(80, 200)

	assertEqual('LadderState', player.fsm.currentState.name)

	lead:switch({ state = 'off' })
	assertEqual(0, #PlayerSensors.queryAllLadders(world, player.collider),
		'hide removed the climb sensor from the world')

	player.fsm:update(1 / 60)
	assertEqual('FallState', player.fsm.currentState.name,
		'no overlap left -> shouldFallOffLadder -> FallState')
end)

test('toggling the ladder back on restores climbing, keeping any grown height', function()
	local rungs = makeFamilyRungs(2)
	local lead = makeLead(rungs)

	lead:grow(1)
	assertEqual(3 * TILE, lead.rect.height, 'grown before the off/on cycle')

	lead:switch({ state = 'off' })
	local player = makePlayer(80, 200)
	player.fsm:update(1 / 60)
	assertEqual('FallState', player.fsm.currentState.name, 'off makes the player fall off')

	lead:switch({ state = 'on' })
	assertEqual(1, #PlayerSensors.queryAllLadders(world, player.collider),
		'on restores the climb sensor')
	assertEqual(3 * TILE, lead.rect.height, 'grown height survives the off/on cycle')
end)