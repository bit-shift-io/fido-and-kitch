local EnemyBrain = require('src.enemy.enemy_brain')

test('picks the nearer of two alive players', function()
	local near = {x=110, y=0, isDead=function() return false end}
	local far = {x=500, y=0, isDead=function() return false end}

	local target = EnemyBrain.pickTarget({x=100, y=0}, {far, near})

	assertEqual(near, target)
end)

test('excludes wrapped players from targeting', function()
	local wrapped = {x=105, y=0, isDead=function() return false end, wrapped=true}
	local alive = {x=500, y=0, isDead=function() return false end}

	local target = EnemyBrain.pickTarget({x=100, y=0}, {wrapped, alive})

	assertEqual(alive, target)
end)

test('excludes dead players from targeting', function()
	local dead = {x=105, y=0, isDead=function() return true end}
	local alive = {x=500, y=0, isDead=function() return false end}

	local target = EnemyBrain.pickTarget({x=100, y=0}, {dead, alive})

	assertEqual(alive, target)
end)

test('returns nil when no players are alive', function()
	local dead = {x=105, y=0, isDead=function() return true end}

	local target = EnemyBrain.pickTarget({x=100, y=0}, {dead})

	assertEqual(nil, target)
end)

test('walks right when target is to the right beyond the alignment threshold', function()
	local decision = EnemyBrain.decideHorizontalMovement(100, 200, 70, 4)

	assertEqual(70, decision.velocityX)
	assertEqual('walk', decision.animation)
end)

test('walks left when target is to the left beyond the alignment threshold', function()
	local decision = EnemyBrain.decideHorizontalMovement(200, 100, 70, 4)

	assertEqual(-70, decision.velocityX)
	assertEqual('walk', decision.animation)
end)

test('idles when within the alignment threshold of the target', function()
	local decision = EnemyBrain.decideHorizontalMovement(100, 102, 70, 4)

	assertEqual(0, decision.velocityX)
	assertEqual('idle', decision.animation)
end)

test('climbs up when target is above and a ladder overlaps', function()
	local direction = EnemyBrain.shouldClimb(200, 100, 4, true, false)

	assertEqual('up', direction)
end)

test('climbs down when target is below and a ladder is below', function()
	local direction = EnemyBrain.shouldClimb(100, 200, 4, false, true)

	assertEqual('down', direction)
end)

test('does not climb toward a target above with no overlapping ladder', function()
	local direction = EnemyBrain.shouldClimb(200, 100, 4, false, false)

	assertEqual(nil, direction)
end)

test('does not climb toward a target below with no ladder below', function()
	local direction = EnemyBrain.shouldClimb(100, 200, 4, false, false)

	assertEqual(nil, direction)
end)

test('does not climb when already aligned with the target Y', function()
	local direction = EnemyBrain.shouldClimb(100, 102, 4, true, true)

	assertEqual(nil, direction)
end)

test('shoves a player to the right when they are to the right of the robot', function()
	local offsetX = EnemyBrain.decideShove(100, 150, 40, false)

	assertEqual(40, offsetX)
end)

test('shoves a player to the left when they are to the left of the robot', function()
	local offsetX = EnemyBrain.decideShove(150, 100, 40, false)

	assertEqual(-40, offsetX)
end)

test('applies no shove to a wrapped player', function()
	local offsetX = EnemyBrain.decideShove(100, 150, 40, true)

	assertEqual(0, offsetX)
end)

test('a freshly banned player is banned', function()
	local bans = {}
	local player = {}

	EnemyBrain.ban(bans, player, 30)

	assertTrue(EnemyBrain.isBanned(bans, player))
end)

test('an unbanned player is not banned', function()
	local bans = {}
	local player = {}

	assertFalse(EnemyBrain.isBanned(bans, player))
end)

test('a ban expires once its timer ticks past the duration', function()
	local bans = {}
	local player = {}
	EnemyBrain.ban(bans, player, 30)

	EnemyBrain.tickBans(bans, 29)
	assertTrue(EnemyBrain.isBanned(bans, player))

	EnemyBrain.tickBans(bans, 2)
	assertFalse(EnemyBrain.isBanned(bans, player))
end)

test('pickTarget skips a banned player in favour of an unbanned one', function()
	local near = {x=110, y=0, isDead=function() return false end}
	local far = {x=500, y=0, isDead=function() return false end}
	local bans = {}
	EnemyBrain.ban(bans, near, 30)

	local target = EnemyBrain.pickTarget({x=100, y=0}, {far, near}, bans)

	assertEqual(far, target)
end)

test('pickTarget again considers a player once their ban expires', function()
	local near = {x=110, y=0, isDead=function() return false end}
	local far = {x=500, y=0, isDead=function() return false end}
	local bans = {}
	EnemyBrain.ban(bans, near, 30)
	EnemyBrain.tickBans(bans, 31)

	local target = EnemyBrain.pickTarget({x=100, y=0}, {far, near}, bans)

	assertEqual(near, target)
end)

test('chase timer accumulates while chasing the same target', function()
	local timer = {target = nil, elapsed = 0}
	local target = {}

	local nextTimer, shouldBan = EnemyBrain.updateChaseTimer(timer, target, 4, 10)

	assertEqual(target, nextTimer.target)
	assertEqual(4, nextTimer.elapsed)
	assertFalse(shouldBan)
end)

test('chase timer resets when the target switches', function()
	local targetA = {}
	local targetB = {}
	local timer = {target = targetA, elapsed = 8}

	local nextTimer, shouldBan = EnemyBrain.updateChaseTimer(timer, targetB, 1, 10)

	assertEqual(targetB, nextTimer.target)
	assertEqual(1, nextTimer.elapsed)
	assertFalse(shouldBan)
end)

test('chase timer triggers a ban once it reaches the threshold', function()
	local target = {}
	local timer = {target = target, elapsed = 9}

	local nextTimer, shouldBan = EnemyBrain.updateChaseTimer(timer, target, 2, 10)

	assertTrue(shouldBan)
	assertEqual(nil, nextTimer.target)
	assertEqual(0, nextTimer.elapsed)
end)

test('chase timer resets when there is no target', function()
	local timer = {target = {}, elapsed = 6}

	local nextTimer, shouldBan = EnemyBrain.updateChaseTimer(timer, nil, 1, 10)

	assertEqual(nil, nextTimer.target)
	assertEqual(0, nextTimer.elapsed)
	assertFalse(shouldBan)
end)

test('wander paces forward until it reaches the range limit', function()
	local decision = EnemyBrain.decideWander({direction = 1}, 140, 100, 30, 50, 1)

	assertEqual(1, decision.direction)
	assertEqual(30, decision.velocityX)
end)

test('wander reverses direction once it reaches the range limit', function()
	local decision = EnemyBrain.decideWander({direction = 1}, 151, 100, 30, 50, 1)

	assertEqual(-1, decision.direction)
	assertEqual(-30, decision.velocityX)
end)

test('wander reverses direction at the opposite range limit', function()
	local decision = EnemyBrain.decideWander({direction = -1}, 49, 100, 30, 50, 1)

	assertEqual(1, decision.direction)
	assertEqual(30, decision.velocityX)
end)

test('falling onto the enemy from above is a stomp', function()
	local isStomp = EnemyBrain.isStomp(150, 100, 100, 40, 0.5)

	assertTrue(isStomp)
end)

test('falling but landing in the enemy lower half is not a stomp', function()
	local isStomp = EnemyBrain.isStomp(150, 135, 100, 40, 0.5)

	assertFalse(isStomp)
end)

test('rising through the enemy is never a stomp', function()
	local isStomp = EnemyBrain.isStomp(-150, 100, 100, 40, 0.5)

	assertFalse(isStomp)
end)

test('standing still (no vertical velocity) is not a stomp', function()
	local isStomp = EnemyBrain.isStomp(0, 100, 100, 40, 0.5)

	assertFalse(isStomp)
end)
