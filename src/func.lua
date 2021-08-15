-- Helper to wrap function calls with optional instance to call the function on

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