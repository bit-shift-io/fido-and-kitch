local MapList = Class{}

function MapList:init(props)
   self.dir = props.dir
   self.files = love.filesystem.getDirectoryItems(self.dir)
   self.selectedFile = nil
end

function MapList:update(dt)
	Slab.BeginListBox('ListBoxExample')
	for k, file in ipairs(self.files) do
		if str.endsWith(file, '.lua') then
			Slab.BeginListBoxItem('ListBoxExample_Item_' .. k, {Selected = self.selectedFileName == file})
			Slab.Text(file)

			if Slab.IsListBoxItemClicked() then
				self.selectedFileName = file
				self.selectedFile = self.dir .. '/' .. file
			end

			Slab.EndListBoxItem()
		end
	end
	Slab.EndListBox()
end

return MapList