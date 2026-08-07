local all_files = {}
local function walk(dir)
  for line in io.popen('find ' .. dir .. ' -name "*.lua" -type f'):lines() do
    table.insert(all_files, line)
  end
end
walk('src')
walk('tests')

local requires = {}
local function scan(path)
  local f = io.open(path)
  if not f then return end
  local content = f:read('*a')
  f:close()
  for m in content:gmatch("require%s*%([%'\"]([^%'\"]+)") do
    requires[m] = (requires[m] or 0) + 1
  end
end
scan('main.lua')
scan('conf.lua')
for _, p in ipairs(all_files) do scan(p) end

local orphans = {}
for _, p in ipairs(all_files) do
  if p:match('^src/') then
    local mod = p:gsub('%.lua$', ''):gsub('^', ''):gsub('/', '.')
    if not requires[mod] then
      table.insert(orphans, mod)
    end
  end
end
table.sort(orphans)
for _, o in ipairs(orphans) do print(o) end