Class = Class or require('lib.hump.class')
local InputManager = require('src.input.input_manager')

-- 'return' is player 1's `start` action (src/input/input_config.lua), and
-- `start` means two opposite things depending on who is listening: "start the
-- selected map" in MenuState, "leave the map" in InGameState. A press that
-- crosses a state transition therefore has to be swallowed, or the state that
-- just took over reads the same physical press as its own command.
local function withMockedLove(fn)
	local previousLove = love
	local keysDown = {}

	love = {
		keyboard = {
			isDown = function(key) return keysDown[key] == true end,
		},
		joystick = {
			getJoysticks = function() return {} end,
		},
		-- InputConfig:load() looks for a saved config; "no file" keeps the
		-- defaults, which is what these tests are asserting against.
		filesystem = {
			getInfo = function() return nil end,
		},
	}

	local ok, err = pcall(fn, InputManager(), keysDown)

	love = previousLove
	if not ok then
		error(err, 0)
	end
end

test('a press already held when a state transition happens is not reported to the new state', function()
	withMockedLove(function(inputManager, keysDown)
		-- Enter goes down during the event phase. love.keypressed runs there
		-- and switches state before inputManager:update() ever polls the key.
		keysDown['return'] = true
		inputManager:swallowEdges()

		inputManager:update(1 / 60)

		assertFalse(inputManager:wasPressed(1, 'start'),
			'the state entered by this press must not also consume it')
	end)
end)

test('a press held across a state transition stays consumed while it is held', function()
	withMockedLove(function(inputManager, keysDown)
		keysDown['return'] = true
		inputManager:swallowEdges()
		inputManager:update(1 / 60)

		inputManager:update(1 / 60)

		assertFalse(inputManager:wasPressed(1, 'start'),
			'holding the key longer must not produce a delayed edge')
	end)
end)

test('a genuine press after a swallowed one is reported', function()
	withMockedLove(function(inputManager, keysDown)
		keysDown['return'] = true
		inputManager:swallowEdges()
		inputManager:update(1 / 60)

		keysDown['return'] = false
		inputManager:update(1 / 60)
		keysDown['return'] = true
		inputManager:update(1 / 60)

		assertTrue(inputManager:wasPressed(1, 'start'),
			'releasing and pressing again is a new command')
	end)
end)

test('an ordinary press is reported without a state transition', function()
	withMockedLove(function(inputManager, keysDown)
		keysDown['return'] = true

		inputManager:update(1 / 60)

		assertTrue(inputManager:wasPressed(1, 'start'))
	end)
end)

test('swallowing edges only affects the next update', function()
	withMockedLove(function(inputManager, keysDown)
		inputManager:swallowEdges()
		inputManager:update(1 / 60)

		keysDown['left'] = true
		inputManager:update(1 / 60)

		assertTrue(inputManager:wasPressed(1, 'left'),
			'input pressed after the transition frame is live again')
	end)
end)
