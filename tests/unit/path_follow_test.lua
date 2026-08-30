-- Unit tests for src/components/path_follow.lua's solid-collision handling:
-- a PathFollow drives the player kinematically along a scripted path, which
-- would otherwise cross every collider (kinematic bodies cross everything --
-- see World.colFilter). These tests exercise the real bump World/Collider
-- query underneath the check, the same way ground_support_test.lua does.
local LoveMock = require('tests.support.love_mock')
love = LoveMock.new() -- Path needs love.math.newBezierCurve

local HeadlessBootstrap = require('tests.support.headless_bootstrap')
local World = require('src.physics.bump.world')
local Path = require('src.components.path')
local PathFollow = require('src.components.path_follow')

-- A straight horizontal polyline object, as STI resolves it (absolute
-- points, no re-added origin -- same contract mover_platform_test.lua notes).
local function straightPath(x1, y1, x2, y2)
	return Path({ polyline = { { x = x1, y = y1 }, { x = x2, y = y2 } } })
end

local function makeCollider(centreX, centreY, width, height, bodyType)
	return Collider{
		shape_type = 'rectangle',
		shape_arguments = {width, height},
		body_type = bodyType or 'static',
		position = {x = centreX, y = centreY},
	}
end

-- player collider riding the path: kinematic (as JumpTravelState sets it),
-- 16x16, starting wherever the path starts.
local function makePlayerCollider(x, y)
	local collider = makeCollider(x, y, 16, 16, 'kinematic')
	collider:setGroupIndex(1)
	return collider
end

local function runToCompletion(pathFollow, dt, maxSteps)
	pathFollow.timeline:play()
	for i = 1, maxSteps do
		pathFollow:update(dt)
		if pathFollow.timeline.playing == false then
			return i
		end
	end
	return maxSteps
end

test('clear path: reaches the end unblocked, exactly as before', function()
	world = World:new(0, 0, true)
	local path = straightPath(0, 0, 200, 0)
	local player = makePlayerCollider(0, 0)

	local pathFollow = PathFollow{
		collider = player,
		path = path,
		speed = 200,
	}

	runToCompletion(pathFollow, 1/60, 600)

	assertFalse(pathFollow:wasBlocked())
	local endPos = player:getPositionV()
	assertNear(200, endPos.x, 1)
end)

test('stops before entering a static solid collider partway along the path', function()
	world = World:new(0, 0, true)
	local path = straightPath(0, 0, 200, 0)
	local player = makePlayerCollider(0, 0)
	local wall = makeCollider(150, 0, 32, 32, 'static')

	local pathFollow = PathFollow{
		collider = player,
		path = path,
		speed = 200,
	}

	runToCompletion(pathFollow, 1/60, 600)

	assertTrue(pathFollow:wasBlocked())

	local bounds = player:getBounds()
	local wallBounds = wall:getBounds()
	local overlapsWall = bounds.left < wallBounds.right and bounds.right > wallBounds.left
		and bounds.top < wallBounds.bottom and bounds.bottom > wallBounds.top
	assertFalse(overlapsWall)

	-- keeps reporting blocked, and keeps the player out of the wall, on
	-- every subsequent update once it has stopped
	pathFollow:update(1/60)
	assertTrue(pathFollow:wasBlocked())
	local boundsAfter = player:getBounds()
	local overlapsAfter = boundsAfter.left < wallBounds.right and boundsAfter.right > wallBounds.left
		and boundsAfter.top < wallBounds.bottom and boundsAfter.bottom > wallBounds.top
	assertFalse(overlapsAfter)
end)

test('stops before entering a pushable-equivalent dynamic collider', function()
	world = World:new(0, 0, true)
	local path = straightPath(0, 0, 200, 0)
	local player = makePlayerCollider(0, 0)
	local pushable = makeCollider(150, 0, 32, 32, 'dynamic')
	pushable:setGroupIndex(2) -- distinct from the player's groupIndex

	local pathFollow = PathFollow{
		collider = player,
		path = path,
		speed = 200,
	}

	runToCompletion(pathFollow, 1/60, 600)

	assertTrue(pathFollow:wasBlocked())

	local bounds = player:getBounds()
	local pushableBounds = pushable:getBounds()
	local overlaps = bounds.left < pushableBounds.right and bounds.right > pushableBounds.left
		and bounds.top < pushableBounds.bottom and bounds.bottom > pushableBounds.top
	assertFalse(overlaps)
end)

test('does not trigger a hit on sample 0, even when it already overlaps a solid', function()
	world = World:new(0, 0, true)
	local path = straightPath(0, 0, 200, 0)
	local player = makePlayerCollider(0, 0)
	-- overlaps the player's own starting position -- simulates standing on
	-- the launch tile
	local launchTile = makeCollider(0, 0, 32, 32, 'static')

	local pathFollow = PathFollow{
		collider = player,
		path = path,
		speed = 200,
	}

	pathFollow.timeline:play()
	pathFollow:update(1/60)

	assertFalse(pathFollow:wasBlocked())
end)

test('ignoreCollider is never treated as a hit, anywhere along the path', function()
	world = World:new(0, 0, true)
	local path = straightPath(0, 0, 200, 0)
	local player = makePlayerCollider(0, 0)
	-- would otherwise block the whole path -- simulates the jump pad's own
	-- collider sitting right on the route
	local jumpPadCollider = makeCollider(100, 0, 32, 32, 'static')

	local pathFollow = PathFollow{
		collider = player,
		path = path,
		speed = 200,
		ignoreCollider = jumpPadCollider,
	}

	runToCompletion(pathFollow, 1/60, 600)

	assertFalse(pathFollow:wasBlocked())
	local endPos = player:getPositionV()
	assertNear(200, endPos.x, 1)
end)
