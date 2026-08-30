local HandlerHelpers = {}

local FRAME_DT = 1 / 60

-- Resolve the current InGameState if the game is loaded and in-game. Returns
-- (nil, message) otherwise so the caller can answer with a clear error.
function HandlerHelpers.inGameState()
	if not game or not game.fsm or not game.fsm.currentState then
		return nil, 'Game not loaded'
	end

	local state = game.fsm.currentState
	if state.__class and state.__class.name ~= 'InGameState' then
		return nil, 'Not in game'
	end

	return state
end

-- Advance the fixed 1/60s timestep by `frames` frames, ticking inputManager
-- first then the current game state (mirrors the real update order). Safe to
-- call when the game isn't loaded.
function HandlerHelpers.stepFixed(frames)
	for _ = 1, frames do
		if game and game.fsm and game.fsm.currentState then
			if inputManager and inputManager.update then
				inputManager:update(FRAME_DT)
			end
			game.fsm.currentState:update(FRAME_DT)
		end
	end
end

return HandlerHelpers
