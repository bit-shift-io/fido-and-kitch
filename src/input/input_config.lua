local InputConfig = {}
InputConfig.__index = InputConfig

local DEFAULT_KEYBOARD_MAPS = {
	[1] = {
		left = "left",
		right = "right",
		up = "up",
		down = "down",
		use = "rshift",
		start = "return",
		back = "escape",
	},
	[2] = { left = "a", right = "d", up = "w", down = "s", use = "q", start = "tab", back = "lshift" },
	[3] = {
		left = "left",
		right = "right",
		up = "up",
		down = "down",
		use = "rshift",
		start = "return",
		back = "escape",
	},
	[4] = { left = "a", right = "d", up = "w", down = "s", use = "q", start = "tab", back = "lshift" },
}

local CONFIG_FILE = "input_config.lua"

function InputConfig:new()
	local config = setmetatable({
		keyboardMaps = {},
		joystickDeadzones = {},
		joystickForcedNonGamepad = {},
	}, InputConfig)

	config:load()
	return config
end

function InputConfig:getKeyboardMap(playerIdx)
	return self.keyboardMaps[playerIdx] or DEFAULT_KEYBOARD_MAPS[playerIdx] or DEFAULT_KEYBOARD_MAPS[1]
end

function InputConfig:getDeadzone(playerIdx)
	return self.joystickDeadzones[playerIdx] or 0.2
end

function InputConfig:isForcedNonGamepad(playerIdx)
	return self.joystickForcedNonGamepad[playerIdx] or false
end

function InputConfig:load()
	if not love or not love.filesystem then
		return
	end

	if love.filesystem.getInfo(CONFIG_FILE) then
		local content = love.filesystem.read(CONFIG_FILE)
		if content then
			local chunk, err = load(content)
			if chunk then
				local ok, data = pcall(chunk)
				if ok and data then
					self.keyboardMaps = data.keyboardMaps or {}
					self.joystickDeadzones = data.joystickDeadzones or {}
					self.joystickForcedNonGamepad = data.joystickForcedNonGamepad or {}
				end
			end
		end
	end
end

return InputConfig
