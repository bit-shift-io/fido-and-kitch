-- Small test-only lookup helpers, built on existing entity/component APIs,
-- so integration tests assert on gameplay state without duplicating lookup
-- logic or reaching into private internals.
local Queries = {}

function Queries.findEntityByType(mapInstance, entityType)
	for _, layer in ipairs(mapInstance.layers) do
		if layer.type == 'objectgroup' and layer.entities then
			for _, entity in pairs(layer.entities) do
				if entity.type == entityType then
					return entity
				end
			end
		end
	end
	return nil
end

function Queries.findEntitiesByType(mapInstance, entityType)
	local entities = {}
	for _, layer in ipairs(mapInstance.layers) do
		if layer.type == 'objectgroup' and layer.entities then
			for _, entity in pairs(layer.entities) do
				if entity.type == entityType then
					table.insert(entities, entity)
				end
			end
		end
	end
	return entities
end

-- Object `name` rather than `type`, for fixtures that place several entities
-- of the same type and need to address a specific one. Entity load order
-- within a layer is not something a test should depend on.
function Queries.findEntityByName(mapInstance, name)
	for _, layer in ipairs(mapInstance.layers) do
		if layer.type == 'objectgroup' and layer.entities then
			for _, entity in pairs(layer.entities) do
				if entity.name == name then
					return entity
				end
			end
		end
	end
	return nil
end

function Queries.playerPositionV(player)
	return player.collider:getPositionV()
end

function Queries.playerFacing(player)
	return player.facing
end

function Queries.inventoryCount(player, itemName)
	return player.inventory.items[itemName] or 0
end

function Queries.playerIsDead(player)
	return player:isDead()
end

function Queries.pressureSwitchIsActive(plate)
	return plate:isActive()
end

function Queries.drawbridgeState(bridge)
	return bridge.state
end

function Queries.doorState(door)
	return door.state
end

return Queries
