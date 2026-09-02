-- Sound component
-- attaches a table of named WAV sources to an entity; play(name) reuses
-- stopped sources from a pool or creates a new one with random pitch variation
local Log = require('src.utils.log')
local Headless = require('src.utils.headless')
local MAX_POOL_SIZE = 8

local Sound = Class{}

function Sound:init(props)
	self.type = 'sound'
	self.sounds = props.sounds or {}
	self.volume = props.volume or 1
	self.pitchVariation = props.pitchVariation or 0.1
	self.pool = {}
end

function Sound:play(name)
	if Headless.isAudio() then return end

	local path = self.sounds[name]
	if path == nil then
		Log.warn('Sound not found: ' .. tostring(name))
		return
	end

	if love.filesystem.getInfo(path) == nil then
		Log.warn('Sound file not found: ' .. path)
		return
	end

	local source = self:_acquireSource(name, path)
	local pitch = 1 + (love.math.random() * 2 - 1) * self.pitchVariation
	source:setPitch(pitch)
	source:setVolume(self.volume)
	source:play()
	return source
end

function Sound:_acquireSource(name, path)
	local sources = self.pool[name]
	if sources then
		for i, source in ipairs(sources) do
			if not source:isPlaying() then
				source:seek(0)
				table.remove(sources, i)
				return source
			end
		end
	else
		sources = {}
		self.pool[name] = sources
	end

	local source = love.audio.newSource(path, 'static')
	if #sources >= MAX_POOL_SIZE then
		table.remove(sources, 1):stop()
	end
	table.insert(sources, source)
	return source
end

function Sound:destroy()
	for _, sources in pairs(self.pool) do
		for _, source in ipairs(sources) do
			source:stop()
		end
	end
	self.pool = {}
end

return Sound
