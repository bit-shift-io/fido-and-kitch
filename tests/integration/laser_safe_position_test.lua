-- End-to-end coverage for the destructible-tile exclusion in
-- src/player/player.lua's grounded gate (see src/player/player_sensors.lua's
-- queryOnDestructibleTile): a destructible_tile can be blown up later by an
-- unrelated laser elsewhere on the map, so standing on one -- even long
-- enough to normally qualify -- must never become the player's recorded
-- last-safe-position, or a respawn could drop them straight into the open
-- pit the tile used to bridge.
--
-- tests/fixtures/laser_safe_position_room.tmj: two ordinary ground segments
-- (ground_left, ground_right) either side of a one-tile gap bridged by a
-- floor-mounted destructible_tile ('bridge_tile'), with a laser embedded in
-- the same row just past the tile's far edge, aimed back at it, so the beam
-- destroys the tile without ever touching a player standing on top of it
-- (the beam travels through the tile's own body, below the player's feet).
-- The laser is authored `enabled = false` and switched on explicitly by the
-- test at the moment it's needed -- a free-running laser would otherwise
-- destroy the tile within its first ~45 frames (POWER_DURATION plus a few
-- removal frames), well before the test gets to stand the player on it.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')

local MAP = 'tests/fixtures/laser_safe_position_room.tmj'

-- comfortably past SafePosition's DEFAULT_THRESHOLD (0.5s = 30 frames @60fps)
local SETTLE_FRAMES = 90
local PAST_THRESHOLD_FRAMES = 40

local function player1(game)
	return game.fsm.currentState.players[1]
end

test('a player standing on ordinary ground has it recorded as their last-safe-position, unaffected', function()
	local game = GameHarness.startGame(MAP)
	local player = player1(game)

	FrameStepper.step(game, SETTLE_FRAMES)

	local restingX = player.collider:getX()
	local restingY = player.collider:getY()
	assertEqual(restingX, player.safePosition.x, 'expected ordinary grounded terrain to be recorded as safe (x)')
	assertEqual(restingY, player.safePosition.y, 'expected ordinary grounded terrain to be recorded as safe (y)')
end)

test('standing on a destructible tile bridging a gap never becomes the safe position, even after it is destroyed', function()
	local game = GameHarness.startGame(MAP)
	local player = player1(game)

	-- settle on ordinary ground first, past the stability threshold, so the
	-- safe position is seeded to real, permanent terrain
	FrameStepper.step(game, SETTLE_FRAMES)
	local groundSafeX = player.safePosition.x
	local groundSafeY = player.safePosition.y
	assertEqual(player.collider:getX(), groundSafeX, 'fixture check: safe position seeded from ordinary ground (x)')
	assertEqual(player.collider:getY(), groundSafeY, 'fixture check: safe position seeded from ordinary ground (y)')

	local tile = Queries.findEntityByName(map, 'bridge_tile')
	local laser = Queries.findEntityByName(map, 'laser_tile')
	assertTrue(tile ~= nil, 'expected the fixture to load bridge_tile')
	assertTrue(laser ~= nil, 'expected the fixture to load laser_tile')

	-- step sideways onto the bridge tile (same resting height as the ground
	-- either side of the gap) and stay there well past the stability
	-- threshold -- long enough to normally qualify as a new safe position
	player.collider:setPosition(tile.collider:getX(), player.collider:getY())
	FrameStepper.step(game, PAST_THRESHOLD_FRAMES)

	assertEqual(groundSafeX, player.safePosition.x,
		'expected standing on a destructible tile to never update the safe position (x)')
	assertEqual(groundSafeY, player.safePosition.y,
		'expected standing on a destructible tile to never update the safe position (y)')

	-- now switch the laser on (aimed at the tile from its far edge, never
	-- touching the player standing on top) and let it destroy the tile while
	-- the player is still standing there
	laser:getComponent(Switchable):switch({state = 'on'})
	local frames = 0
	while not laser:isFullyOn() and frames < 40 do
		FrameStepper.step(game, 1)
		frames = frames + 1
	end
	assertTrue(laser:isFullyOn(), 'expected the laser to reach full power within 40 frames')
	FrameStepper.step(game, 5) -- give the map's removal pass a few frames to land

	assertTrue(Queries.findEntityByName(map, 'bridge_tile') == nil,
		'expected the destructible tile to have been destroyed while the player stood on it')
	assertEqual(groundSafeX, player.safePosition.x,
		'expected the safe position to still point at the earlier ordinary ground, not the destroyed tile (x)')
	assertEqual(groundSafeY, player.safePosition.y,
		'expected the safe position to still point at the earlier ordinary ground, not the destroyed tile (y)')
end)
