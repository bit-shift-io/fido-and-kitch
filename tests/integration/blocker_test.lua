-- The blocker driven through the real Game/Map/World/Player stack. The pure
-- decision logic and the entity's own wiring live in
-- tests/unit/blocker_test.lua; this file covers what only real physics can
-- answer -- does a locked blocker actually stop a walking player, does it
-- stop a shoved prop just the same, and does the timing asymmetry hold
-- against real animation.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Queries = require('tests.support.queries')

local FakeInput = FakeInputModule.FakeInput

local MAP = 'tests/fixtures/blocker_room.lua'

-- see the fixture's header diagram
local BLOCKER_CENTRE_X = 304
local BARRIER_HALF_WIDTH = 9.6 -- 60% of a 32px object, halved
-- the player's physics collider is 20x30 (src/player/player.lua), so its
-- centre rests 15px above the walking surface at y=224
local PLAYER_HALF_WIDTH = 10
local PLAYER_RESTING_Y = 209

local function player1(game)
	return game.fsm.currentState.players[1]
end

-- let the players fall from spawn onto the surface and settle into
-- WalkIdleState before driving any input
local function settle(game)
	FrameStepper.step(game, 60)
end

local function walkRight(game, controller, frames)
	controller:press('right')
	FrameStepper.step(game, frames)
	controller:release('right')
end

test('a blocker object placed in a map loads as a locked, solid entity', function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local blocker = Queries.findEntityByType(map, 'blocker')
	assertTrue(blocker ~= nil, 'expected the map to load a blocker entity')
	assertEqual('closed', blocker.state)
	assertFalse(blocker.barrier:isSensor(), 'a locked blocker must present a solid barrier')
end)

test('a locked blocker stops a walking player -- they cannot pass through it', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local player = player1(game)
	local startX = Queries.playerPositionV(player).x

	walkRight(game, controller, 300)

	local finalX = Queries.playerPositionV(player).x
	assertTrue(finalX > startX + 50, 'expected the player to actually walk toward the blocker, not idle at spawn')
	assertTrue(finalX + PLAYER_HALF_WIDTH <= BLOCKER_CENTRE_X - BARRIER_HALF_WIDTH + 1,
		string.format('expected the player to stop at the barrier, but they reached x=%.1f', finalX))
end)

test('a locked blocker stops a pushed box too -- there is no entity-type eligibility', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local box = Queries.findEntityByName(map, 'push_box')
	assertTrue(box ~= nil, 'expected the map to load a push_box entity')
	local startX = box.collider:getX()

	-- the box lives on the far side of the blocker (see the fixture's
	-- diagram), so the player is placed out there with it and shoves it back
	-- leftward into the barrier
	local player = player1(game)
	player.collider:setPosition(box.collider:getX() + 40, PLAYER_RESTING_Y)
	FrameStepper.step(game, 30)

	controller:press('left')
	FrameStepper.step(game, 600)
	controller:release('left')

	local finalX = box.collider:getX()
	assertTrue(finalX < startX - 20, 'expected the box to actually be shoved toward the blocker')
	assertTrue(finalX - 16 >= BLOCKER_CENTRE_X + BARRIER_HALF_WIDTH - 1,
		string.format('expected the box to stop at the barrier, but it reached x=%.1f', finalX))
end)

-- Switch:use(user) is the public entry point Usable:use forwards to once a
-- player has walked up and pressed use; calling it directly (the precedent
-- set by tests/integration/switch_sound_test.lua) keeps these tests about
-- the blocker rather than about reproducing the press choreography.
local function flipSwitch(game)
	Queries.findEntityByName(map, 'switch1'):use(player1(game))
end

-- The core timing asymmetry under real physics: the blocker stays solid for
-- the whole 1s opening animation -- no pass-through mid-open -- and only
-- lets a player cross once it is fully open.
test('the blocker stays solid through its whole opening animation -- no pass-through mid-open', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local blocker = Queries.findEntityByType(map, 'blocker')
	local player = player1(game)
	player.collider:setPosition(BLOCKER_CENTRE_X - 30, PLAYER_RESTING_Y)
	FrameStepper.step(game, 10)

	flipSwitch(game)
	FrameStepper.step(game, 10) -- 10/60s of the 1s opening animation elapsed
	assertEqual('opening', blocker.state, 'fixture check: expected the blocker to still be opening')

	walkRight(game, controller, 20)
	assertEqual('opening', blocker.state, 'fixture check: the 1s opening animation should not have finished yet')
	assertTrue(Queries.playerPositionV(player).x + PLAYER_HALF_WIDTH <= BLOCKER_CENTRE_X - BARRIER_HALF_WIDTH + 1,
		'expected the still-opening blocker to keep blocking the player')

	FrameStepper.step(game, 40) -- let the opening animation finish
	assertEqual('open', blocker.state)

	walkRight(game, controller, 300)
	assertTrue(Queries.playerPositionV(player1(game)).x > BLOCKER_CENTRE_X + 32,
		'expected the player to cross through once the blocker is fully open')
end)

test('flipping the switch back off relocks the blocker instantly -- solid again the very same frame', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local blocker = Queries.findEntityByType(map, 'blocker')
	flipSwitch(game) -- on
	FrameStepper.step(game, 125) -- let the blocker finish opening (1s animation)
	assertEqual('open', blocker.state)

	flipSwitch(game) -- off again, with nobody in the doorway
	FrameStepper.step(game, 1)

	assertEqual('closed', blocker.state, 'expected the blocker to be closed one frame after the switch flips off')
	assertFalse(blocker.barrier:isSensor(), 'expected the relocked blocker to be solid immediately, no animation delay')

	walkRight(game, controller, 300)

	assertTrue(Queries.playerPositionV(player1(game)).x + PLAYER_HALF_WIDTH <= BLOCKER_CENTRE_X - BARRIER_HALF_WIDTH + 1,
		'expected the relocked blocker to stop the player at the barrier again')
end)

-- Regression guard for the real blocker.tx template (res/editor/blocker.tx):
-- its spriteOffsetY property must actually reach an instance through the
-- full template -> object merge, and must shift ONLY the art. Notably, when
-- this template was authored by hand with a self-closed <object/> and the
-- <properties> block dangling outside it, the xml parser rejected the whole
-- file ("Unbalanced Tag (/object)") and sandbox.tmx stopped loading entirely
-- -- this test exists to make that failure mode loud.
test('the real blocker.tx template feeds spriteOffsetY into the sandbox instance, shifting only the art', function()
	local game = GameHarness.startGame('res/map/sandbox.tmx')
	FrameStepper.step(game, 30)

	local blocker = Queries.findEntityByType(map, 'blocker')
	assertTrue(blocker ~= nil, 'expected sandbox to load a blocker -- a malformed blocker.tx fails the whole map load')

	-- sandbox blocker object: x=256 y=224, 32x64 -> bottom-anchored centre
	-- (272, 192); the template's spriteOffsetY=14 drops only the sprite
	assertEqual(14, blocker.object.properties.spriteOffsetY, 'the template property must be inherited by the instance')
	assertEqual(272, blocker.barrier:getPositionV().x)
	assertEqual(192, blocker.barrier:getPositionV().y, 'the barrier must stay on the authored rect centre')
	assertEqual(272, blocker.sprite.position.x)
	assertEqual(206, blocker.sprite.position.y, 'the art sits 14px below the authored centre')
end)