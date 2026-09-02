-- Spies on Log.error calls to verify error messages are logged.
-- Returns a spy object with captured errors and an uninstall function.
local LogSpy = {}

function LogSpy.install()
	local Log = require("src.utils.log")
	local original = Log.error
	local errors = {}

	Log.error = function(...)
		table.insert(errors, table.concat({ ... }, " "))
		return original(...)
	end

	return {
		errors = errors,
		uninstall = function()
			Log.error = original
		end,
	}
end

return LogSpy
