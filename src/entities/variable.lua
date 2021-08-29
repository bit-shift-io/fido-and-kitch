-- special entity which is just a variable
-- use this for keep count etc..
-- for use in editor as a counter
local VariableEntity = Class{__includes = Entity}

function VariableEntity:init(object)
	Entity.init(self)
	self.name = object.name
    self.object = object
	self.type = 'variable'
    self.variable = self:addComponent(Variable{
        initial=object.properties.initial,
		entity=self,
		event=utils.func(self.event, self)
	})
end

function VariableEntity:reset()
    self.variable:reset()
end

function VariableEntity:add(v)
    self.variable:add(v)
end

function VariableEntity:subtract(v)
    self.variable:subtract(v)
end

function VariableEntity:event(eventName, component)
    self.object:exec(eventName, self)
end

return VariableEntity