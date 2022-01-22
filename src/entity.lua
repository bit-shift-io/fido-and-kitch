local Entity = Class{}


function Entity:init()
	self.type = 'entity'
	self.components = {}
	self.destroySignal = Signal{} -- is this better as a special component that detects destruction? making entity more light weight
end


function Entity:addComponent(component)
	table.insert(self.components, component)
	component.entity = self
	return component
end


function Entity:removeComponent(component)
	local idx = tbl.findIndexEq(self.components, component)
	if idx then
		table.remove(self.components, idx)
	end
	return component
end


function Entity:update(dt)
	assert(self.components)
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
function Entity:queueRemove()
	self.remove_from_map_flag = true
end


-- flag this item for removal from the map layer entity list then call destroy whenn done
function Entity:queueDestroy()
	self.remove_from_map_flag = true
	self.destroy_flag = true
end


function Entity:destroy()
	for _, component in pairs(self.components) do
		if component.destroy ~= nil then
			component:destroy()
		end
	end
	self.destroySignal:emit(self)
end

function Entity:getComponentByType(componentType)
	for _, component in pairs(self.components) do
		if utils.instanceOf(component, componentType) then
			return component
		end
	end

	return nil
end

return Entity