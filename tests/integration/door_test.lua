-- The door driven through the real Game/Map/World/Player stack. The pure
-- decision logic and the entity's own wiring live in
-- tests/unit/door_test.lua; this file covers what only real physics can
-- answer -- does a locked door actually stop a walking player, and does it
-- stop a shoved prop just the same.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Queries = require('tests.support.queries')

local FakeInput = FakeInputModule.FakeInput

local MAP = 'tests/fixtures/door_room.lua'

-- see the fixture's header diagram
local DOOR_CENTRE_X = 304
local BARRIER_HALF_WIDTH = 4 -- 25% of a 32px object, halved
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

test('a door object placed in a map loads as a locked, solid entity', function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local door = Queries.findEntityByType(map, 'door')
	assertTrue(door ~= nil, 'expected the map to load a door entity')
	assertEqual('closed', door.state)
	assertFalse(door.barrier:isSensor(), 'a locked door must present a solid barrier')
end)

test('a locked door stops a walking player -- they cannot pass through it', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local player = player1(game)
	local startX = Queries.playerPositionV(player).x

	walkRight(game, controller, 300)

	local finalX = Queries.playerPositionV(player).x
	assertTrue(finalX > startX + 50, 'expected the player to actually walk toward the door, not idle at spawn')
	assertTrue(finalX + PLAYER_HALF_WIDTH <= DOOR_CENTRE_X - BARRIER_HALF_WIDTH + 1,
		string.format('expected the player to stop at the barrier, but they reached x=%.1f', finalX))
end)

test('a locked door stops a pushed box too -- there is no entity-type eligibility', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local box = Queries.findEntityByName(map, 'push_box')
	assertTrue(box ~= nil, 'expected the map to load a push_box entity')
	local startX = box.collider:getX()

	-- the box lives on the far side of the door (see the fixture's diagram),
	-- so the player is placed out there with it and shoves it back leftward
	-- into the barrier
	local player = player1(game)
	player.collider:setPosition(box.collider:getX() + 40, PLAYER_RESTING_Y)
	FrameStepper.step(game, 30)

	controller:press('left')
	FrameStepper.step(game, 600)
	controller:release('left')

	local finalX = box.collider:getX()
	assertTrue(finalX < startX - 20, 'expected the box to actually be shoved toward the door')
	assertTrue(finalX - 16 >= DOOR_CENTRE_X + BARRIER_HALF_WIDTH - 1,
		string.format('expected the box to stop at the barrier, but it reached x=%.1f', finalX))
end)

-- Switch:use(user) is the public entry point Usable:use forwards to once a
-- player has walked up and pressed use; calling it directly (the precedent
-- set by tests/integration/switch_sound_test.lua) keeps these tests about
-- the door rather than about reproducing the press choreography.
local function flipSwitch(game)
	Queries.findEntityByName(map, 'switch1'):use(player1(game))
end

test('flipping the linked switch on lets the player walk through the door', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local door = Queries.findEntityByType(map, 'door')
	flipSwitch(game)
	FrameStepper.step(game, 60) -- let the door finish opening

	assertEqual('open', door.state)
	walkRight(game, controller, 300)

	assertTrue(Queries.playerPositionV(player1(game)).x > DOOR_CENTRE_X + 32,
		'expected the player to cross the doorway and come out the far side')
end)

test('flipping the switch back off relocks the door and blocks the player again', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local door = Queries.findEntityByType(map, 'door')
	flipSwitch(game) -- on
	FrameStepper.step(game, 60)
	flipSwitch(game) -- off again, with nobody in the doorway
	FrameStepper.step(game, 60)

	assertEqual('closed', door.state)

	walkRight(game, controller, 300)

	assertTrue(Queries.playerPositionV(player1(game)).x + PLAYER_HALF_WIDTH <= DOOR_CENTRE_X - BARRIER_HALF_WIDTH + 1,
		'expected the relocked door to stop the player at the barrier again')
end)

-- A switch must never be able to seal a player into the doorway: the door
-- defers its close while anything overlaps, for as long as that takes.
test('a switch flipped off while a player stands in the doorway cannot seal them in', function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local door = Queries.findEntityByType(map, 'door')
	flipSwitch(game)
	FrameStepper.step(game, 60)

	local player = player1(game)
	player.collider:setPosition(DOOR_CENTRE_X, PLAYER_RESTING_Y)
	FrameStepper.step(game, 10)

	flipSwitch(game) -- off, with the player standing right in the doorway
	FrameStepper.step(game, 300)

	assertFalse(door.state == 'closed', 'expected the door to stay open around the player, not close on them')
	assertTrue(door.barrier:isSensor(), 'expected the doorway to stay passable while occupied')
	assertNear(DOOR_CENTRE_X, Queries.playerPositionV(player).x, 4,
		'expected the player to still be standing in the doorway, not shoved out by it')
end)

test('the door closes by itself once the player walks clear, with no further switch input', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local door = Queries.findEntityByType(map, 'door')
	flipSwitch(game)
	FrameStepper.step(game, 60)

	local player = player1(game)
	player.collider:setPosition(DOOR_CENTRE_X, PLAYER_RESTING_Y)
	FrameStepper.step(game, 10)
	flipSwitch(game) -- off
	FrameStepper.step(game, 60)
	assertFalse(door.state == 'closed', 'fixture check: expected the occupant to be holding the door open')

	walkRight(game, controller, 120) -- step clear of the doorway
	FrameStepper.step(game, 120)

	assertEqual('closed', door.state, 'expected the cleared doorway alone to finish the close')
	assertFalse(door.barrier:isSensor(), 'expected the closed door to be solid again')
end)
