local GameAPI = {}
local Helpers = require('src.ipc.handler_helpers')

local function getCamera()
	local state = Helpers.inGameState()
	return state and state.camera
end

function GameAPI.resize(w, h)
	if not _G.love or not _G.love.window then
		return nil, 'love.window not available'
	end
	_G.love.window.setMode(w, h)
	return 'OK: Resized to ' .. w .. 'x' .. h
end

function GameAPI.toggleCamera()
	if not game or not game.fsm or not game.fsm.currentState then
		return nil, 'Game not loaded'
	end

	local camera = getCamera()
	if camera then
		camera:toggleOverview()
		return 'OK: Camera overview toggled'
	end

	return nil, 'Camera not available'
end

function GameAPI.takeScreenshot(filename)
	if not _G.love or not _G.love.graphics then
		return nil, 'love.graphics not available'
	end
	
	local cwd = love.filesystem.getWorkingDirectory() .. '/' .. filename .. '.png'
	love.graphics.captureScreenshot(cwd)
	
	return 'OK: Screenshot saved to ' .. cwd
end

function GameAPI.stepFrames(count)
	local state, err = Helpers.inGameState()
	if not state then
		return nil, err
	end

	Helpers.stepFixed(count)

	return 'OK: Stepped ' .. count .. ' frames'
end

function GameAPI.toggleDebugDraw()
	conf.drawphysics = not conf.drawphysics
	return 'OK: Debug draw ' .. (conf.drawphysics and 'enabled' or 'disabled')
end

return GameAPI