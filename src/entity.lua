local utils = require('src.utils.utils')
local tbl = require('src.utils.tbl')

local Entity = Class{}


-- object/type are optional: entities backed by a Tiled map object pass both
-- so Entity.init(self, object, 'coin') covers the self.object/self.name/
-- self.type preamble every map entity used to repeat by hand. Callers with
-- nothing map-related (Player, game states) can still call Entity.init(self).
function Entity:init(object, type)
	self.type = type or 'entity'
	self.object = object
	self.name = object and object.name or nil
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
	for _, component in pairs(self.components) do
		if component.postDraw ~= nil then
			component:postDraw()
		end
	end
end


-- Every Sprite-type component this entity owns, in add order.
function Entity:getSprites()
	local sprites = {}
	for _, component in ipairs(self.components) do
		if component.type == 'sprite' then
			sprites[#sprites + 1] = component
		end
	end
	return sprites
end


-- True only when this entity owns 2+ of its own Sprite components with
-- different renderOrder values (unset treated as 0, matching the global
-- sort's own convention) -- see docs/memory/entity-atomic-draw-and-tint.md.
-- An entity with one Sprite, or several sharing the same renderOrder, stays
-- a single atomic draw unit.
function Entity:hasSplitRenderOrder()
	local sprites = self:getSprites()
	if #sprites < 2 then
		return false
	end

	local first = sprites[1].renderOrder or 0
	for i = 2, #sprites do
		if (sprites[i].renderOrder or 0) ~= first then
			return true
		end
	end
	return false
end


-- True if this entity owns a Tint or FlashEffect component -- the one
-- combination unsupported with render-order splitting (see
-- docs/memory/entity-atomic-draw-and-tint.md: their draw()/postDraw() color
-- state relies on nothing else drawing in between).
function Entity:hasColorStateComponent()
	for _, component in ipairs(self.components) do
		if component.type == 'tint' or component.type == 'flash_effect' then
			return true
		end
	end
	return false
end


-- Draws every non-Sprite component of a split entity as one grouped unit
-- (draw() then postDraw(), mirroring Entity:draw()'s own two-pass loop) --
-- used only when Map:drawEntities has pulled this entity's Sprites out into
-- their own per-sprite draw units. Combining that split with Tint/
-- FlashEffect is unsupported: Map:drawEntities logs the misuse via
-- hasColorStateComponent above, this method does not attempt to make the
-- resulting color output correct.
function Entity:drawNonSpriteComponents()
	for _, component in pairs(self.components) do
		if component.type ~= 'sprite' and component.draw ~= nil then
			component:draw()
		end
	end
	for _, component in pairs(self.components) do
		if component.type ~= 'sprite' and component.postDraw ~= nil then
			component:postDraw()
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