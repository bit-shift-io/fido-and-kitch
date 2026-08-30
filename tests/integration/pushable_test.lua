-- Pushable props driven through the real Game/Map/World/Player stack. The
-- pure geometry and gating decisions live in tests/unit/pushable_support_test.lua;
-- this file covers what only the real stack can answer -- does the prop
-- actually fall, rest, block, and carry a player.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local FakeInputModule = require('tests.support.fake_input')
local Queries = require('tests.support.queries')

local FakeInput = FakeInputModule.FakeInput
local holdFor = FakeInputModule.holdFor

local MAP = 'tests/fixtures/pushable_room.tmj'

-- see the fixture's header diagram
local SURFACE_TOP = 224
-- a 32x32 prop resting on the surface: centre is half its height above it
local BOX_RESTING_Y = SURFACE_TOP - 16
-- the top edge of a 32x32 prop resting on the surface
local BOX_TOP = 192
-- the player's physics collider is 20x30 (src/player/player.lua), so its
-- centre rests 15px above whatever it is standing on
local PLAYER_HALF_WIDTH = 10
local PLAYER_HALF_HEIGHT = 15

-- let the players fall from spawn onto the surface and settle into
-- WalkIdleState before driving any input
local function settle(game)
	FrameStepper.step(game, 60)
end

local function player1(game)
	return game.fsm.currentState.players[1]
end

test('a push_box placed in a map falls straight down and comes to rest on solid ground', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60)

	local box = Queries.findEntityByName(map, 'push_box')
	assertTrue(box ~= nil, 'expected the map to load a push_box entity')
	assertNear(BOX_RESTING_Y, box.collider:getY(), 1, 'expected the box to land on the surface')
	assertNear(176, box.collider:getX(), 0.5, 'expected the box to fall straight down, not drift sideways')
end)

-- The box slides away under a sustained push (see the slide test below), so
-- "cannot walk through it" is a relative invariant, not a fixed stopping
-- point: the player's leading edge never crosses the box's near face,
-- wherever the box has been shoved to by then.
test('a push_box blocks the player -- walking into it cannot pass through', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local box = Queries.findEntityByName(map, 'push_box')
	local player = player1(game)
	local startX = Queries.playerPositionV(player).x

	-- stops short of shoving the box as far as the hole, so this stays a test
	-- about blocking rather than about falling
	controller:press('right')
	for _ = 1, 60 do
		FrameStepper.step(game, 1)
		local playerRightEdge = Queries.playerPositionV(player).x + PLAYER_HALF_WIDTH
		local boxLeftEdge = box.collider:getX() - 16
		assertTrue(playerRightEdge <= boxLeftEdge + 1,
			'expected the player never to penetrate the box, but their edges overlapped')
	end
	controller:release('right')

	assertTrue(Queries.playerPositionV(player).x > startX + 50,
		'expected the player to have actually walked into the box, not merely idled short of it')
end)

-- A prop's own collider belongs to an entity, and Player:queryOnGround()
-- only treats an entity-owned collider as ground when it opts in via
-- collider.walkable. Without the opt-in the player is physically supported
-- but stuck in FallState -- standing on the box yet unable to walk.
test('the player can stand on top of a push_box as if it were solid ground', function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local box = Queries.findEntityByName(map, 'push_box')
	local player = player1(game)
	player.collider:setPosition(box.collider:getX(), BOX_TOP - PLAYER_HALF_HEIGHT)
	FrameStepper.step(game, 30)

	assertNear(BOX_TOP - PLAYER_HALF_HEIGHT, Queries.playerPositionV(player).y, 1,
		'expected the player to rest on the box\'s top, not sink through it')
	assertTrue(player:queryOnGround(),
		'expected the box to count as ground -- otherwise the player is stuck in FallState on top of it')
end)

-- The prop draws real art (res/img/pushable_crate_wood.png), not a
-- placeholder quad. What matters beyond "an image exists" is that it tracks
-- the collider: a sprite left at the spawn position would render the crate
-- hanging in the air while the physical box rests on the floor below it.
test('a push_box draws a sprite that follows its collider', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 60)

	local box = Queries.findEntityByName(map, 'push_box')
	assertTrue(box.sprite ~= nil, 'expected the box to have a sprite to draw')

	local spritePosition = box.sprite:getPositionV()
	assertNear(box.collider:getX(), spritePosition.x, 0.001, 'expected the sprite to track the collider horizontally')
	assertNear(box.collider:getY(), spritePosition.y, 0.001, 'expected the sprite to track the collider as it falls')
end)

-- walks P1 rightward until the box actually starts moving, so the
-- measurements below start from established contact rather than from the
-- approach walk
local function pushUntilMoving(game, controller, box)
	local startX = box.collider:getX()
	controller:press('right')
	for _ = 1, 180 do
		FrameStepper.step(game, 1)
		if box.collider:getX() > startX + 0.5 then
			return
		end
	end
	error('the player never got the box moving')
end

test('a grounded player walking into a box slides it at the player\'s walk speed', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local box = Queries.findEntityByName(map, 'push_box')
	local player = player1(game)
	pushUntilMoving(game, controller, box)

	local fromX = box.collider:getX()
	FrameStepper.step(game, 30) -- half a second of established pushing
	local travelled = box.collider:getX() - fromX

	-- the player's own walk speed is 100px/s (src/player/player.lua), so half
	-- a second of pushing is ~50px -- the box keeps pace with the pusher
	-- rather than crawling or being flung
	assertNear(player.speed * 0.5, travelled, 3, 'expected the box to slide at the player\'s walk speed')
end)

test('the box stops the instant the player releases the direction', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local box = Queries.findEntityByName(map, 'push_box')
	pushUntilMoving(game, controller, box)
	FrameStepper.step(game, 15)

	controller:release('right')
	FrameStepper.step(game, 1) -- the frame the release takes effect
	local restingX = box.collider:getX()
	FrameStepper.step(game, 60) -- a full second of nobody pushing

	assertNear(restingX, box.collider:getX(), 0.001,
		'expected the box to stop dead on release, with no coasting')
end)

-- pushing is a walking action: a player who collides with the prop in mid-air
-- is just blocked by it
test('an airborne player cannot push the box', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local box = Queries.findEntityByName(map, 'push_box')
	local player = player1(game)
	local boxX = box.collider:getX()

	-- flush against the box's left face, but held clear of the floor so the
	-- box's side -- not the ground -- is the only thing beside them
	player.collider:setPosition(boxX - 16 - PLAYER_HALF_WIDTH, 200)
	assertFalse(player:queryOnGround(), 'fixture check: the player should be airborne here')

	controller:press('right')
	FrameStepper.step(game, 10)
	controller:release('right')

	assertNear(boxX, box.collider:getX(), 0.001,
		'expected a mid-air player to be blocked by the box, not to push it')
end)

local function player2(game)
	return game.fsm.currentState.players[2]
end

-- stands P2 on the given prop and puts P1 flush against its left face, so a
-- press of 'right' is a genuine push attempt with a passenger aboard
local function setUpRiddenPush(game, box)
	local boxX = box.collider:getX()
	player2(game).collider:setPosition(boxX, BOX_TOP - PLAYER_HALF_HEIGHT)
	player1(game).collider:setPosition(boxX - 16 - PLAYER_HALF_WIDTH, BOX_RESTING_Y + 1)
	FrameStepper.step(game, 10)
end

test('a box with a player standing on it cannot be pushed', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local box = Queries.findEntityByName(map, 'push_box')
	setUpRiddenPush(game, box)
	local boxX = box.collider:getX()

	holdFor(game, controller, 'right', 1)

	assertNear(boxX, box.collider:getX(), 0.001,
		'expected a box with a player aboard to refuse to move by default')
end)

-- the co-op opt-in: one player rides while the other pushes
test('a box with allowPushWhenStoodOn set can be pushed with a player aboard', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local box = Queries.findEntityByName(map, 'ride_box')
	setUpRiddenPush(game, box)
	local boxX = box.collider:getX()

	holdFor(game, controller, 'right', 1)

	assertTrue(box.collider:getX() > boxX + 20,
		'expected the opted-in box to slide even with a player standing on it')
end)

-- stacking stays predictable: shoving the bottom prop out would leave the
-- one above it hanging, so the bottom one refuses. The opt-in above is about
-- players only and must not unblock this.
test('a box with another pushable resting on it cannot be pushed', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local box = Queries.findEntityByName(map, 'push_box')
	local stacked = Queries.findEntityByName(map, 'ride_box')
	stacked.collider:setPosition(box.collider:getX(), BOX_TOP - 16)
	FrameStepper.step(game, 10)

	local boxX = box.collider:getX()
	holdFor(game, controller, 'right', 1)

	assertNear(boxX, box.collider:getX(), 0.001,
		'expected a box with a prop stacked on it to refuse to move')
end)

-- puts P1 flush against the given prop's left face, standing on the surface
local function standBehind(game, box)
	player1(game).collider:setPosition(box.collider:getX() - 16 - PLAYER_HALF_WIDTH, BOX_RESTING_Y + 1)
	FrameStepper.step(game, 10)
end

-- no prop trains: only players push, so a prop shoved into another prop just
-- stops rather than shunting it along
test('pushing a box into another pushable moves neither of them onward', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local pushed = Queries.findEntityByName(map, 'ride_box')
	local blocker = Queries.findEntityByName(map, 'blocker_box')
	local blockerX = blocker.collider:getX()
	standBehind(game, pushed)

	holdFor(game, controller, 'right', 2)

	assertNear(blockerX - 32, pushed.collider:getX(), 1.5,
		'expected the pushed box to come to rest flush against the other prop')
	assertNear(blockerX, blocker.collider:getX(), 0.001,
		'expected the blocking prop to stay put -- a prop never shunts another prop along')
end)

test('pushing a box into a wall stops it at the wall', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	-- see the fixture: the right wall's face is at x=576
	local WALL_FACE = 576
	local box = Queries.findEntityByName(map, 'blocker_box')
	standBehind(game, box)

	holdFor(game, controller, 'right', 3)

	assertNear(WALL_FACE - 16, box.collider:getX(), 1.5,
		'expected the box to come to rest flush against the wall')
end)

-- see the fixture: the hole spans x=288..320, one tile deep, floor top at 256
local HOLE_CENTRE_X = 304
local HOLE_FLOOR_TOP = 256

-- ADR 0002's payoff: the box aligns to the hole's tile centre and drops
-- straight in, so it fills the gap flush instead of landing wedged
-- off-centre wherever momentum left it.
test('a box pushed over a one-tile hole snaps into it and fills it flush', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local box = Queries.findEntityByName(map, 'push_box')

	holdFor(game, controller, 'right', 4) -- long enough to shove it over the edge and let it settle

	assertNear(HOLE_CENTRE_X, box.collider:getX(), 0.5,
		'expected the box to align to the hole\'s tile centre')
	assertNear(HOLE_FLOOR_TOP - 16, box.collider:getY(), 1,
		'expected the box to come to rest on the hole floor, filling the gap')
	-- filling the gap means its top is flush with the surrounding surface
	assertNear(SURFACE_TOP, box.collider:getBounds().top, 1,
		'expected the filled hole to be flush with the walking surface')
end)

-- The counterpart to the snap: alignment is an EVENT, not the resting state.
-- A prop shoved along flat ground rests at whatever arbitrary x it was left
-- at -- props are not grid-locked (ADR 0002, DECISIONS Q7).
test('a box resting over solid ground keeps its arbitrary x -- no grid alignment', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local box = Queries.findEntityByName(map, 'push_box')
	pushUntilMoving(game, controller, box)
	FrameStepper.step(game, 7) -- a deliberately un-round shove
	controller:release('right')
	FrameStepper.step(game, 30)

	local restingX = box.collider:getX()
	local offsetWithinTile = restingX % map.tilewidth
	assertTrue(math.abs(offsetWithinTile - map.tilewidth * 0.5) > 1,
		'expected the box to rest off-centre within its tile, not snapped to the grid')
end)

-- Committed is committed: once a prop is falling it cannot be steered, and it
-- becomes pushable again the moment it lands.
test('a box in mid-air cannot be pushed, and is pushable again once it lands', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local box = Queries.findEntityByName(map, 'blocker_box')
	local boxX = box.collider:getX()
	-- lifted just clear of the surface: airborne, but still side-by-side with
	-- a player standing on the ground, so the push is genuinely attempted
	box.collider:setPosition(boxX, 190)
	player1(game).collider:setPosition(boxX - 16 - PLAYER_HALF_WIDTH, BOX_RESTING_Y + 1)

	controller:press('right')
	for _ = 1, 6 do
		FrameStepper.step(game, 1)
		assertNear(boxX, box.collider:getX(), 0.001,
			'expected a falling box to ignore the push and drop straight down')
	end

	FrameStepper.step(game, 45) -- land, then keep pushing
	controller:release('right')

	assertTrue(box.collider:getX() > boxX + 10,
		'expected the box to become pushable again once it landed')
end)

test('a box filling a hole is solid ground the player can walk across', function()
	local game = GameHarness.startGame(MAP)
	local controller = FakeInput.new()
	settle(game)

	local box = Queries.findEntityByName(map, 'push_box')
	local player = player1(game)

	-- one continuous walk: shove the box into the hole, then keep going and
	-- cross over it onto the far side
	holdFor(game, controller, 'right', 10)

	assertNear(HOLE_CENTRE_X, box.collider:getX(), 0.5, 'fixture check: the box should have filled the hole')
	assertTrue(Queries.playerPositionV(player).x > 320,
		'expected the player to have crossed the filled hole onto the far ground')
	assertNear(BOX_RESTING_Y + 1, Queries.playerPositionV(player).y, 2,
		'expected the player to stay at walking height the whole way -- never dropping into the gap')
end)

-- DECISIONS Q8: no buoyancy. Water is cosmetic tiles plus a kill_zone SENSOR,
-- and a prop crosses a sensor rather than being stopped by it, so a prop shoved
-- into water just keeps going until the map's own bottom boundary catches it.
-- It must not be destroyed, and must not stick to the sensor on the way down.
test('a box pushed into a bottomless water gap sinks to the map\'s bottom border', function()
	local PIT_MAP = 'tests/fixtures/pushable_pit_room.tmj'
	-- the fixture is 10 tiles tall, so the boundary's inner face is at y=320
	local MAP_BOTTOM = 320

	local game = GameHarness.startGame(PIT_MAP)
	local controller = FakeInput.new()
	settle(game)

	local box = Queries.findEntityByName(map, 'push_box')
	holdFor(game, controller, 'right', 5)

	assertNear(MAP_BOTTOM - 16, box.collider:getY(), 1,
		'expected the box to come to rest on the map\'s bottom boundary')
	assertTrue(box.collider:getX() > 160 and box.collider:getX() < 192,
		'expected the box to have sunk down the gap column, not drifted out of it')
end)
