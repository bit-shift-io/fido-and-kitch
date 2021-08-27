-- special entity which is just a variable
-- use this for keep count etc..
local Variable = Class{__includes = Entity}

function Variable:init(object)
	Entity.init(self)
	self.name = object.name
    self.object = object
	self.type = 'variable'
    self.value = object.properties.initial
end

function Variable:reset()
    self.value = self.object.properties.initial
end

function Variable:add(v)
    self:set(self.value + v)
end

function Variable:subtract(v)
    self:set(self.value - v)
end

function Variable:set(v)
    self.value = v
    local eventName = 'on_' + self.value
    self.object:exec(eventName, self)
end

return Variable