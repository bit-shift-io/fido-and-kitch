-- Unit tests for the pushable props' pure decision helpers
-- (src.components.pushable.pushable_support). The entities themselves compose
-- Sprite/Collider and need love.graphics, so their behaviour is covered in
-- tests/integration/pushable_test.lua instead.
Class = Class or require('lib.hump.class')
local PushableSupport = require('src.components.pushable.pushable_support')

-- A plain rectangle object (no gid) is top-anchored: Tiled's y is the top
-- edge. This is the shape the hand-edited push_box objects already in
-- res/map/sandbox.tmx have.
test('a gid-less object is top-anchored -- its centre is half a tile below its y', function()
	local centreX, centreY = PushableSupport.spawnCentre({x = 160, y = 192, width = 32, height = 32})

	assertEqual(176, centreX)
	assertEqual(208, centreY)
end)

-- A tile object (with a gid, which is what res/templates/push_box.tx
-- produces when dragged in from Tiled's palette) is BOTTOM-anchored: Tiled's
-- y is the tile's bottom edge, so the centre sits half a tile ABOVE it. Same
-- convention src/entities/switch.lua already assumes for its gid object.
-- Getting this wrong places every template-placed prop one tile too low --
-- buried in the floor rather than resting on it.
test('a gid tile object is bottom-anchored -- its centre is half a tile above its y', function()
	local centreX, centreY = PushableSupport.spawnCentre({x = 160, y = 192, width = 32, height = 32, gid = 148})

	assertEqual(176, centreX)
	assertEqual(176, centreY)
end)

-- World.colFilter ignores a collision between two colliders whose
-- groupIndex matches (it exists so co-op players pass through each other),
-- and nil == nil is true in Lua. So a prop needs an index that is concrete
-- (or it passes through the terrain and falls out of the level), distinct
-- from the players' -1 (or it passes through them), and distinct from every
-- OTHER prop's (or props pass through each other -- a box stacked on a box
-- drops straight through it).
test('every pushable gets its own collision group, so props collide with each other', function()
	local first = PushableSupport.nextGroupIndex()
	local second = PushableSupport.nextGroupIndex()
	local third = PushableSupport.nextGroupIndex()

	assertTrue(first ~= second, 'expected two props to land in different collision groups')
	assertTrue(second ~= third, 'expected two props to land in different collision groups')
end)

test('a pushable never lands in the players\' collision group, or in none at all', function()
	for _ = 1, 20 do
		local groupIndex = PushableSupport.nextGroupIndex()
		assertTrue(groupIndex ~= nil, 'a nil groupIndex matches the terrain\'s and drops the prop through the floor')
		assertTrue(groupIndex ~= -1, 'the players\' group would let props pass through players')
	end
end)

-- Push direction is decided from the pusher's *input intent*, not its
-- velocity: once the prop blocks it, the physics layer zeroes the pusher's
-- horizontal velocity every frame, so velocity would read as "not pushing"
-- exactly when the push is hardest.
local function pusher(props)
	return {
		centreX = props.centreX,
		grounded = props.grounded ~= false,
		holdingLeft = props.holdingLeft or false,
		holdingRight = props.holdingRight or false,
	}
end

test('a grounded pusher on the prop\'s left holding right pushes it right', function()
	assertEqual(1, PushableSupport.pushDirection({pusher{centreX = 150, holdingRight = true}}, 176))
end)

test('a grounded pusher on the prop\'s right holding left pushes it left', function()
	assertEqual(-1, PushableSupport.pushDirection({pusher{centreX = 202, holdingLeft = true}}, 176))
end)

test('a pusher holding away from the prop does not push it', function()
	assertEqual(0, PushableSupport.pushDirection({pusher{centreX = 150, holdingLeft = true}}, 176))
end)

test('a pusher holding nothing does not push', function()
	assertEqual(0, PushableSupport.pushDirection({pusher{centreX = 150}}, 176))
end)

-- pushing is a walking action: a mid-air collision is just a block
test('an airborne pusher does not push, however it is holding', function()
	assertEqual(0, PushableSupport.pushDirection({pusher{centreX = 150, holdingRight = true, grounded = false}}, 176))
end)

-- co-op: two players shoving opposite faces cancel out rather than one
-- arbitrarily winning by query order
test('pushers on opposite faces cancel each other out', function()
	local both = {
		pusher{centreX = 150, holdingRight = true},
		pusher{centreX = 202, holdingLeft = true},
	}

	assertEqual(0, PushableSupport.pushDirection(both, 176))
end)

test('nobody adjacent means no push', function()
	assertEqual(0, PushableSupport.pushDirection({}, 176))
end)

test('a prop resting on the ground with nothing on it is pushable', function()
	assertTrue(PushableSupport.isPushableNow({}))
end)

-- stacking is predictable: shove the bottom prop out and the one above it
-- would be left hanging, so the bottom one simply refuses to move
test('a prop with another pushable resting on it is not pushable', function()
	assertFalse(PushableSupport.isPushableNow({pushableOnTop = true}))
end)

-- the default footgun guard: don't let a player slide the ground out from
-- under their own feet
test('a prop with a player standing on it is not pushable by default', function()
	assertFalse(PushableSupport.isPushableNow({playerOnTop = true}))
end)

-- the per-prop opt-in exists for deliberate co-op puzzles: one player rides
-- while the other pushes
test('allowPushWhenStoodOn opts a prop into being pushed with a player aboard', function()
	assertTrue(PushableSupport.isPushableNow({playerOnTop = true, allowPushWhenStoodOn = true}))
end)

-- the opt-in is about players only -- a stacked prop still hard-blocks
test('allowPushWhenStoodOn does not override a pushable resting on top', function()
	assertFalse(PushableSupport.isPushableNow({pushableOnTop = true, allowPushWhenStoodOn = true}))
end)

test('a prop in mid-air is not pushable', function()
	assertFalse(PushableSupport.isPushableNow({airborne = true}))
end)

-- The physics layer cancels the velocity component pushing into a surface
-- the frame a body lands (Motion.resolveCollisions), so a prop at rest reads
-- as exactly zero vertical velocity while a falling one does not. The
-- tolerance keeps a hair of float noise from reading as flight.
test('a prop with no vertical velocity is resting, not airborne', function()
	assertFalse(PushableSupport.isAirborne(0))
end)

test('a prop with real vertical velocity is airborne', function()
	assertTrue(PushableSupport.isAirborne(120))
end)

test('a hair of float noise in the vertical velocity is still resting', function()
	assertFalse(PushableSupport.isAirborne(0.0001))
end)

-- The prop keeps pace with whoever is pushing it (the PRD's "slides at the
-- player's walk speed"), taken from the pusher itself rather than a constant
-- duplicated here, so it cannot drift out of sync with Player.speed.
test('the push speed is the contributing pusher\'s own walk speed', function()
	local pushers = {pusher{centreX = 150, holdingRight = true}}
	pushers[1].speed = 100

	assertEqual(100, PushableSupport.pushSpeed(pushers, 176, 1))
end)

-- The pusher on the prop's right holding right is walking AWAY from it --
-- it contributes nothing to the rightward push, so its speed must not be the
-- one that sets the pace.
test('only pushers contributing to the chosen direction set the speed', function()
	local behind = pusher{centreX = 150, holdingRight = true}
	behind.speed = 100
	local walkingAway = pusher{centreX = 202, holdingRight = true}
	walkingAway.speed = 500

	assertEqual(100, PushableSupport.pushSpeed({behind, walkingAway}, 176, 1))
end)

test('nothing pushing means no speed', function()
	assertEqual(0, PushableSupport.pushSpeed({}, 176, 0))
end)

-- ADR 0001: falling is a snap event. The prop's centre-x decides which tile
-- it drops into, and it aligns to that tile's centre so a one-tile hole is
-- filled flush -- the whole point of the model over free-body teetering.
test('a prop drops into the tile its centre-x is over, aligned to that tile\'s centre', function()
	-- centre at 290 is just inside the tile spanning 288..320
	assertEqual(304, PushableSupport.snapTargetX(290, 32))
end)

test('a prop already at the tile centre stays there -- snapping is idempotent', function()
	assertEqual(304, PushableSupport.snapTargetX(304, 32))
end)

test('a prop whose centre is still over the previous tile snaps to that one', function()
	assertEqual(272, PushableSupport.snapTargetX(287, 32))
end)

-- exactly on a tile boundary belongs to the tile it is entering, matching
-- how the floor division falls out -- no ambiguous half-tile case
test('a centre exactly on a tile boundary snaps into the tile it is entering', function()
	assertEqual(304, PushableSupport.snapTargetX(288, 32))
end)

test('snapping works away from the origin and for other tile sizes', function()
	assertEqual(1008, PushableSupport.snapTargetX(1000, 32))
	assertEqual(24, PushableSupport.snapTargetX(20, 16))
end)

-- A prop that has come to rest becomes STATIC, so it behaves exactly like the
-- terrain it is filling in for. This is not an optimisation: a dynamic body
-- re-resolves gravity every frame, and a dynamic prop whose top is flush with
-- a walking surface makes lib/bump report the player's contact as a wall
-- (normal (-1,0)) instead of a step -- so a box filling a one-tile hole
-- BLOCKS the player rather than carrying them across, defeating the whole
-- mechanic. A static collider of identical geometry is crossed correctly, the
-- same way the drawbridge's static deck is. It goes dynamic again only when
-- it actually needs to move.
test('a prop that has settled with nothing pushing it rests as static terrain', function()
	assertEqual('static', PushableSupport.bodyTypeFor({supported = true}))
end)

test('a prop with nothing under its centre goes dynamic so gravity can take it', function()
	assertEqual('dynamic', PushableSupport.bodyTypeFor({supported = false}))
end)

-- it has landed on something but the physics step has not finished settling
-- it yet; going static here would freeze it hanging just above the surface
test('a prop still carrying vertical velocity stays dynamic even once supported', function()
	assertEqual('dynamic', PushableSupport.bodyTypeFor({supported = true, airborne = true}))
end)

test('a prop that is moving goes dynamic so the physics can carry it', function()
	assertEqual('dynamic', PushableSupport.bodyTypeFor({supported = true, moving = true}))
end)

-- A prop that is falling stops colliding with players, by borrowing the
-- players' own collision group (World.colFilter ignores a pair that shares
-- one). This is not cosmetic -- it is what keeps a filled hole walkable.
--
-- While a player pushes a prop, lib/bump clamps the player EXACTLY onto the
-- prop's side face. bump's rect_detectCollision counts exact touching as
-- "already intersecting" (its zero-area case), and from that state it blocks
-- a diagonal move outright with a horizontal normal -- the player's own
-- fractional gravity step is enough to make every subsequent frame diagonal.
-- So once the prop drops into the hole, a player left welded to where its
-- face used to be can never walk forward again: the filled hole becomes a
-- wall. Dropping the prop out of the player's way for the duration of the
-- fall means the player is never welded in the first place, and afterwards
-- they meet the landed prop mid-stride, which bump's corner-clip exemption
-- handles correctly.
--
-- Terrain keeps an unset (nil) group, so a falling prop still collides with
-- the ground normally and lands.
test('a falling prop shares the players\' group so it passes through them', function()
	assertEqual(-1, PushableSupport.groupIndexFor({supported = false}, 7))
end)

test('a prop still settling after a landing also passes through players', function()
	assertEqual(-1, PushableSupport.groupIndexFor({supported = true, airborne = true}, 7))
end)

test('a prop at rest takes back its own group, so it blocks players again', function()
	assertEqual(7, PushableSupport.groupIndexFor({supported = true}, 7))
end)

-- Roll mode (the boulder): a shove starts it and it then carries on under its
-- own momentum, unlike slide mode (the box) which only moves while pushed.
test('a shove sets the boulder rolling in that direction at that speed', function()
	assertEqual(100, PushableSupport.nextRollVelocity({pushVelocity = 100}))
end)

test('a rolling boulder keeps rolling once the player stops touching it', function()
	assertEqual(100, PushableSupport.nextRollVelocity({
		currentRoll = 100,
		pushVelocity = 0,
		resolvedVelocityX = 100,
	}))
end)

-- The physics layer cancels the velocity component pushing into a surface, so
-- a roll that was travelling at 100 and comes back resolved to 0 has hit
-- something -- a wall, another prop, or a player. That is the stop condition
-- for all three at once; no per-obstacle-type detection is needed.
test('a rolling boulder stops when its velocity has been cancelled by an obstacle', function()
	assertEqual(0, PushableSupport.nextRollVelocity({
		currentRoll = 100,
		pushVelocity = 0,
		resolvedVelocityX = 0,
	}))
end)

test('a rolling boulder that falls into a gap stops rolling', function()
	assertEqual(0, PushableSupport.nextRollVelocity({
		currentRoll = 100,
		pushVelocity = 0,
		resolvedVelocityX = 100,
		falling = true,
	}))
end)

-- being shoved the other way while already rolling wins over the momentum,
-- so a stopped-then-repushed boulder can be sent back where it came from
test('a fresh shove overrides the current roll, including reversing it', function()
	assertEqual(-100, PushableSupport.nextRollVelocity({
		currentRoll = 100,
		pushVelocity = -100,
		resolvedVelocityX = 100,
	}))
end)

test('a boulder nobody has touched is not rolling', function()
	assertEqual(0, PushableSupport.nextRollVelocity({}))
end)
