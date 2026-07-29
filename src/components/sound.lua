-- Sound component
-- attaches a table of named WAV sources to an entity; play(name) creates
-- a fresh Source each time with random pitch variation (no pooling)
local Sound = Class{}

function Sound:init(props)
	self.type = 'sound'
	self.sounds = props.sounds or {}
	self.pitchVariation = props.pitchVariation or 0.1
	self.sources = {}
end

function Sound:play(name)
	local path = self.sounds[name]
	if path == nil then
		print('Sound not found: ' .. tostring(name))
		return
	end

	if love.filesystem.getInfo(path) == nil then
		print('Sound file not found: ' .. path)
		return
	end

	local source = love.audio.newSource(path, 'static')
	local pitch = 1 + (love.math.random() * 2 - 1) * self.pitchVariation
	source:setPitch(pitch)
	source:play()

	table.insert(self.sources, source)
	return source
end

function Sound:destroy()
	for _, source in ipairs(self.sources) do
		source:stop()
	end
	self.sources = {}
end

return Sound
