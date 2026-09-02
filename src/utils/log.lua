-- Minimal leveled logger. Most of the codebase's diagnostics used to go
-- through bare print(), which meant genuine warnings (a missing sound file,
-- a bad Tiled property) were mixed in with per-action gameplay chatter
-- ("switch has been used", every state's "X enter", every pickup) that
-- floods the console during ordinary play. Log.warn/error stay visible at
-- the default level; Log.debug only prints once Log.level is raised (wired
-- to conf.debug in src/main.lua's setupConf, so `love . debug` shows it).
local Log = {}

local LEVELS = { error = 1, warn = 2, info = 3, debug = 4 }

Log.level = "info"

local function log(level, ...)
	if LEVELS[level] > LEVELS[Log.level] then
		return
	end
	print(...)
end

function Log.error(...)
	log("error", ...)
end

function Log.warn(...)
	log("warn", ...)
end

function Log.info(...)
	log("info", ...)
end

function Log.debug(...)
	log("debug", ...)
end

return Log
