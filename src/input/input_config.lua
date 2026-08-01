local InputConfig = {}
InputConfig.__index = InputConfig

local DEFAULT_KEYBOARD_MAPS = {
	[1] = {left = 'left', right = 'right', up = 'up', down = 'down', use = 'rshift', start = 'return', back = 'escape'},
	[2] = {left = 'a', right = 'd', up = 'w', down = 's', use = 'q', start = 'tab', back = 'lshift'},
	[3] = {left = 'left', right = 'right', up = 'up', down = 'down', use = 'rshift', start = 'return', back = 'escape'},
	[4] = {left = 'a', right = 'd', up = 'w', down = 's', use = 'q', start = 'tab', back = 'lshift'},
}

local CONFIG_FILE = 'input_config.lua'

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

function InputConfig:setKeyboardMap(playerIdx, action, key)
	if not self.keyboardMaps[playerIdx] then
		self.keyboardMaps[playerIdx] = {}
		for k, v in pairs(DEFAULT_KEYBOARD_MAPS[playerIdx] or DEFAULT_KEYBOARD_MAPS[1]) do
			self.keyboardMaps[playerIdx][k] = v
		end
	end
	self.keyboardMaps[playerIdx][action] = key
	self:save()
end

function InputConfig:resetToDefaults(playerIdx)
	self.keyboardMaps[playerIdx] = nil
	self:save()
end

function InputConfig:getDeadzone(playerIdx)
	return self.joystickDeadzones[playerIdx] or 0.2
end

function InputConfig:setDeadzone(playerIdx, deadzone)
	self.joystickDeadzones[playerIdx] = deadzone
	self:save()
end

function InputConfig:isForcedNonGamepad(playerIdx)
	return self.joystickForcedNonGamepad[playerIdx] or false
end

function InputConfig:setForcedNonGamepad(playerIdx, forced)
	self.joystickForcedNonGamepad[playerIdx] = forced
	self:save()
end

function InputConfig:save()
	if not love or not love.filesystem then return end
	
	local data = {
		keyboardMaps = self.keyboardMaps,
		joystickDeadzones = self.joystickDeadzones,
		joystickForcedNonGamepad = self.joystickForcedNonGamepad,
	}
	
	local serialized = self:serialize(data)
	love.filesystem.write(CONFIG_FILE, serialized)
end

function InputConfig:load()
	if not love or not love.filesystem then return end
	
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

function InputConfig:serialize(data)
	local function serializeValue(v)
		local t = type(v)
		if t == 'string' then
			return string.format('%q', v)
		elseif t == 'number' or t == 'boolean' then
			return tostring(v)
		elseif t == 'table' then
			local parts = {}
			for k, val in pairs(v) do
				local key = type(k) == 'string' and '[' .. string.format('%q', k) .. ']' or '[' .. tostring(k) .. ']'
				table.insert(parts, key .. ' = ' .. serializeValue(val))
			end
			return '{' .. table.concat(parts, ', ') .. '}'
		else
			return 'nil'
		end
	end
	
	return 'return ' .. serializeValue(data)
end

return InputConfig