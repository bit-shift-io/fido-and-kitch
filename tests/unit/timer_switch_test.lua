-- Two tiers of coverage for src/entities/timer_switch.lua, both headless,
-- mirroring tests/unit/pressure_switch_test.lua's split:
--
-- 1. Pure decision-helper tests against TimerSwitch._internal -- fast,
--    construction-free, one assertion per branch.
--
-- 2. Entity-level tests that construct a real TimerSwitch -- real Sound,
--    a real bump World -- via tests/support/headless_bootstrap, and drive it
--    through TimerSwitch:update(dt) the way the game does.
--
-- The target-driving mechanism (a real Blocker reacting to :switch())
-- and the gameplay scenarios through a real Game/Map stack stay in
-- tests/integration/timer_switch_test.lua; this file covers the switch's
-- own decision logic and wiring, not the surrounding game.

local HeadlessBootstrap = require('tests.support.headless_bootstrap')
local SoundSpy = require('tests.support.sound_spy')

local TimerSwitch = require('src.entities.timer_switch')
local P = TimerSwitch._internal

--
-- Part 1: pure decision helpers
--

test('timer stays in off phase while accumulator is less than offDuration', function()
	local phase, remaining = P.nextPhase('off', 0.3, 1.0, 0.5)
	assertEqual('off', phase)
	assertNear(0.3, remaining)
end)

test('timer flips from off to on when accumulator exceeds offDuration', function()
	local phase, remaining = P.nextPhase('off', 0.7, 1.0, 0.5)
	assertEqual('on', phase)
	assertNear(0.2, remaining)
end)

test('timer stays in on phase while accumulator is less than onDuration', function()
	local phase, remaining = P.nextPhase('on', 0.4, 1.0, 0.5)
	assertEqual('on', phase)
	assertNear(0.4, remaining)
end)

test('timer flips from on to off when accumulator exceeds onDuration', function()
	local phase, remaining = P.nextPhase('on', 1.3, 1.0, 0.5)
	assertEqual('off', phase)
	assertNear(0.3, remaining)
end)

test('timer handles zero duration (instant flip)', function()
	local phase, remaining = P.nextPhase('off', 0.1, 1.0, 0)
	assertEqual('on', phase)
	assertNear(0.1, remaining)
end)

test('timer flips exactly when elapsed equals duration', function()
	local phase, remaining = P.nextPhase('off', 0.05, 0.1, 0.05)
	assertEqual('on', phase)
	assertNear(0, remaining, 0.001)
end)

--
-- Part 2: entity-level, against a real constructed TimerSwitch
--

local function makeSwitch(properties)
	HeadlessBootstrap.resetWorld()
	return TimerSwitch({
		x = 0, y = 0, width = 32, height = 32,
		properties = properties,
	})
end

test('constructs headless with real Sound/World stack, off initially', function()
	local switch = makeSwitch()

	assertEqual('off', switch.state)
	assertFalse(switch:isActive())
	assertEqual(0, switch.accumulator)
end)

test('uses default onDuration and offDuration of 1.0 when not specified', function()
	local switch = makeSwitch()

	assertEqual(1.0, switch.onDuration)
	assertEqual(1.0, switch.offDuration)
end)

test('uses provided onDuration and offDuration from properties', function()
	local switch = makeSwitch({onDuration = 2.5, offDuration = 0.5})

	assertEqual(2.5, switch.onDuration)
	assertEqual(0.5, switch.offDuration)
end)

test('timer accumulates dt each frame', function()
	local switch = makeSwitch({onDuration = 1.0, offDuration = 1.0})

	switch:update(0.1)
	assertNear(0.1, switch.accumulator)

	switch:update(0.2)
	assertNear(0.3, switch.accumulator)
end)

test('timer flips to on when offDuration elapsed and plays sound', function()
	local switch = makeSwitch({onDuration = 1.0, offDuration = 0.5})
	local spy = SoundSpy.install()

	switch:update(0.3)
	assertEqual('off', switch.state)
	assertEqual(0, #spy.played)

	switch:update(0.3)
	assertEqual('on', switch.state)
	assertEqual('on', spy.played[1])

	spy.uninstall()
end)

test('timer flips back to off when onDuration elapsed and plays sound', function()
	local switch = makeSwitch({onDuration = 0.4, offDuration = 0.2})
	local spy = SoundSpy.install()

	-- Get to 'on' state
	switch:update(0.3)
	assertEqual('on', switch.state)

	-- Now advance onDuration to flip back to 'off'
	switch:update(0.5)
	assertEqual('off', switch.state)
	assertEqual(2, #spy.played)
	assertEqual('on', spy.played[1])
	assertEqual('off', spy.played[2])

	spy.uninstall()
end)

test('timer cycles repeatedly through on/off phases', function()
	local switch = makeSwitch({onDuration = 0.3, offDuration = 0.2})

	-- Cycle 1: off -> on (0.2s)
	switch:update(0.25)
	assertEqual('on', switch.state)

	-- Cycle 2: on -> off (0.3s from the flip)
	switch:update(0.4)
	assertEqual('off', switch.state)

	-- Cycle 3: off -> on (0.2s from the flip)
	switch:update(0.25)
	assertEqual('on', switch.state)
end)

test('timer survives variable frame dt via accumulator', function()
	local switch = makeSwitch({onDuration = 1.0, offDuration = 0.5})

	-- Simulate variable frame times: 60fps, then 30fps frame
	switch:update(1/60)
	switch:update(1/60)
	switch:update(1/60)
	switch:update(1/30)

	-- Total: 3*(1/60) + 1/30 = 3/60 + 2/60 = 5/60 ≈ 0.083
	-- Should still be 'off' since 0.083 < 0.5
	assertEqual('off', switch.state)

	-- Jump past offDuration
	switch:update(0.5)
	assertEqual('on', switch.state)
end)

test('timer with no target cycles silently with no crash', function()
	local switch = makeSwitch({onDuration = 0.1, offDuration = 0.1})

	-- Should not crash when there's no target
	switch:update(0.15)
	assertEqual('on', switch.state)

	switch:update(0.15)
	assertEqual('off', switch.state)
end)

test('flipping drives the target through :switch(), the same mechanism the lever uses', function()
	local switch = makeSwitch({onDuration = 0.2, offDuration = 0.2})
	local switchedWith = {}

	-- bypasses map:getObjectById (no real Map here) -- driveTarget only
	-- reads self.target.entity, so a bare fake stands in fine
	switch.target = {entity = {switch = function(self_, triggeringSwitch) table.insert(switchedWith, triggeringSwitch) end}}

	-- First transition: off -> on
	switch:update(0.3)
	assertEqual(1, #switchedWith)
	assertEqual(switch, switchedWith[1])
	assertEqual('on', switch.state)

	-- Second transition: on -> off
	switch:update(0.3)
	assertEqual(2, #switchedWith)
	assertEqual(switch, switchedWith[2])
	assertEqual('off', switch.state)
end)

test('target receives Switchable:switch() if target entity has that component', function()
	local switch = makeSwitch({onDuration = 0.1, offDuration = 0.1})
	local switchedWith = {}

	-- Create a mock entity with a Switchable component
	local mockEntity = {}
	function mockEntity:getComponent(componentType)
		if componentType == Switchable then
			return {
				switch = function(self_, triggeringSwitch)
					table.insert(switchedWith, triggeringSwitch)
				end
			}
		end
		return nil
	end

	switch.target = {entity = mockEntity}

	switch:update(0.15)
	assertEqual(1, #switchedWith)
	assertEqual(switch, switchedWith[1])
end)

test('accumulator carries remainder correctly across phase boundaries', function()
	local switch = makeSwitch({onDuration = 0.6, offDuration = 0.4})

	-- In 'off' phase with duration 0.4
	-- Update with 0.5 (exceeds duration by 0.1)
	switch:update(0.5)
	assertEqual('on', switch.state)
	assertNear(0.1, switch.accumulator)

	-- In 'on' phase with duration 0.6
	-- Update with 0.3 (total 0.1 + 0.3 = 0.4, not yet at 0.6)
	switch:update(0.3)
	assertEqual('on', switch.state)
	assertNear(0.4, switch.accumulator)

	-- Update with 0.3 (total 0.4 + 0.3 = 0.7, exceeds 0.6 by 0.1)
	switch:update(0.3)
	assertEqual('off', switch.state)
	assertNear(0.1, switch.accumulator)
end)
