-- Per-level best-attempt records: best Level score percentage (with its
-- medal) and best completion time, tracked independently of each other (a
-- fast, low-scoring run and a slow, perfect run each update their own
-- field -- see DECISIONS.md Q5). Keyed by map filename.
--
-- A thin wrapper over src/utils/settings.lua's flat, whole-value JSON blob:
-- all records live under one 'levelRecords' settings key as
-- {[mapFile] = {bestScorePct, medal, bestTimeSeconds}, ...}, so every write
-- reads the whole table, mutates one entry, and saves the whole table back.
-- Inherits Settings' "every read falls back to a default, every write is
-- best-effort" philosophy -- a missing/corrupt settings file must not crash
-- level completion.
local Settings = require('src.utils.settings')

local LevelRecords = {}

local SETTINGS_KEY = 'levelRecords'

-- Returns the stored record for mapFile, or nil if it has never been
-- completed.
function LevelRecords.get(mapFile)
	if not mapFile then return nil end

	local records = Settings.get(SETTINGS_KEY, {})
	return records[mapFile]
end

-- Updates the stored record for mapFile with whatever in `result` is
-- strictly better than what's already there. `result` is
-- {totalPct, medal, timeSeconds}. Score (totalPct/medal) and time are
-- independent: a faster time is kept even if this run's score is worse, and
-- vice versa.
function LevelRecords.recordCompletion(mapFile, result)
	if not mapFile then return false end

	local records = Settings.get(SETTINGS_KEY, {})
	local existing = records[mapFile]

	local bestScorePct = existing and existing.bestScorePct
	local medal = existing and existing.medal
	local bestTimeSeconds = existing and existing.bestTimeSeconds

	if not existing or result.totalPct > existing.bestScorePct then
		bestScorePct = result.totalPct
		medal = result.medal
	end

	if not existing or result.timeSeconds < existing.bestTimeSeconds then
		bestTimeSeconds = result.timeSeconds
	end

	records[mapFile] = {
		bestScorePct = bestScorePct,
		medal = medal,
		bestTimeSeconds = bestTimeSeconds,
	}

	return Settings.set(SETTINGS_KEY, records)
end

return LevelRecords
