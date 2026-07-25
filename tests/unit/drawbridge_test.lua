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

test('closed state has no walkable deck (the gap is fully exposed, no barrier)', function()
	assertFalse(DrawbridgeSupport.isDeckSolid('closed'))
end)

test('opening, open, and closing states have a solid deck', function()
	for _, state in ipairs({'opening', 'open', 'closing'}) do
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

test('occupancy is any collider whose entity is not the bridge itself', function()
	local bridge = {}
	local occupantCollider = {entity = {type = 'player'}}
	local ownCollider = {entity = bridge}
	local groundCollider = {entity = nil}

	assertTrue(DrawbridgeSupport.hasOccupant({occupantCollider}, bridge))
	assertFalse(DrawbridgeSupport.hasOccupant({ownCollider, groundCollider}, bridge))
	assertFalse(DrawbridgeSupport.hasOccupant({}, bridge))
end)

test('an open bridge that has been occupied begins closing once empty', function()
	assertEqual('closing', DrawbridgeSupport.nextStateOnOccupancyChange('open', false, true))
end)

test('a freshly-open bridge nobody has reached yet does not close just because it is currently empty', function()
	assertEqual('open', DrawbridgeSupport.nextStateOnOccupancyChange('open', false, false))
end)

test('an open bridge stays open while occupied', function()
	assertEqual('open', DrawbridgeSupport.nextStateOnOccupancyChange('open', true, true))
end)

test('a new occupant mid-close reverses back to opening', function()
	assertEqual('opening', DrawbridgeSupport.nextStateOnOccupancyChange('closing', true, false))
end)

test('occupancy has no effect on closed, opening, or an already-closing empty bridge', function()
	assertEqual('closed', DrawbridgeSupport.nextStateOnOccupancyChange('closed', false, false))
	assertEqual('closed', DrawbridgeSupport.nextStateOnOccupancyChange('closed', true, false))
	assertEqual('opening', DrawbridgeSupport.nextStateOnOccupancyChange('opening', false, false))
	assertEqual('opening', DrawbridgeSupport.nextStateOnOccupancyChange('opening', true, false))
	assertEqual('closing', DrawbridgeSupport.nextStateOnOccupancyChange('closing', false, false))
end)
