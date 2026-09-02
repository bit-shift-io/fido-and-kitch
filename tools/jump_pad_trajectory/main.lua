-- Offline trajectory bake tool: CLI entrypoint.
--
--   lua tools/jump_pad_trajectory/main.lua <level.tmj>
--
-- Reads the raw Tiled JSON (src.utils.json, NOT the game's templated
-- object parser -- see bake.lua's header), bakes every eligible jump_pad
-- object (see bake.lua for the actual transform), and writes the result
-- back to the same file. Run from the repo root (relative requires depend
-- on it, matching tools/level_generator/main.lua's convention).
local json = require("src.utils.json")
local Bake = require("tools.jump_pad_trajectory.bake")

local Main = {}

local function readFile(path)
	local file, err = io.open(path, "r")
	if not file then
		error(string.format('jump_pad_trajectory: could not open "%s": %s', path, tostring(err)), 0)
	end
	local contents = file:read("*a")
	file:close()
	return contents
end

local function writeFile(path, contents)
	local file, err = io.open(path, "w")
	if not file then
		error(string.format('jump_pad_trajectory: could not write "%s": %s', path, tostring(err)), 0)
	end
	file:write(contents)
	file:close()
end

--- Pure core: given already-read JSON text and a path (used only for
-- error messages), bakes and returns (bakedCount, encodedText). No file
-- I/O, so it's directly testable if needed without touching the
-- filesystem.
function Main.bakeText(text, path)
	path = path or "<map>"

	local map, decodeErr = json.decode(text)
	if not map then
		error(string.format("jump_pad_trajectory: %s: malformed JSON: %s", path, tostring(decodeErr)), 0)
	end

	local pads = Bake.findJumpPads(map, path)
	if #pads == 0 then
		error(string.format("jump_pad_trajectory: %s: no jump_pad objects found", path), 0)
	end

	local baked = Bake.bakeMap(map, path)
	return baked, json.encode(map)
end

--- CLI entrypoint: reads argv[1] as a .tmj path, bakes it, and writes the
-- result back to the same file.
function Main.run(argv)
	local path = argv and argv[1]
	if not path then
		io.stderr:write("Usage: lua tools/jump_pad_trajectory/main.lua <level.tmj>\n")
		os.exit(1)
	end

	local ok, bakedOrErr, encoded = pcall(function()
		local text = readFile(path)
		return Main.bakeText(text, path)
	end)

	if not ok then
		io.stderr:write("Error: " .. tostring(bakedOrErr) .. "\n")
		os.exit(1)
	end

	writeFile(path, encoded)
	print(string.format("jump_pad_trajectory: %s: baked %d pad(s)", path, bakedOrErr))
end

if arg and arg[0] and arg[0]:match("main%.lua$") then
	-- arg[1..] here excludes arg[0] itself (standard Lua CLI convention).
	Main.run(arg)
end

return Main
