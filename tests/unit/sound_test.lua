Class = Class or require("lib.hump.class")
local Sound = require("src.components.sound")

local function fakeSource()
	local source = { calls = {}, _playing = false }
	function source:setPitch(pitch)
		table.insert(self.calls, { name = "setPitch", pitch = pitch })
	end
	function source:setVolume(vol)
		table.insert(self.calls, { name = "setVolume", volume = vol })
	end
	function source:play()
		self._playing = true
		table.insert(self.calls, { name = "play" })
	end
	function source:stop()
		self._playing = false
		table.insert(self.calls, { name = "stop" })
	end
	function source:isPlaying()
		return self._playing
	end
	function source:seek(offset)
		table.insert(self.calls, { name = "seek", offset = offset })
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

test("play(name) creates a static Source at the configured path", function()
	withMockedLove(0.5, function(createdSources)
		local sound = Sound({ sounds = { jump = "res/sfx/player_jump.wav" } })

		sound:play("jump")

		assertEqual(1, #createdSources)
		assertEqual("res/sfx/player_jump.wav", createdSources[1].path)
		assertEqual("static", createdSources[1].kind)
	end)
end)

test("play(name) sets pitch within the configured variation and calls play", function()
	withMockedLove(1, function(createdSources)
		local sound = Sound({ sounds = { jump = "res/sfx/player_jump.wav" }, pitchVariation = 0.1 })

		sound:play("jump")

		local source = createdSources[1]
		assertNear(1.1, source.calls[1].pitch)
		assertEqual("setPitch", source.calls[1].name)
		assertEqual("setVolume", source.calls[2].name)
		assertEqual("play", source.calls[3].name)
	end)
end)

test("play(name) defaults pitch variation to 0.1", function()
	withMockedLove(0, function(createdSources)
		local sound = Sound({ sounds = { jump = "res/sfx/player_jump.wav" } })

		sound:play("jump")

		assertNear(0.9, createdSources[1].calls[1].pitch)
	end)
end)

test("pitch variation of 0 always produces a pitch of 1", function()
	withMockedLove(0.73, function(createdSources)
		local sound = Sound({ sounds = { jump = "res/sfx/player_jump.wav" }, pitchVariation = 0 })

		sound:play("jump")

		assertEqual(1, createdSources[1].calls[1].pitch)
	end)
end)

test("play(name) with an unknown name logs a warning and does not error", function()
	withMockedLove(0.5, function(createdSources)
		local sound = Sound({ sounds = { jump = "res/sfx/player_jump.wav" } })

		sound:play("nonexistent")

		assertEqual(0, #createdSources)
	end)
end)

test("play(name) with a missing sound file logs a warning and does not error", function()
	withMockedLove(0.5, function(createdSources)
		local sound = Sound({ sounds = { jump = "res/snd/entity_player_jump.wav" } })

		sound:play("jump")

		assertEqual(0, #createdSources)
	end, {
		getInfo = function(path)
			return nil
		end,
	})
end)

test("destroy() stops every source created by play", function()
	withMockedLove(0.5, function(createdSources)
		local sound = Sound({ sounds = { jump = "res/sfx/player_jump.wav", land = "res/sfx/player_land.wav" } })
		sound:play("jump")
		sound:play("land")

		sound:destroy()

		for _, source in ipairs(createdSources) do
			assertEqual("stop", source.calls[#source.calls].name)
		end
	end)
end)

test("play(name) reuses a stopped source instead of creating a new one", function()
	withMockedLove(0.5, function(createdSources)
		local sound = Sound({ sounds = { jump = "res/sfx/player_jump.wav" } })

		sound:play("jump")
		assertEqual(1, #createdSources)

		createdSources[1]._playing = false
		sound:play("jump")
		assertEqual(1, #createdSources)
		-- the source should have been seeked to 0
		local seekCall = nil
		for _, c in ipairs(createdSources[1].calls) do
			if c.name == "seek" then
				seekCall = c
			end
		end
		assertTrue(seekCall ~= nil)
		assertEqual(0, seekCall.offset)
	end)
end)

test("play(name) creates a new source if all pooled sources are still playing", function()
	withMockedLove(0.5, function(createdSources)
		local sound = Sound({ sounds = { jump = "res/sfx/player_jump.wav" } })

		sound:play("jump")
		assertEqual(1, #createdSources)

		sound:play("jump")
		assertEqual(2, #createdSources)
	end)
end)

test("play(name) sets volume from the volume prop", function()
	withMockedLove(0.5, function(createdSources)
		local sound = Sound({ sounds = { jump = "res/sfx/player_jump.wav" }, volume = 0.5 })

		sound:play("jump")

		local volCall = nil
		for _, c in ipairs(createdSources[1].calls) do
			if c.name == "setVolume" then
				volCall = c
			end
		end
		assertTrue(volCall ~= nil)
		assertEqual(0.5, volCall.volume)
	end)
end)

test("play(name) defaults volume to 1", function()
	withMockedLove(0.5, function(createdSources)
		local sound = Sound({ sounds = { jump = "res/sfx/player_jump.wav" } })

		sound:play("jump")

		local volCall = nil
		for _, c in ipairs(createdSources[1].calls) do
			if c.name == "setVolume" then
				volCall = c
			end
		end
		assertTrue(volCall ~= nil)
		assertEqual(1, volCall.volume)
	end)
end)
