-- Spies on every entity's Sound component for the duration of a test by
-- wrapping the shared Sound.play method (hump class instances resolve
-- methods through the class table's __index, so patching it here reaches
-- every Sound instance already constructed and any constructed afterward).
-- Records names in call order so tests can assert what was played without
-- reaching into a specific entity's internals.
local SoundSpy = {}

function SoundSpy.install()
	local Sound = require("src.components.sound")
	local original = Sound.play
	local played = {}

	Sound.play = function(self, name)
		table.insert(played, name)
		return original(self, name)
	end

	return {
		played = played,
		uninstall = function()
			Sound.play = original
		end,
	}
end

return SoundSpy
