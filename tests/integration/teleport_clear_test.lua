-- Teleporter tile clearing, driven through the real Game/Map/World/Player
-- stack. The pure decision logic (which direction to push, whether a tile is
-- occupied) lives in tests/unit/pushable_support_test.lua; this file covers
-- what only the real stack can answer -- does the box actually slide, does
-- the player actually (not) travel.
--
-- Teleport:use is called directly on the entity, the same way
-- switchable_teleport_test.lua calls Switch:use directly -- the walk-up-and-
-- press choreography is covered generically elsewhere and isn't the point
-- of these assertions.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')

local MAP = 'tests/fixtures/teleport_clear_room.tmj'
local BLOCKED_MAP = 'tests/fixtures/teleport_clear_blocked_room.tmj'

-- see the fixtures' teleport_a/teleport_b objects: both sit on the floor
-- tile spanning y=192..224
local BOX_RESTING_Y = 208
local TILE_WIDTH = 32

local function player1(game)
	return game.fsm.currentState.players[1]
end

local function settle(game)
	FrameStepper.step(game, 60)
end

local function travelled(game)
	return player1(game).fsm.currentState.name == 'TeleportTravelState'
end

test('using a teleporter with both source and destination clear teleports as before', function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local teleportA = Queries.findEntityByName(map, 'teleport_a')
	teleportA:use(player1(game))

	assertTrue(travelled(game), 'expected the player to start travelling when both tiles are clear')
end)

test('a box overlapping the source tile from the left is pushed one tile left, then the player teleports', function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local box = Queries.findEntityByName(map, 'push_box')
	local teleportA = Queries.findEntityByName(map, 'teleport_a')
	-- centre 168 sits left of the tile's own centre (176), overlapping from the left
	box.collider:setPosition(168, BOX_RESTING_Y)
	FrameStepper.step(game, 5) -- let it settle at the set position

	local startX = box.collider:getX()
	teleportA:use(player1(game))
	FrameStepper.step(game, 60) -- long enough for the scripted push to finish

	assertNear(startX - TILE_WIDTH, box.collider:getX(), 2, 'expected the box to have slid one tile left')
	assertTrue(travelled(game), 'expected the player to teleport once the source tile cleared')
end)

test('a box overlapping the source tile from the right is pushed one tile right, then the player teleports', function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local box = Queries.findEntityByName(map, 'push_box')
	local teleportA = Queries.findEntityByName(map, 'teleport_a')
	-- centre 184 sits right of the tile's own centre (176), overlapping from the right
	box.collider:setPosition(184, BOX_RESTING_Y)
	FrameStepper.step(game, 5)

	local startX = box.collider:getX()
	teleportA:use(player1(game))
	FrameStepper.step(game, 60)

	assertNear(startX + TILE_WIDTH, box.collider:getX(), 2, 'expected the box to have slid one tile right')
	assertTrue(travelled(game), 'expected the player to teleport once the source tile cleared')
end)

test('a boulder overlapping the source tile is pushed clear too, not just push_box', function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local boulder = Queries.findEntityByName(map, 'boulder')
	local teleportA = Queries.findEntityByName(map, 'teleport_a')
	boulder.collider:setPosition(168, BOX_RESTING_Y)
	FrameStepper.step(game, 5)

	local startX = boulder.collider:getX()
	teleportA:use(player1(game))
	FrameStepper.step(game, 60)

	assertNear(startX - TILE_WIDTH, boulder.collider:getX(), 2, 'expected the boulder to have slid one tile left')
	assertTrue(travelled(game), 'expected the player to teleport once the source tile cleared')
end)

test('the destination tile having any pushable overlapping it blocks the teleport entirely', function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local box = Queries.findEntityByName(map, 'push_box')
	local teleportA = Queries.findEntityByName(map, 'teleport_a')
	-- 496 is the destination teleporter's own tile centre
	box.collider:setPosition(496, BOX_RESTING_Y)
	FrameStepper.step(game, 5)
	local boxX = box.collider:getX()

	teleportA:use(player1(game))
	FrameStepper.step(game, 60)

	assertFalse(travelled(game), 'expected the teleport to be blocked by the occupied destination')
	assertNear(boxX, box.collider:getX(), 0.001, 'expected nothing at the destination to be pushed or moved')
end)

test('a source-tile box whose escape cell is blocked by a wall prevents the teleport entirely', function()
	local game = GameHarness.startGame(BLOCKED_MAP)
	settle(game)

	local box = Queries.findEntityByName(map, 'pusher_box')
	local teleportA = Queries.findEntityByName(map, 'teleport_a')
	-- centre 188 overlaps the tile from the right, whose escape cell (192..224) is walled
	box.collider:setPosition(188, BOX_RESTING_Y)
	FrameStepper.step(game, 5)
	local boxX = box.collider:getX()

	teleportA:use(player1(game))
	FrameStepper.step(game, 60)

	assertFalse(travelled(game), 'expected a wall-blocked escape to prevent the teleport')
	assertNear(boxX, box.collider:getX(), 0.001, 'expected the box not to move at all')
end)

-- Regression: props aren't grid-locked (ADR 0001), and a box brought to rest
-- against something can end up grazing the neighbouring tile's edge by a
-- stray pixel or two from float residue in collision resolution, rather than
-- sitting exactly flush. A sliver like that must not read as "the box is on
-- this tile" -- otherwise a box resting one tile away, with its own escape
-- wall on the far side, wrongly stalls the teleporter on an escape check
-- that should never have run.
test('a box merely grazing the source tile\'s edge by a sliver does not gate the teleporter', function()
	local game = GameHarness.startGame(BLOCKED_MAP)
	settle(game)

	local box = Queries.findEntityByName(map, 'pusher_box')
	local teleportA = Queries.findEntityByName(map, 'teleport_a')
	-- tile is 160..192; centre 145 (spans 129..161) grazes the left edge by
	-- just 1px -- nowhere near actually resting on the tile
	box.collider:setPosition(145, BOX_RESTING_Y)
	FrameStepper.step(game, 5)
	local boxX = box.collider:getX()

	teleportA:use(player1(game))
	FrameStepper.step(game, 60)

	assertNear(boxX, box.collider:getX(), 0.001, 'expected a mere graze not to trigger a push')
	assertTrue(travelled(game), 'expected a mere graze not to gate the teleporter at all')
end)

-- Regression: teleport.tj is authored 64x64 (2x2 tiles) purely so the USE
-- sensor reads across the whole tall sprite, not because a pushable can
-- ever rest anywhere but the one floor tile at its base. A box resting a
-- genuine full tile away -- flush against the ground tile's edge, no
-- overlap with it at all -- still grazes the oversized sensor's decorative
-- overhang by a wide margin (16px here), which must not gate the
-- teleporter either.
test('a box resting flush against a full tile away, only grazing the 2x2 sensor\'s overhang, does not gate the teleporter', function()
	local game = GameHarness.startGame(MAP)
	settle(game)

	local box = Queries.findEntityByName(map, 'push_box')
	local teleportA = Queries.findEntityByName(map, 'teleport_a')
	-- teleport_a's ground tile is 160..192 (its footprint spans 144..208);
	-- centre 144 (spans 128..160) sits flush against the tile's left edge --
	-- a genuine tile away, not on it -- while still overlapping the sensor's
	-- 144..208 footprint by 16px
	box.collider:setPosition(144, BOX_RESTING_Y)
	FrameStepper.step(game, 5)
	local boxX = box.collider:getX()

	teleportA:use(player1(game))
	FrameStepper.step(game, 60)

	assertNear(boxX, box.collider:getX(), 0.001, 'expected a box a genuine tile away not to be pushed')
	assertTrue(travelled(game), 'expected a box a genuine tile away not to gate the teleporter at all')
end)

test('a source-tile box whose escape cell is blocked by another pushable prevents the teleport entirely', function()
	local game = GameHarness.startGame(BLOCKED_MAP)
	settle(game)

	local box = Queries.findEntityByName(map, 'pusher_box')
	local teleportA = Queries.findEntityByName(map, 'teleport_a')
	-- centre 164 overlaps the tile from the left, whose escape cell (128..160)
	-- is occupied by the fixture's blocker_box -- no chain push (DECISIONS.md Q3)
	box.collider:setPosition(164, BOX_RESTING_Y)
	FrameStepper.step(game, 5)
	local boxX = box.collider:getX()

	teleportA:use(player1(game))
	FrameStepper.step(game, 60)

	assertFalse(travelled(game), 'expected an escape cell blocked by another pushable to prevent the teleport')
	assertNear(boxX, box.collider:getX(), 0.001, 'expected the box not to move at all')
end)
