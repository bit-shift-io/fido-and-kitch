-- Player-facing preferences that outlive a run, kept in `settings.json` in the
-- LÖVE save directory (`t.identity` in conf.lua). Currently just the last map
-- started from the menu, so the menu can reopen on it.
--
-- Deliberately separate from src/input/input_config.lua: that file is a
-- serialized Lua table of key bindings, this one is a small hand-editable JSON
-- file. Nothing here is required for the game to run — every read falls back to
-- a default and every write is best-effort, so a missing, unwritable or corrupt
-- file only ever costs the remembered preference.
local json = require("src.utils.json")
local Log = require("src.utils.log")

local Settings = {}

local FILE = "settings.json"
local IDENTITY = "fido-and-kitch"

local cache = nil

local function filesystem()
	if not love or not love.filesystem then
		return nil
	end
	-- Game:keypressed's F12 handler and the IPC screenshot both call
	-- setIdentity, so don't trust whatever identity is current.
	if love.filesystem.setIdentity then
		pcall(love.filesystem.setIdentity, IDENTITY)
	end
	return love.filesystem
end

function Settings.load()
	if cache then
		return cache
	end

	cache = {}

	local fs = filesystem()
	if not fs or not fs.getInfo or not fs.getInfo(FILE) then
		return cache
	end

	local content = fs.read(FILE)
	if not content then
		return cache
	end

	local data, err = json.decode(content)
	if type(data) ~= "table" then
		Log.warn("Could not read " .. FILE .. ": " .. tostring(err))
		return cache
	end

	cache = data
	return cache
end

function Settings.save()
	local fs = filesystem()
	if not fs or not fs.write then
		return false
	end

	local ok, err = pcall(fs.write, FILE, json.encode(Settings.load()))
	if not ok then
		Log.warn("Could not write " .. FILE .. ": " .. tostring(err))
		return false
	end
	return true
end

function Settings.get(key, default)
	local value = Settings.load()[key]
	if value == nil or value == json.null then
		return default
	end
	return value
end

function Settings.set(key, value)
	local settings = Settings.load()
	if settings[key] == value then
		return true
	end
	settings[key] = value
	return Settings.save()
end

-- tests only: drop the in-memory copy so the next read hits the filesystem
function Settings.reset()
	cache = nil
end

return Settings
