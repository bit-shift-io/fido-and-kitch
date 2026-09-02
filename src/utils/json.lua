-- Minimal JSON encode/decode, enough for the small settings file we persist
-- (src/utils/settings.lua). Supports objects, arrays, strings, numbers,
-- booleans and null; no unicode escapes beyond \uXXXX pass-through as '?'.
local json = {}

local ESCAPES = {
	['"'] = '\\"',
	["\\"] = "\\\\",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}

local function escapeString(s)
	return '"' .. s:gsub('[%c"\\]', function(c)
		return ESCAPES[c] or string.format("\\u%04x", c:byte())
	end) .. '"'
end

local function isArray(t)
	local count = 0
	for k in pairs(t) do
		if type(k) ~= "number" then
			return false
		end
		count = count + 1
	end
	return count == #t
end

local function encodeValue(value, indent)
	local t = type(value)
	if value == nil or value == json.null then
		return "null"
	elseif t == "string" then
		return escapeString(value)
	elseif t == "boolean" then
		return tostring(value)
	elseif t == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return "null"
		end
		if value == math.floor(value) then
			return string.format("%d", value)
		end
		return string.format("%.14g", value)
	elseif t == "table" then
		local inner = indent .. "\t"
		local parts = {}
		if isArray(value) then
			if #value == 0 then
				return "[]"
			end
			for _, item in ipairs(value) do
				table.insert(parts, inner .. encodeValue(item, inner))
			end
			return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
		end

		-- sorted keys so the file is stable across saves and diffable
		local keys = {}
		for k in pairs(value) do
			if type(k) == "string" then
				table.insert(keys, k)
			end
		end
		if #keys == 0 then
			return "{}"
		end
		table.sort(keys)
		for _, k in ipairs(keys) do
			table.insert(parts, inner .. escapeString(k) .. ": " .. encodeValue(value[k], inner))
		end
		return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
	end

	return "null"
end

function json.encode(value)
	return encodeValue(value, "")
end

local Decoder = {}
Decoder.__index = Decoder

local WHITESPACE = { [" "] = true, ["\t"] = true, ["\n"] = true, ["\r"] = true }

function Decoder:skipWhitespace()
	while self.pos <= #self.text and WHITESPACE[self.text:sub(self.pos, self.pos)] do
		self.pos = self.pos + 1
	end
end

function Decoder:error(message)
	error("json: " .. message .. " at position " .. self.pos, 0)
end

function Decoder:expect(char)
	if self.text:sub(self.pos, self.pos) ~= char then
		self:error("expected '" .. char .. "'")
	end
	self.pos = self.pos + 1
end

local UNESCAPES = {
	['"'] = '"',
	["\\"] = "\\",
	["/"] = "/",
	b = "\b",
	f = "\f",
	n = "\n",
	r = "\r",
	t = "\t",
}

function Decoder:parseString()
	self:expect('"')
	local parts = {}
	while true do
		local char = self.text:sub(self.pos, self.pos)
		if char == "" then
			self:error("unterminated string")
		end
		self.pos = self.pos + 1
		if char == '"' then
			break
		elseif char == "\\" then
			local escape = self.text:sub(self.pos, self.pos)
			self.pos = self.pos + 1
			if escape == "u" then
				local hex = self.text:sub(self.pos, self.pos + 3)
				self.pos = self.pos + 4
				local code = tonumber(hex, 16)
				table.insert(parts, code and code < 128 and string.char(code) or "?")
			elseif UNESCAPES[escape] then
				table.insert(parts, UNESCAPES[escape])
			else
				self:error("invalid escape")
			end
		else
			table.insert(parts, char)
		end
	end
	return table.concat(parts)
end

function Decoder:parseNumber()
	local numberText = self.text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", self.pos)
	local value = numberText and tonumber(numberText)
	if not value then
		self:error("invalid number")
	end
	self.pos = self.pos + #numberText
	return value
end

function Decoder:parseLiteral()
	for literal, value in pairs({ ["true"] = true, ["false"] = false, ["null"] = json.null }) do
		if self.text:sub(self.pos, self.pos + #literal - 1) == literal then
			self.pos = self.pos + #literal
			return value
		end
	end
	self:error("unexpected token")
end

function Decoder:parseArray()
	self:expect("[")
	local result = {}
	self:skipWhitespace()
	if self.text:sub(self.pos, self.pos) == "]" then
		self.pos = self.pos + 1
		return result
	end
	while true do
		table.insert(result, self:parseValue())
		self:skipWhitespace()
		local char = self.text:sub(self.pos, self.pos)
		self.pos = self.pos + 1
		if char == "]" then
			break
		end
		if char ~= "," then
			self:error("expected ',' or ']'")
		end
	end
	return result
end

function Decoder:parseObject()
	self:expect("{")
	local result = {}
	self:skipWhitespace()
	if self.text:sub(self.pos, self.pos) == "}" then
		self.pos = self.pos + 1
		return result
	end
	while true do
		self:skipWhitespace()
		local key = self:parseString()
		self:skipWhitespace()
		self:expect(":")
		result[key] = self:parseValue()
		self:skipWhitespace()
		local char = self.text:sub(self.pos, self.pos)
		self.pos = self.pos + 1
		if char == "}" then
			break
		end
		if char ~= "," then
			self:error("expected ',' or '}'")
		end
	end
	return result
end

function Decoder:parseValue()
	self:skipWhitespace()
	local char = self.text:sub(self.pos, self.pos)
	if char == "{" then
		return self:parseObject()
	end
	if char == "[" then
		return self:parseArray()
	end
	if char == '"' then
		return self:parseString()
	end
	if char == "-" or char:match("%d") then
		return self:parseNumber()
	end
	return self:parseLiteral()
end

-- decode returns (value) on success, or (nil, message) on malformed input, so
-- callers can fall back to defaults instead of crashing on a corrupt file.
function json.decode(text)
	if type(text) ~= "string" then
		return nil, "json: expected a string"
	end
	local decoder = setmetatable({ text = text, pos = 1 }, Decoder)
	local ok, result = pcall(function()
		local value = decoder:parseValue()
		decoder:skipWhitespace()
		if decoder.pos <= #decoder.text then
			decoder:error("trailing content")
		end
		return value
	end)
	if not ok then
		return nil, tostring(result)
	end
	return result
end

-- sentinel returned for JSON null, so `null` survives a decode/encode round
-- trip without becoming a hole in the table
json.null = setmetatable({}, {
	__tostring = function()
		return "null"
	end,
})

return json
