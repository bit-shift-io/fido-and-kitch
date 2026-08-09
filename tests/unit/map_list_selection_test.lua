Class = Class or require('lib.hump.class')
local MapList = require('src.ui.map_list')

-- MapList:init builds fonts and parses every map in res/map, so these tests
-- drive the selection methods against a hand-built card list instead.
local function listOf(...)
	local cards = {}
	for _, file in ipairs({...}) do
		table.insert(cards, {file = file, path = 'res/map/' .. file})
	end
	return setmetatable({cards = cards, selectedIndex = 1}, MapList)
end

test('the last map played is restored as the selected card', function()
	local list = listOf('a.tmx', 'b.tmx', 'c.tmx')

	assertTrue(list:selectFile('c.tmx'))

	assertEqual('res/map/c.tmx', list.selectedFile)
	assertEqual('c.tmx', list.selectedFileName)
end)

test('a remembered map that no longer exists leaves the first card selected', function()
	local list = listOf('a.tmx', 'b.tmx')
	list:updateSelection()

	assertFalse(list:selectFile('deleted.tmx'))

	assertEqual('res/map/a.tmx', list.selectedFile)
end)
