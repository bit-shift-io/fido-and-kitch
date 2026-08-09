-- Anything-holds-it (no entity-type eligibility), enemy-follow-across, and
-- reset-on-restart, driven through the real Game/Map/World stack. The
-- spatial "no fall" / "wrong side blocked" acceptance criteria already have
-- headed coverage in tests/e2e/drawbridge_test.lua; this file covers what
-- doesn't need real rendering.
--
-- No enemy entity class exists in this project yet -- holding the bridge
-- only cares about collider.entity being set to something other than the
-- bridge itself, so a bare dynamic collider tagged {type = 'enemy'} stands
-- in for one, mirroring the fake-collider convention in
-- tests/unit/kill_zone_test.lua.
local GameHarness = require('tests.support.game_harness')
local FrameStepper = require('tests.support.frame_stepper')
local Queries = require('tests.support.queries')

local MAP = 'tests/fixtures/drawbridge_room.lua'

local GAP_START_X = 128
local GAP_END_X = 160
-- ground top (128) minus half the collider's own height (15) -- the height
-- a body resting on the fixture's ground/deck settles at
local RESTING_Y = 113

local function spawnEnemy(x)
	local enemy = Collider{
		shape_type = 'rectangle',
		shape_arguments = {0, 0, 20, 30},
		body_type = 'dynamic',
		position = {x = x, y = RESTING_Y},
	}
	enemy.entity = {type = 'enemy'}
	-- Two colliders with no groupIndex both read as nil, and nil == nil is
	-- true in Lua, so World.colFilter's own-group check (meant to make
	-- players ignore each other, see Player:init's setGroupIndex(-1)) also
	-- silently matches any two colliders that never set one at all -- every
	-- static terrain/deck/barrier collider included. Skip that trap: any
	-- concrete groupIndex distinct from the players' -1 collides normally.
	enemy:setGroupIndex(100)
	return enemy
end

-- Steps frames while continuously redriving horizontal velocity, the way a
-- real player (from live input) or a future enemy AI (from its own control
-- logic) would every frame -- not a one-shot setLinearVelocity before a
-- long stretch of stepping. A single stray one-frame collision (e.g. a
-- corner catch while gravity is still settling the body onto the ground)
-- can zero linearVelocityX; a controlled entity self-heals next frame
-- because it reasserts its intended velocity regardless, but a bare
-- collider given velocity once and left alone does not.
--
-- Callers should pass a non-integer px/s speed (97, not 60): at this
-- project's fixed 1/60s timestep, an exact-integer speed advances by a
-- whole pixel every frame and can land exactly on a tile boundary, which
-- hits a genuine bump (lib/bump) edge case that reports a permanent
-- blocking contact against a walkable surface's edge instead of a normal
-- pass-through. A fractional per-frame step (any non-multiple-of-60 speed)
-- never lands exactly on the boundary and never hits it.
local function walk(game, enemy, vx, frames)
	for _ = 1, frames do
		local _, vy = enemy:getLinearVelocity()
		enemy:setLinearVelocity(vx, vy)
		FrameStepper.step(game, 1)
	end
end

test('anything overlapping the trigger opens the bridge -- an enemy, with no eligibility to opt into', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 10)

	local bridge = Queries.findEntityByType(map, 'drawbridge')
	assertEqual('closed', Queries.drawbridgeState(bridge))

	local enemy = spawnEnemy(80)

	local opened = false
	for _ = 1, 120 do
		local _, vy = enemy:getLinearVelocity()
		enemy:setLinearVelocity(97, vy)
		FrameStepper.step(game, 1)
		local state = Queries.drawbridgeState(bridge)
		if state == 'opening' or state == 'open' then
			opened = true
			break
		end
	end

	assertTrue(opened, 'expected the enemy to open the bridge from the correct side -- nothing is ineligible')
end)

test('once open, an enemy can cross the deck without falling', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 10)

	local bridge = Queries.findEntityByType(map, 'drawbridge')
	-- bypass the approach and set up the "already open" precondition
	-- directly -- only the crossing itself is under test here
	bridge:setState('open')

	local enemy = spawnEnemy(80)
	walk(game, enemy, 97, 150) -- walk all the way across

	local finalX = enemy:getX()
	assertTrue(finalX > GAP_END_X, 'expected the enemy to have crossed onto the far side')
	-- falling into the pit would leave the enemy well below the walking
	-- surface; crossing safely keeps it at the same resting height
	assertNear(RESTING_Y, enemy:getY(), 2, 'expected the enemy to stay on its feet, not fall into the gap')
end)

test('every drawbridge resets to closed on level restart', function()
	local game = GameHarness.startGame(MAP)
	FrameStepper.step(game, 10)

	local bridge = Queries.findEntityByType(map, 'drawbridge')
	bridge:setState('open')
	assertEqual('open', Queries.drawbridgeState(bridge))

	game:load{map = MAP} -- InGameState:load rebuilds World/Map from scratch,
	-- the same path a real "restart level" menu action takes -- so a fresh
	-- drawbridge entity, starting closed, is the natural/only outcome; there
	-- is no reset hook to write or forget.

	local restarted = Queries.findEntityByType(map, 'drawbridge')
	assertTrue(restarted ~= bridge, 'expected a restart to instantiate a fresh drawbridge entity')
	assertEqual('closed', Queries.drawbridgeState(restarted), 'expected every drawbridge to reset to closed on restart')
end)
