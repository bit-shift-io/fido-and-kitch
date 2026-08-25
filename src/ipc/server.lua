local Class = require('lib.hump.class')
local Log = require('src.utils.log')

local IPCServer = Class{}

function IPCServer:init(handler)
	self.handler = handler
	self.server = nil
	self.running = false
end

function IPCServer:start(port)
	local socket = require('socket')
	local ok, srv = pcall(socket.bind, '127.0.0.1', port or 8081)
	if not ok then
		Log.warn('[IPC] Could not bind port', port or 8081, '— IPC disabled:', srv)
		self.running = false
		return false
	end
	self.server = srv
	self.server:settimeout(0)
	self.running = true
	Log.info('IPC Server listening on 127.0.0.1:' .. (port or 8081))
	return true
end

function IPCServer:update(dt)
	if not self.running or not self.server then
		return
	end

	local client = self.server:accept()
	if client then
		client:settimeout(0.5)
		local line, err = client:receive('*l')
		if line then
			local ok, response = pcall(self.handler.handle, self.handler, line)
			if ok and response then
				client:send(response .. '\n')
			else
				client:send('ERROR: Internal handler error\n')
			end
		elseif err ~= 'timeout' then
			client:send('ERROR: ' .. (err or 'unknown') .. '\n')
		end
		client:close()
	end
end

function IPCServer:close()
	if self.server then
		self.server:close()
		self.server = nil
		self.running = false
		Log.info('IPC Server stopped')
	end
end

return IPCServer