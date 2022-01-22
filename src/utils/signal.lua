-- Signal class to easily allow multiple slots (aka functions) to listen for events
local Signal = Class{}

function Signal:init(object)
    self.slots = {}
end

function Signal:connect(fn)
    local idx = tbl.findIndexEq(self.slots, fn)
    if (idx) then
        return
    end
    table.insert(self.slots, fn)
end

function Signal:disconnect(fn)
    local idx = tbl.findIndexEq(self.slots, fn)
    if (idx) then
        table.remove(self.slots, idx)
    end
end

function Signal:emit(...)
    for _, s in ipairs(self.slots) do
        s(...)
    end
end

return Signal