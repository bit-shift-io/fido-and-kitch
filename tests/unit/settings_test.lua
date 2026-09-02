local json = require("src.utils.json")
local Settings = require("src.utils.settings")

-- Settings talks to the LÖVE save directory; here that's a single in-memory
-- file so the tests can inspect exactly what got written.
local function withMockedSave(files, fn)
	local previousLove = love

	love = {
		filesystem = {
			setIdentity = function() end,
			getInfo = function(path)
				return files[path] and {} or nil
			end,
			read = function(path)
				return files[path]
			end,
			write = function(path, content)
				files[path] = content
				return true
			end,
		},
	}

	Settings.reset()
	local ok, err = pcall(fn, files)
	love = previousLove
	Settings.reset()

	if not ok then
		error(err, 0)
	end
end

test("a saved setting is written to settings.json as JSON", function()
	withMockedSave({}, function(files)
		Settings.set("lastMap", "fab1.tmj")

		assertEqual(
			"fab1.tmj",
			json.decode(files["settings.json"]).lastMap,
			"the map started from the menu must survive a restart"
		)
	end)
end)

test("settings are read back from an existing settings.json", function()
	withMockedSave({ ["settings.json"] = '{ "lastMap": "sandbox.tmj" }' }, function()
		assertEqual("sandbox.tmj", Settings.get("lastMap"))
	end)
end)

test("a missing setting falls back to the given default", function()
	withMockedSave({ ["settings.json"] = "{}" }, function()
		assertEqual("fallback.tmj", Settings.get("lastMap", "fallback.tmj"))
	end)
end)

test("a corrupt settings.json is ignored rather than fatal", function()
	withMockedSave({ ["settings.json"] = "not json at all" }, function()
		assertEqual("fallback.tmj", Settings.get("lastMap", "fallback.tmj"))

		-- and it must still be possible to save over the broken file
		assertTrue(Settings.set("lastMap", "fab1.tmj"))
		assertEqual("fab1.tmj", Settings.get("lastMap"))
	end)
end)

test("saving without a filesystem (headless) does not error", function()
	local previousLove = love
	love = nil
	Settings.reset()

	local ok = pcall(Settings.set, "lastMap", "fab1.tmj")

	love = previousLove
	Settings.reset()
	assertTrue(ok, "settings must be optional, never a crash")
end)

test("json round trips the values settings stores", function()
	local encoded = json.encode({ lastMap = "fab1.tmj", volume = 0.5, muted = false, count = 3 })
	local decoded = json.decode(encoded)

	assertEqual("fab1.tmj", decoded.lastMap)
	assertEqual(0.5, decoded.volume)
	assertEqual(false, decoded.muted)
	assertEqual(3, decoded.count)
end)
