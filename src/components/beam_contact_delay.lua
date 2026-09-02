-- BeamContactDelay component: tracks contact duration with a beam and queues
-- entity destruction once the contact delay is reached.
--
-- Usage:
--   self.beamDelay = self:addComponent(BeamContactDelay{delay = 0.5})
--   -- Then each frame a beam contacts:
--   self.beamDelay:markContact()
--   -- After 0.5s of continuous markContact() calls per frame, entity queues destruction.
--
-- The component requires a fresh markContact() call each frame to accumulate time;
-- skipping a single frame resets the elapsed counter to zero.
local BeamContactDelay = Class({})

function BeamContactDelay:init(props)
	self.type = "beam_contact_delay"
	self.delay = props.delay or 0.5
	self.elapsed = 0
	self.contacted = false
end

-- Mark this frame as having contact. Must be called every frame to accumulate
-- time toward the delay threshold. Skipping a frame resets elapsed to zero.
function BeamContactDelay:markContact()
	self.contacted = true
end

function BeamContactDelay:update(dt)
	if self.contacted then
		self.elapsed = self.elapsed + dt
		if self.elapsed >= self.delay then
			self.entity:queueDestroy()
		end
	else
		self.elapsed = 0
	end

	self.contacted = false
end

return BeamContactDelay
