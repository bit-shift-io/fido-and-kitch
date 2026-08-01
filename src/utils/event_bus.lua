local Signal = require('src.utils.signal')

local EventBus = {}
EventBus.signals = {}

function EventBus.getSignal(name)
	if not EventBus.signals[name] then
		EventBus.signals[name] = Signal{}
	end
	return EventBus.signals[name]
end

function EventBus.emit(name, ...)
	local signal = EventBus.getSignal(name)
	signal:emit(...)
end

function EventBus.on(name, fn)
	local signal = EventBus.getSignal(name)
	return signal:connect(fn)
end

function EventBus.off(name, fn)
	local signal = EventBus.signals[name]
	if signal then
		signal:disconnect(fn)
	end
end

function EventBus.clear(name)
	if name then
		EventBus.signals[name] = nil
	else
		EventBus.signals = {}
	end
end

return EventBus