local base64 = require('src.utils.base64')
local zlib = require('zlib')

local function decodeGrid(tmxPath, layerName)
	local f = io.open(tmxPath, 'r')
	local s = f:read('*a')
	f:close()

	local layerPattern = '<layer[^>]*name="' .. layerName .. '"[^>]*>.-<data%-encoding="base64">%s*([%w%+/=%s]-)%s*</data>'
	local b64 = s:match('name="' .. layerName .. '"[^\n]*--<data encoding="base64">')
	-- crude: find data block after the named layer
	local _, e = s:find('<layer[^>]*name="' .. layerName .. '"')
	local block = s:match('(<data encoding="base64">%s*[%w+/=%s]+%s*</data>)', e or 0)
	if not block then return nil end
	b64 = block:match('<data encoding="base64">%s*([%w+/=%s]+)%s*</data>')
	b64 = b64:gsub('%s+', '')
	local raw = base64.decode(b64)
	local dec = zlib.inflate()(raw)
	return dec
end

local dec = decode('res/map/ll2.tmx', 'ground')
if not dec then print('NO DATA'); return end

local w, h = 36, 23
for y = 0, h - 1 do
	local row = ''
	local yKey = y .. ':'
	for x = 0, w - 1 do
		local idx = y * w * 4 + x * 4 + 1
		local g = string.byte(dec, idx) + string.byte(dec, idx + 1) * 256
		row = row .. (g > 0 and '##' or '..')
	end
	print(string.format('%2d', y) .. ' ' .. row)
end