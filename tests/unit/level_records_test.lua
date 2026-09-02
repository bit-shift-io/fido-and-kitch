local Settings = require("src.utils.settings")
local LevelRecords = require("src.utils.level_records")

-- LevelRecords talks to Settings, which talks to the LÖVE save directory;
-- here that's a single in-memory file so the tests can inspect exactly what
-- got written. Mirrors withMockedSave from tests/unit/settings_test.lua.
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

test("a never-completed map has no record", function()
	withMockedSave({}, function()
		assertEqual(nil, LevelRecords.get("res/map/sandbox.tmj"))
	end)
end)

test("first completion of a level creates its record", function()
	withMockedSave({}, function()
		LevelRecords.recordCompletion("res/map/sandbox.tmj", {
			totalPct = 80,
			medal = "silver",
			timeSeconds = 95,
		})

		local record = LevelRecords.get("res/map/sandbox.tmj")
		assertEqual(80, record.bestScorePct)
		assertEqual("silver", record.medal)
		assertEqual(95, record.bestTimeSeconds)
	end)
end)

test("a strictly better score updates bestScorePct and medal", function()
	withMockedSave({}, function()
		LevelRecords.recordCompletion("res/map/sandbox.tmj", { totalPct = 60, medal = "bronze", timeSeconds = 100 })
		LevelRecords.recordCompletion("res/map/sandbox.tmj", { totalPct = 90, medal = "gold", timeSeconds = 100 })

		local record = LevelRecords.get("res/map/sandbox.tmj")
		assertEqual(90, record.bestScorePct)
		assertEqual("gold", record.medal)
	end)
end)

test("a worse score does not overwrite bestScorePct or medal", function()
	withMockedSave({}, function()
		LevelRecords.recordCompletion("res/map/sandbox.tmj", { totalPct = 90, medal = "gold", timeSeconds = 100 })
		LevelRecords.recordCompletion("res/map/sandbox.tmj", { totalPct = 60, medal = "bronze", timeSeconds = 100 })

		local record = LevelRecords.get("res/map/sandbox.tmj")
		assertEqual(90, record.bestScorePct)
		assertEqual("gold", record.medal)
	end)
end)

test("an equal score does not overwrite bestScorePct or medal", function()
	withMockedSave({}, function()
		LevelRecords.recordCompletion("res/map/sandbox.tmj", { totalPct = 90, medal = "gold", timeSeconds = 100 })
		LevelRecords.recordCompletion("res/map/sandbox.tmj", { totalPct = 90, medal = "silver", timeSeconds = 100 })

		local record = LevelRecords.get("res/map/sandbox.tmj")
		assertEqual(90, record.bestScorePct)
		assertEqual("gold", record.medal, "equal score must not swap in the new medal either")
	end)
end)

test("a strictly faster time updates bestTimeSeconds independently of score", function()
	withMockedSave({}, function()
		LevelRecords.recordCompletion("res/map/sandbox.tmj", { totalPct = 90, medal = "gold", timeSeconds = 100 })
		-- worse score, but faster time: time must still update
		LevelRecords.recordCompletion("res/map/sandbox.tmj", { totalPct = 50, medal = "bronze", timeSeconds = 60 })

		local record = LevelRecords.get("res/map/sandbox.tmj")
		assertEqual(60, record.bestTimeSeconds)
		assertEqual(90, record.bestScorePct, "score stays the prior best since the new run scored lower")
		assertEqual("gold", record.medal)
	end)
end)

test("a slower time does not overwrite bestTimeSeconds", function()
	withMockedSave({}, function()
		LevelRecords.recordCompletion("res/map/sandbox.tmj", { totalPct = 50, medal = "bronze", timeSeconds = 60 })
		LevelRecords.recordCompletion("res/map/sandbox.tmj", { totalPct = 90, medal = "gold", timeSeconds = 100 })

		local record = LevelRecords.get("res/map/sandbox.tmj")
		assertEqual(
			60,
			record.bestTimeSeconds,
			"slower time on the better-scoring run must not overwrite the faster one"
		)
		assertEqual(90, record.bestScorePct)
	end)
end)

test("an equal time does not overwrite bestTimeSeconds", function()
	withMockedSave({}, function()
		LevelRecords.recordCompletion("res/map/sandbox.tmj", { totalPct = 50, medal = "bronze", timeSeconds = 60 })
		LevelRecords.recordCompletion("res/map/sandbox.tmj", { totalPct = 90, medal = "gold", timeSeconds = 60 })

		local record = LevelRecords.get("res/map/sandbox.tmj")
		assertEqual(60, record.bestTimeSeconds)
	end)
end)

test("records for different maps do not collide", function()
	withMockedSave({}, function()
		LevelRecords.recordCompletion("res/map/sandbox.tmj", { totalPct = 90, medal = "gold", timeSeconds = 60 })
		LevelRecords.recordCompletion("res/map/fab1.tmj", { totalPct = 40, medal = "bronze", timeSeconds = 200 })

		local sandbox = LevelRecords.get("res/map/sandbox.tmj")
		local fab1 = LevelRecords.get("res/map/fab1.tmj")

		assertEqual(90, sandbox.bestScorePct)
		assertEqual("gold", sandbox.medal)
		assertEqual(60, sandbox.bestTimeSeconds)

		assertEqual(40, fab1.bestScorePct)
		assertEqual("bronze", fab1.medal)
		assertEqual(200, fab1.bestTimeSeconds)
	end)
end)
