-- Usable component
-- an item the player (or entity) can use

local Log = require("src.utils.log")
local UsableSparkle = require("src.components.usable_sparkle")

local Usable = Class({})

function Usable:init(props)
	self.type = "usable"
	self.entity = props.entity
	self.useFunc = props.use
	self.canUseFunc = props.canUse -- optional override for complex canUse situations
	-- single required item (sugar) or a table of item/count pairs
	self.requiredItem = props.requiredItem
	self.requiredItemCount = props.requiredItemCount or 1
	self.requiredItems = props.requiredItems
	self.consumeItems = props.consumeItems or false -- consume on use?
	self.playerAnimationOnUse = props.playerAnimationOnUse
	self.enabled = (props.enabled == nil) and true or props.enabled
	-- Ambient sparkle hint while in range. nil/true = on; false = off; a table
	-- passes per-entity options through to UsableSparkle (texture, range, rate).
	self.sparkles = props.sparkles
end

-- Normalize the single-item and multi-item requirement forms into one
-- {[itemName] = count} map (nil when no items are required).
function Usable:requiredItemsMap()
	if self.requiredItems then
		return self.requiredItems
	end
	if self.requiredItem then
		return { [self.requiredItem] = self.requiredItemCount }
	end
	return nil
end

-- Apply the "glow can be used" sparkles to every usable automatically. Attached
-- on the same entity (named 'usable_sparkle'); Entity:addComponent calls this
-- for us after the Usable is registered, so usables need no per-entity wiring.
function Usable:onAttach(entity)
	if self.sparkles == false then
		return
	end
	local opts = type(self.sparkles) == "table" and self.sparkles or {}
	entity:addComponent(
		UsableSparkle({
			entity = entity,
			texture = opts.texture,
			range = opts.range,
			rate = opts.rate,
			width = opts.width,
			height = opts.height,
		}),
		"usable_sparkle"
	)
end

function Usable:onDetach()
	if self.sparkles ~= false and self.entity then
		self.entity:removeComponent("usable_sparkle")
	end
end

function Usable:canUse(user)
	if self.canUseFunc then
		return self.canUseFunc(user)
	end

	if self.enabled == false then
		return false
	end

	local requiredItems = self:requiredItemsMap()
	if requiredItems then
		-- check the user has the required items in their inventory
		local inventory = user:getComponent(Inventory)
		if inventory then
			for itemName, count in pairs(requiredItems) do
				if inventory:hasItems(itemName, count) == false then
					Log.warn("cant use usable, missing " .. count .. "x " .. itemName)
					return false
				end
			end
		end
	end

	return true
end

function Usable:use(user)
	Log.debug("usable is being used")

	local requiredItems = self:requiredItemsMap()
	if requiredItems then
		local inventory = user:getComponent(Inventory)
		if inventory then
			for itemName, count in pairs(requiredItems) do
				inventory:removeItems(itemName, count)
			end
		end
	end

	self.useFunc(user)
end

return Usable
