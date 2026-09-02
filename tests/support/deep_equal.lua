-- Generic recursive table-equality check used by the golden map
-- differential tests: walks two values in parallel and collects every
-- mismatching leaf path (e.g. ".layers.3.objects.2.gid"), rather than just
-- reporting the first difference, so a failing test shows the whole set of
-- fields that drifted instead of one at a time.
local DeepEqual = {}

local function describe(value)
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local function walk(expected, actual, path, mismatches)
	if type(expected) ~= type(actual) then
		table.insert(
			mismatches,
			string.format(
				"%s: expected %s (%s), got %s (%s)",
				path,
				describe(expected),
				type(expected),
				describe(actual),
				type(actual)
			)
		)
		return
	end

	if type(expected) ~= "table" then
		if expected ~= actual then
			table.insert(
				mismatches,
				string.format("%s: expected %s, got %s", path, describe(expected), describe(actual))
			)
		end
		return
	end

	local seenKeys = {}
	for key in pairs(expected) do
		seenKeys[key] = true
	end
	for key in pairs(actual) do
		seenKeys[key] = true
	end

	for key in pairs(seenKeys) do
		walk(expected[key], actual[key], path .. "." .. tostring(key), mismatches)
	end
end

--- Returns a list of human-readable mismatch descriptions; empty if `actual`
-- deep-equals `expected` (key order and array/hash distinction ignored,
-- since Lua tables don't preserve either).
function DeepEqual.diff(expected, actual)
	local mismatches = {}
	walk(expected, actual, "", mismatches)
	table.sort(mismatches)
	return mismatches
end

function DeepEqual.assertEqual(expected, actual, message)
	local mismatches = DeepEqual.diff(expected, actual)
	if #mismatches > 0 then
		error((message or "tables differ") .. ":\n  " .. table.concat(mismatches, "\n  "), 2)
	end
end

return DeepEqual
