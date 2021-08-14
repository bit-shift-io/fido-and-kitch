local Entity = Class{}

function Entity:init()
	self.name = 'entity'
	self.components = {}
end

function Entity:addComponent(component)
	table.insert(self.components, component)
	return component
end

function Entity:update(dt)
	for _, component in pairs(self.components) do
		if component.update ~= nil then
			component:update(dt)
		end
	end
end

function Entity:draw()
	for _, component in pairs(self.components) do
		if component.draw ~= nil then
			component:draw()
		end
	end
end

-- flag this item for removal from the map layer entity list
function Entity:queue_remove()
	self.remove_from_map_flag = true
end

-- flag this item for removal from the map layer entity list then call destroy whenn done
function Entity:queue_destroy()
	self.remove_from_map_flag = true
	self.destroy_flag = true
end

function Entity:destroy()
	for _, component in pairs(self.components) do
		if component.destroy ~= nil then
			component:destroy()
		end
	end
end

return Entity