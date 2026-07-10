-- Reusable blink helper: toggles a boolean property on a target table N times
-- over the given interval, then invokes onComplete. Used by both the death
-- lock-and-flash and the non-blocking spawn/respawn flash.
local Flash = Class{}

function Flash:init(props)
	self.type = 'flash'
	self.target = props.target
	self.property = props.property or 'visible'
	self.interval = props.interval or 0.12
	self.blinks = props.blinks or 6
	self.onComplete = props.onComplete

	self.elapsed = 0
	self.toggles = 0
	self.active = true
	self.target[self.property] = true
end

function Flash:update(dt)
	if not self.active then
		return
	end

	self.elapsed = self.elapsed + dt
	if self.elapsed < self.interval then
		return
	end

	self.elapsed = self.elapsed - self.interval
	self.target[self.property] = not self.target[self.property]
	self.toggles = self.toggles + 1

	if self.toggles >= self.blinks then
		self.active = false
		self.target[self.property] = true
		if self.onComplete then
			self.onComplete()
		end
	end
end

return Flash
