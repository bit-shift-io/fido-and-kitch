local utils = require('src.utils.utils')
local tbl = require('src.utils.tbl')

local Entity = Class{}


function Entity:init()
	self.type = 'entity'
	self.components = {}             -- Array for ordered update/draw iteration
	self.componentsByType = {}       -- Table for O(1) type/name lookups
	self.destroySignal = Signal{} -- is this better as a special component that detects destruction? making entity more light weight
end


function Entity:addComponent(component, name)
	table.insert(self.components, component)
	component.entity = self

	local key = name or component.class or getmetatable(component)
	if key then
		self.componentsByType[key] = component
	end

	if component.onAttach then
		component:onAttach(self)
	end
	return component
end


function Entity:removeComponent(nameOrType)
	-- Try to find by key in componentsByType first
	local component = self.componentsByType[nameOrType]
	if not component then
		-- Fallback: linear search by reference
		for _, c in ipairs(self.components) do
			if c == nameOrType or utils.instanceOf(c, nameOrType) then
				component = c
				break
			end
		end
	end

	if component then
		-- Remove from array
		local idx = tbl.findIndexEq(self.components, component)
		if idx then
			table.remove(self.components, idx)
		end

		-- Remove from lookup map
		for key, c in pairs(self.componentsByType) do
			if c == component then
				self.componentsByType[key] = nil
				break
			end
		end

		if component.onDetach then
			component:onDetach()
		end
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
		if component.onDestroy then
			component:onDestroy()
		elseif component.destroy ~= nil then
			component:destroy()
		end
	end
	self.destroySignal:emit(self)
end

function Entity:getComponent(typeOrName)
	local comp = self.componentsByType[typeOrName]
	if comp then return comp end

	-- Fallback linear search for legacy class inheritance queries
	for _, c in ipairs(self.components) do
		if utils.instanceOf(c, typeOrName) then
			return c
		end
	end
	return nil
end

return Entity