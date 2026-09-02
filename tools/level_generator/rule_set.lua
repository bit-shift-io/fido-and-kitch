-- Discovers puzzle-rule modules by listing tools/level_generator/rules/ --
-- a new rule file is picked up automatically, no registration here or
-- anywhere else (DECISIONS.md Q14).
local RuleSet = {}

function RuleSet.discover()
	local modules = {}
	local pipe = io.popen("ls tools/level_generator/rules/*.lua 2>/dev/null")
	for path in pipe:lines() do
		local moduleName = path:gsub("%.lua$", ""):gsub("/", ".")
		table.insert(modules, require(moduleName))
	end
	pipe:close()

	table.sort(modules, function(a, b)
		return a.id < b.id
	end)
	return modules
end

return RuleSet
