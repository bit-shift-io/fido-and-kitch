-- `--coop required` geometry: a small walled-off "vault" placed entirely
-- beyond the layout's own width (never touching zones/ladders/hazards), so
-- it is structurally unreachable by walking or climbing -- only a
-- Switchable teleport, gated by a momentary pressure plate elsewhere, can
-- get a player in. Since a plate is momentary (src/entities/pressure_switch.lua:
-- it releases the instant its weight leaves), a lone player can never be
-- both on the distant plate and at the teleport, so this is unsolvable
-- solo by construction -- no dependency-graph solver needed.
local Coop = {}

local TILE = 32
local VAULT_WIDTH = 5
local VAULT_HEIGHT = 4
local VAULT_GAP = 2 -- empty columns between the layout and the vault

local function surfaceY(row)
	return (row - 1) * TILE
end

--- @param layout A tools.level_generator.layout result.
-- @return {
--   newWidth,                          -- map width once the vault is appended
--   wallCells = {{row, col}, ...},      -- solid wall tiles enclosing the vault
--   interior = {teleportX, keyX, cageX, y},  -- pixel positions on the vault floor
-- }
function Coop.planVault(layout)
	local originCol = layout.width + VAULT_GAP + 1
	local originRow = 2
	local floorRow = originRow + VAULT_HEIGHT - 1
	local newWidth = originCol + VAULT_WIDTH - 1

	local wallCells = {}
	for col = originCol, originCol + VAULT_WIDTH - 1 do
		table.insert(wallCells, {row = originRow, col = col}) -- roof
		table.insert(wallCells, {row = floorRow, col = col}) -- floor
	end
	for row = originRow + 1, floorRow - 1 do
		table.insert(wallCells, {row = row, col = originCol}) -- left wall
		table.insert(wallCells, {row = row, col = originCol + VAULT_WIDTH - 1}) -- right wall
	end

	return {
		newWidth = newWidth,
		wallCells = wallCells,
		interior = {
			teleportX = (originCol + 1 - 1) * TILE,
			keyX = (originCol + 2 - 1) * TILE,
			cageX = (originCol + 3 - 1) * TILE,
			y = surfaceY(floorRow),
		},
	}
end

return Coop
