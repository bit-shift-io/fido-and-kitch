-- A timer-driven switch: it cycles on/off automatically based on onDuration
-- and offDuration properties (in seconds), starting in the off phase, and drives
-- an optional target entity through the same `target` + `:switch()` mechanism
-- the lever switch and pressure switch use.
--
-- Timing is accumulator-based: elapsed dt is summed each frame, and the phase
-- flips when the accumulator exceeds the current phase's duration. This survives
-- variable frame dt (no frame-counting), the same approach src/entities/drawbridge
-- and src/entities/pressure_switch use.
--
-- Single file, following src/entities/pressure_switch.lua: pure decision helpers
-- are kept as private locals with a _internal white-box seam for tests/unit/.
-- See tests/unit/timer_switch_test.lua for the entity-level tests.

local TimerSwitch = Class({ __includes = Entity })

-- The next phase (and remaining time) given current elapsed time in the
-- accumulator and the durations for each phase.
-- Returns (nextPhase, remainingTime):
--   * nextPhase: 'on' or 'off'
--   * remainingTime: time past the flip point, to carry into the next phase
--
-- Logic:
--   1. If accumulator hasn't exceeded the current phase duration, no change.
--   2. If it has, flip phase and subtract the duration from accumulator.
local function nextPhase(currentPhase, elapsed, onDuration, offDuration)
	local currentDuration = (currentPhase == "on") and onDuration or offDuration
	if elapsed < currentDuration then
		return currentPhase, elapsed
	end

	-- Phase has elapsed. Flip and carry remainder to next phase.
	local nextPhaseStr = (currentPhase == "on") and "off" or "on"
	local remainder = elapsed - currentDuration
	return nextPhaseStr, remainder
end

function TimerSwitch:init(object, map)
	Entity.init(self, object, "timer_switch")
	self.state = "off"
	self.accumulator = 0

	-- Duration for each phase, in seconds. Defaults: 1 second each if not set.
	self.onDuration = (object.properties and object.properties.onDuration) or 1
	self.offDuration = (object.properties and object.properties.offDuration) or 1

	-- resolved the same way src/entities/switch.lua resolves its own target
	if object.properties and object.properties.target then
		self.target = map:getObjectById(object.properties.target.id)
	end

	-- no assets yet at res/snd/entity_timer_switch_{on,off}.wav;
	-- Sound:play warns and skips until they're added
	self.sound = self:addComponent(Sound({
		sounds = {
			on = "res/snd/entity_timer_switch_on.wav",
			off = "res/snd/entity_timer_switch_off.wav",
		},
	}))
end

function TimerSwitch:isActive()
	return self.state == "on"
end

function TimerSwitch:update(dt)
	Entity.update(self, dt)

	self.accumulator = self.accumulator + dt

	local wasActive = self:isActive()
	local nextPhaseStr, remainingTime = nextPhase(self.state, self.accumulator, self.onDuration, self.offDuration)

	if nextPhaseStr == self.state then
		-- No phase change this frame; update accumulator and return
		self.accumulator = remainingTime
		return
	end

	-- Phase changed. Update state, carry remainder, drive target.
	self.state = nextPhaseStr
	self.accumulator = remainingTime
	self.sound:play(self.state)
	self:driveTarget()
end

-- mirrors src/entities/switch.lua: the target reads this switch's `state`
function TimerSwitch:driveTarget()
	if self.target == nil or self.target.entity == nil then
		return
	end

	if self.target.entity then
		local switchable = self.target.entity.getComponent and self.target.entity:getComponent(Switchable)
		if switchable then
			switchable:switch(self, nil)
		elseif self.target.entity.switch then
			self.target.entity:switch(self, nil)
		end
	end
end

-- White-box seam for tests/unit/timer_switch_test.lua only, mirroring
-- PressureSwitch._internal and Drawbridge._internal (see NOTES.md).
-- Not for use by production code -- reach for the real entity there.
TimerSwitch._internal = {
	nextPhase = nextPhase,
}

return TimerSwitch
