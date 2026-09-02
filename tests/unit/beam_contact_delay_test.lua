-- Unit tests for BeamContactDelay component.
--
-- Pure component-level tests with a stub entity. No World/Map/Entity stack needed.

local HeadlessBootstrap = require("tests.support.headless_bootstrap")
local BeamContactDelay = require("src.components.beam_contact_delay")

-- Helper: create a stub entity with queueDestroy tracking
local function makeStubEntity()
	return {
		destroyed = false,
		queueDestroy = function(self)
			self.destroyed = true
		end,
	}
end

test("init sets up delay, elapsed, and contacted state", function()
	local component = BeamContactDelay({ delay = 0.5 })
	assertEqual(0.5, component.delay)
	assertEqual(0, component.elapsed)
	assertFalse(component.contacted)
end)

test("update without markContact never accumulates elapsed and never destroys", function()
	local component = BeamContactDelay({ delay = 0.5 })
	local entity = makeStubEntity()
	component.entity = entity

	local dt = 1 / 60
	-- Run many frames worth of time, well over the delay, without calling markContact
	for _ = 1, 100 do
		component:update(dt)
	end

	assertEqual(0, component.elapsed, "expected elapsed to remain zero without markContact")
	assertFalse(entity.destroyed, "expected entity to never be destroyed without markContact")
end)

test("markContact once per frame across enough frames reaches the delay and destroys", function()
	local delay = 0.5
	local component = BeamContactDelay({ delay = delay })
	local entity = makeStubEntity()
	component.entity = entity

	local dt = 1 / 60
	local framesNeeded = math.ceil(delay / dt) + 1 -- +1 to ensure we pass the threshold

	for _ = 1, framesNeeded do
		component:markContact()
		component:update(dt)
	end

	assertTrue(entity.destroyed, "expected entity to be destroyed after accumulating enough contact")
end)

test("comfortably short of the delay threshold does not destroy", function()
	local delay = 0.5
	local component = BeamContactDelay({ delay = delay })
	local entity = makeStubEntity()
	component.entity = entity

	local dt = 1 / 60
	local framesShort = math.floor(delay / dt) - 5 -- several frames short of the threshold

	for _ = 1, framesShort do
		component:markContact()
		component:update(dt)
	end

	assertFalse(entity.destroyed, "expected entity to not be destroyed well short of the delay")
end)

test("a single unmarked frame resets elapsed, requiring fresh accumulation", function()
	local delay = 0.5
	local component = BeamContactDelay({ delay = delay })
	local entity = makeStubEntity()
	component.entity = entity

	local dt = 1 / 60
	local halfwayFrames = math.floor(delay / dt / 2)

	-- Accumulate for about half the delay
	for _ = 1, halfwayFrames do
		component:markContact()
		component:update(dt)
	end

	local elapsedHalfway = component.elapsed
	assertTrue(elapsedHalfway > 0, "expected elapsed to accumulate during contact")

	-- Skip one frame (no markContact call)
	component:update(dt)

	assertEqual(0, component.elapsed, "expected elapsed to reset after a missed markContact frame")
	assertFalse(entity.destroyed, "expected entity to still be intact after the reset")

	-- Accumulate again for the same number of frames: still short of delay
	for _ = 1, halfwayFrames do
		component:markContact()
		component:update(dt)
	end

	assertFalse(entity.destroyed, "expected entity to not be destroyed after two half-accumulations with a gap")
end)

test("markContact sets contacted to true, and update resets it to false", function()
	local component = BeamContactDelay({ delay = 0.5 })
	local entity = makeStubEntity()
	component.entity = entity

	assertTrue(not component.contacted, "expected contacted to start as false")
	component:markContact()
	assertTrue(component.contacted, "expected markContact to set contacted to true")

	component:update(1 / 60)
	assertFalse(component.contacted, "expected contacted to be reset to false after update")
end)

test("exactly reaching the delay threshold triggers destruction", function()
	local delay = 0.5
	local component = BeamContactDelay({ delay = delay })
	local entity = makeStubEntity()
	component.entity = entity

	local dt = 1 / 60
	-- Calculate frames needed to reach exactly (or just barely over) the delay
	-- We'll use a precise delta to get very close
	local elapsed = 0
	local frame = 0
	while elapsed < delay do
		component:markContact()
		component:update(dt)
		elapsed = elapsed + dt
		frame = frame + 1
		if frame > 1000 then
			error("test took too long, expected to hit delay within 1000 frames")
		end
	end

	assertTrue(entity.destroyed, "expected entity to be destroyed once elapsed >= delay")
end)
