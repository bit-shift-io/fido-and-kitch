-- Unit tests for the drawbridge's pure decision helpers (src.entities.drawbridge_support).
-- The entity itself composes Sprite/Collider and needs love.graphics, so it's
-- verified manually (love . drawphysics map=drawbridge_fixture.lua) rather than here.
Class = Class or require('lib.hump.class')
local DrawbridgeSupport = require('src.entities.drawbridge_support')

test('facing right places the trigger sensor one tile to the right', function()
	assertEqual(32, DrawbridgeSupport.triggerOffsetX('right', 32))
end)

test('facing left places the trigger sensor one tile to the left', function()
	assertEqual(-32, DrawbridgeSupport.triggerOffsetX('left', 32))
end)

test('closed state has a solid barrier and no walkable deck', function()
	assertTrue(DrawbridgeSupport.isBarrierPresent('closed'))
	assertFalse(DrawbridgeSupport.isDeckSolid('closed'))
end)

test('opening, open, and closing states have a solid deck and no barrier', function()
	for _, state in ipairs({'opening', 'open', 'closing'}) do
		assertFalse(DrawbridgeSupport.isBarrierPresent(state), state .. ' should have no barrier')
		assertTrue(DrawbridgeSupport.isDeckSolid(state), state .. ' should have a solid deck')
	end
end)

test('a player may always open the bridge', function()
	assertTrue(DrawbridgeSupport.mayOpen('player', false))
	assertTrue(DrawbridgeSupport.mayOpen('player', true))
end)

test('an enemy may only open the bridge when opted in', function()
	assertFalse(DrawbridgeSupport.mayOpen('enemy', false))
	assertTrue(DrawbridgeSupport.mayOpen('enemy', true))
end)

test('an unrelated entity type may never open the bridge', function()
	assertFalse(DrawbridgeSupport.mayOpen('push_box', false))
	assertFalse(DrawbridgeSupport.mayOpen('push_box', true))
end)

test('an eligible entity overlapping the trigger while closed starts opening', function()
	assertEqual('opening', DrawbridgeSupport.nextStateOnTrigger('closed', 'player', false))
end)

test('an ineligible entity overlapping the trigger while closed does nothing', function()
	assertEqual('closed', DrawbridgeSupport.nextStateOnTrigger('closed', 'enemy', false))
end)

test('the trigger has no effect once already opening or open', function()
	assertEqual('opening', DrawbridgeSupport.nextStateOnTrigger('opening', 'player', false))
	assertEqual('open', DrawbridgeSupport.nextStateOnTrigger('open', 'player', false))
end)

test('an eligible entity overlapping the trigger mid-close reverses back to opening', function()
	assertEqual('opening', DrawbridgeSupport.nextStateOnTrigger('closing', 'player', false))
end)

test('the open animation finishing transitions opening to open', function()
	assertEqual('open', DrawbridgeSupport.nextStateOnAnimationFinish('opening'))
end)

test('the close animation finishing transitions closing to closed', function()
	assertEqual('closed', DrawbridgeSupport.nextStateOnAnimationFinish('closing'))
end)

test('animation finish has no effect on closed or open (nothing mid-flight)', function()
	assertEqual('closed', DrawbridgeSupport.nextStateOnAnimationFinish('closed'))
	assertEqual('open', DrawbridgeSupport.nextStateOnAnimationFinish('open'))
end)
