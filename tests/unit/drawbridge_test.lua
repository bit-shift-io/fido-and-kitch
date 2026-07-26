-- Unit tests for the drawbridge's pure decision helpers (src.entities.drawbridge_support).
-- The entity itself composes Sprite/Collider and needs love.graphics, so it's
-- verified manually (love . drawphysics map=drawbridge_fixture.lua) rather than here.
Class = Class or require('lib.hump.class')
local DrawbridgeSupport = require('src.entities.drawbridge.drawbridge_support')

-- The trigger is a thin strip flush against the gap's edge (not a full
-- tile out) -- so the deck visibly starts lowering only once the player is
-- right at the edge, reading as "pushing the gate down" rather than
-- tripping a remote sensor a whole tile away.
test('leftToRight places the trigger sensor flush against the gap, on the left (arrival side)', function()
	-- tileWidth=32, triggerWidth=8: trigger's right edge (offset + half its
	-- own width) must land exactly on the deck's left edge (half the tile)
	assertEqual(-20, DrawbridgeSupport.triggerOffsetX('leftToRight', 32, 8))
end)

test('rightToLeft places the trigger sensor flush against the gap, on the right (arrival side)', function()
	assertEqual(20, DrawbridgeSupport.triggerOffsetX('rightToLeft', 32, 8))
end)

test('an unrecognised or missing crossingDirection falls back to leftToRight', function()
	assertEqual(-20, DrawbridgeSupport.triggerOffsetX('sideways', 32, 8))
	assertEqual(-20, DrawbridgeSupport.triggerOffsetX(nil, 32, 8))
end)

test('leftToRight renders unmirrored -- tower on the left, deck lowering rightward over the gap', function()
	assertEqual('right', DrawbridgeSupport.spriteFacing('leftToRight'))
end)

test('rightToLeft renders mirrored', function()
	assertEqual('left', DrawbridgeSupport.spriteFacing('rightToLeft'))
end)

test('an unrecognised or missing crossingDirection renders unmirrored (matches the leftToRight fallback)', function()
	assertEqual('right', DrawbridgeSupport.spriteFacing('sideways'))
	assertEqual('right', DrawbridgeSupport.spriteFacing(nil))
end)

test('the sprite box is 3x the object dimensions, centred on the object tile', function()
	local width, height = DrawbridgeSupport.spriteBoxDimensions(32, 32)
	assertEqual(96, width)
	assertEqual(96, height)
end)

test('the sprite box derives from the object dimensions, not a hard-coded size', function()
	local width, height = DrawbridgeSupport.spriteBoxDimensions(48, 64)
	assertEqual(144, width)
	assertEqual(192, height)
end)

test('closed state has no walkable deck (the gap is fully exposed, no barrier)', function()
	assertFalse(DrawbridgeSupport.isDeckSolid('closed'))
end)

test('opening, open, and closing states have a solid deck', function()
	for _, state in ipairs({'opening', 'open', 'closing'}) do
		assertTrue(DrawbridgeSupport.isDeckSolid(state), state .. ' should have a solid deck')
	end
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

test('held is any collider (in the combined trigger+deck overlap set) whose entity is not the bridge itself', function()
	local bridge = {}
	local occupantCollider = {entity = {type = 'player'}}
	local ownCollider = {entity = bridge}
	local groundCollider = {entity = nil}

	assertTrue(DrawbridgeSupport.isHeld({occupantCollider}, bridge))
	assertFalse(DrawbridgeSupport.isHeld({ownCollider, groundCollider}, bridge))
	assertFalse(DrawbridgeSupport.isHeld({}, bridge))
end)

test('anything holds the bridge, not just players -- eligibility no longer exists', function()
	local bridge = {}
	local enemyCollider = {entity = {type = 'enemy'}}
	local pushBoxCollider = {entity = {type = 'push_box'}}

	assertTrue(DrawbridgeSupport.isHeld({enemyCollider}, bridge))
	assertTrue(DrawbridgeSupport.isHeld({pushBoxCollider}, bridge))
end)

-- Only the trigger tile can break a closed bridge -- not the deck alone.
-- This is what keeps a wrong-side approach a real hazard: a wide collider
-- grazing the far edge of the deck tile (while still standing on solid
-- ground on the wrong side) must not pre-emptively solidify the gap for it.
-- Direction only gates this one edge; every other transition is driven by
-- either zone once the bridge is already moving (see below).
test('only the trigger can break a closed bridge -- deck overlap alone does nothing', function()
	assertEqual('closed', DrawbridgeSupport.nextStateOnHeldChange('closed', false, true))
	assertEqual('opening', DrawbridgeSupport.nextStateOnHeldChange('closed', true, false))
	assertEqual('opening', DrawbridgeSupport.nextStateOnHeldChange('closed', true, true))
end)

-- once already closing (deck still solid throughout), either zone re-holds
-- it -- an occupant who never left the deck, or a fresh trigger touch, both
-- reverse it back to opening
test('either zone reopens a closing bridge', function()
	assertEqual('opening', DrawbridgeSupport.nextStateOnHeldChange('closing', true, false))
	assertEqual('opening', DrawbridgeSupport.nextStateOnHeldChange('closing', false, true))
	assertEqual('closing', DrawbridgeSupport.nextStateOnHeldChange('closing', false, false))
end)

test('unheld in both zones pushes an open or opening bridge toward closing', function()
	assertEqual('closing', DrawbridgeSupport.nextStateOnHeldChange('open', false, false))
	assertEqual('closing', DrawbridgeSupport.nextStateOnHeldChange('opening', false, false))
end)

test('held in either zone has no effect on an already-opening or already-open bridge', function()
	assertEqual('opening', DrawbridgeSupport.nextStateOnHeldChange('opening', true, false))
	assertEqual('open', DrawbridgeSupport.nextStateOnHeldChange('open', false, true))
end)

-- the previously-unreachable path: open -> closing -> opening (reopened
-- mid-close) -> open -> closing (closes again once cleared). No flag, no
-- memory of past occupancy -- held is recomputed fresh every frame.
test('a bridge that reopens mid-close still closes again once cleared (the stuck-down regression)', function()
	local state = 'open'

	state = DrawbridgeSupport.nextStateOnHeldChange(state, false, false) -- last occupant leaves
	assertEqual('closing', state)

	state = DrawbridgeSupport.nextStateOnHeldChange(state, false, true) -- re-occupies the deck mid-close
	assertEqual('opening', state)

	state = DrawbridgeSupport.nextStateOnAnimationFinish(state)
	assertEqual('open', state)

	state = DrawbridgeSupport.nextStateOnHeldChange(state, false, false) -- cleared again
	assertEqual('closing', state, 'expected the reopened bridge to still be able to close again once cleared')

	state = DrawbridgeSupport.nextStateOnAnimationFinish(state)
	assertEqual('closed', state)
end)

-- the free-play repro (DECISIONS.md Q3): entering only the trigger tile
-- and retreating before ever reaching the deck must not get stuck --
-- unheld-in-both-zones still closes it once the animation finishes to open
test('turning back from the trigger alone, before ever touching the deck, still closes again', function()
	local state = 'closed'

	state = DrawbridgeSupport.nextStateOnHeldChange(state, true, false) -- enters the trigger tile
	assertEqual('opening', state)

	-- retreats fully -- neither zone held from here on
	state = DrawbridgeSupport.nextStateOnAnimationFinish(state)
	assertEqual('open', state)

	state = DrawbridgeSupport.nextStateOnHeldChange(state, false, false)
	assertEqual('closing', state, 'expected the bridge to raise again once genuinely unheld, never stuck open')
end)
