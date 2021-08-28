-- Helper to wrap function calls with optional instance to call the function on
-- TODO: I think we can replace this class with a simple util function, see state_machine.lua how it forwards on function calls!

local Func = Class{}

function Func:init(fn, inst)
    self.inst = inst
    self.fn = fn
end

function Func:call(...)
    if self.inst then
        self.fn(self.inst, ...)
    else
        self.fn(...)
    end
end

return Func