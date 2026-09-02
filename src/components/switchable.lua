-- Switchable component
-- an entity a linked switch (lever, pressure switch) can turn on/off
local Switchable = Class({})

function Switchable:init(props)
	self.type = "switchable"
	self.entity = props.entity
	self.onStateChange = props.onStateChange
	self.enabled = (props.enabled == nil) and true or props.enabled
end

function Switchable:switch(switch, user)
	self.enabled = (switch.state == "on")
	if self.onStateChange then
		self.onStateChange(self.enabled, switch, user)
	end
end

return Switchable
