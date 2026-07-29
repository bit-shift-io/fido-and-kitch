Class = Class or require('lib.hump.class')
local Sound = require('src.components.sound')

local function fakeSource()
	local source = {calls = {}}
	function source:setPitch(pitch)
		table.insert(self.calls, {name = 'setPitch', pitch = pitch})
	end
	function source:play()
		table.insert(self.calls, {name = 'play'})
	end
	function source:stop()
		table.insert(self.calls, {name = 'stop'})
	end
	return source
end

local function withMockedLove(randomValue, fn, opts)
	opts = opts or {}
	local previousLove = love
	local createdSources = {}
	love = {
		audio = {
			newSource = function(path, kind)
				local source = fakeSource()
				source.path = path
				source.kind = kind
				table.insert(createdSources, source)
				return source
			end,
		},
		math = {
			random = function()
				return randomValue
			end,
		},
		filesystem = {
			-- real LÖVE returns a FileInfo table when the file exists, nil
			-- otherwise; a bare truthy stub is enough for tests that aren't
			-- exercising the missing-file path
			getInfo = opts.getInfo or function(path)
				return {}
			end,
		},
	}

	local ok, err = pcall(fn, createdSources)
	love = previousLove
	if not ok then
		error(err, 2)
	end
end

test('play(name) creates a static Source at the configured path', function()
	withMockedLove(0.5, function(createdSources)
		local sound = Sound{sounds = {jump = 'res/sfx/player_jump.wav'}}

		sound:play('jump')

		assertEqual(1, #createdSources)
		assertEqual('res/sfx/player_jump.wav', createdSources[1].path)
		assertEqual('static', createdSources[1].kind)
	end)
end)

test('play(name) sets pitch within the configured variation and calls play', function()
	withMockedLove(1, function(createdSources)
		local sound = Sound{sounds = {jump = 'res/sfx/player_jump.wav'}, pitchVariation = 0.1}

		sound:play('jump')

		local source = createdSources[1]
		assertNear(1.1, source.calls[1].pitch)
		assertEqual('setPitch', source.calls[1].name)
		assertEqual('play', source.calls[2].name)
	end)
end)

test('play(name) defaults pitch variation to 0.1', function()
	withMockedLove(0, function(createdSources)
		local sound = Sound{sounds = {jump = 'res/sfx/player_jump.wav'}}

		sound:play('jump')

		assertNear(0.9, createdSources[1].calls[1].pitch)
	end)
end)

test('pitch variation of 0 always produces a pitch of 1', function()
	withMockedLove(0.73, function(createdSources)
		local sound = Sound{sounds = {jump = 'res/sfx/player_jump.wav'}, pitchVariation = 0}

		sound:play('jump')

		assertEqual(1, createdSources[1].calls[1].pitch)
	end)
end)

test('play(name) with an unknown name logs a warning and does not error', function()
	withMockedLove(0.5, function(createdSources)
		local sound = Sound{sounds = {jump = 'res/sfx/player_jump.wav'}}

		sound:play('nonexistent')

		assertEqual(0, #createdSources)
	end)
end)

test('play(name) with a missing sound file logs a warning and does not error', function()
	withMockedLove(0.5, function(createdSources)
		local sound = Sound{sounds = {jump = 'res/snd/entity_player_jump.wav'}}

		sound:play('jump')

		assertEqual(0, #createdSources)
	end, {getInfo = function(path) return nil end})
end)

test('destroy() stops every source created by play', function()
	withMockedLove(0.5, function(createdSources)
		local sound = Sound{sounds = {jump = 'res/sfx/player_jump.wav', land = 'res/sfx/player_land.wav'}}
		sound:play('jump')
		sound:play('land')

		sound:destroy()

		assertEqual('stop', createdSources[1].calls[#createdSources[1].calls].name)
		assertEqual('stop', createdSources[2].calls[#createdSources[2].calls].name)
	end)
end)
