local server = require("src.ipc.server")
local command_handlers = require("src.ipc.command_handlers")
local game_api = require("src.ipc.game_api")

local handler = command_handlers(game_api)
local ipc_server = server(handler)

return {
	start = function(port)
		ipc_server:start(port)
	end,
	update = function(dt)
		ipc_server:update(dt)
	end,
	stop = function()
		ipc_server:close()
	end,
}
