-- Utility file I/O with love.filesystem fallback for headless tests.

local FileUtils = {}

local isHeadless = love and not love.filesystem.isFile
dependencies = dependencies or {}
--- Load a file into a string.
--- Handles love.filesystem in runtime and a no-op fallback for unit tests.
--- @param path string Path relative to the game root
--- @return string content
function FileUtils.load(path)
	if isHeadless then
		local dep = dependencies[path]
		if dep then
			return dep
		end
		error("File not loaded in headless test: " .. path)
	end
	local file, err = love.filesystem.openFileData(path)
	if not file then
		error("Failed to open " .. path .. ": " .. err)
	end
	return file:getString()
end

--- Write a file from a string.
--- No-op in headless mode to avoid side effects.
--- @param path string
--- @param content string
function FileUtils.write(path, content)
	if isHeadless then
		return
	end
	local file, err = love.filesystem.newFileData(path)
	if not file then
		error("Failed to create " .. path .. ": " .. err)
	end
	file:setString(content)
	love.filesystem.write(path, file:getString())
	file:release()
end

--- Check if a file exists.
--- In headless mode, check dependencies map instead.
--- @param path string
--- @return boolean
function FileUtils.exists(path)
	if isHeadless then
		return dependencies[path] ~= nil
	end
	return love.filesystem.getInfo(path) ~= nil
end

return FileUtils
