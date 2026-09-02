local GameAPI = {}

local playerHandler = require("src.ipc.handlers.player")
local mapHandler = require("src.ipc.handlers.map")
local entityHandler = require("src.ipc.handlers.entity")
local debugHandler = require("src.ipc.handlers.debug")

for k, v in pairs(playerHandler) do
	GameAPI[k] = v
end

for k, v in pairs(mapHandler) do
	GameAPI[k] = v
end

for k, v in pairs(entityHandler) do
	GameAPI[k] = v
end

for k, v in pairs(debugHandler) do
	GameAPI[k] = v
end

return GameAPI
