-- component which is just a variable
-- use this for keep count etc..
-- and can fire events when reaching certain values
local Variable = Class{}

function Variable:init(props)
	self.type = 'variable'
    self.initial = props.initial or 0
    self.value = self.initial
    self.eventSignal = Signal{}
    self.eventSignal:connect(props.event)
end

function Variable:reset()
    self.value = self.initial
end

function Variable:add(v)
    self:set(self.value + v)
end

function Variable:subtract(v)
    self:set(self.value - v)
end

function Variable:set(v)
    self.value = v
    local eventName = 'on_' .. self.value
    self.eventSignal:emit(eventName, self)
end

return Variable