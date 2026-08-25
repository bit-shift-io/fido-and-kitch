-- Shared physics tolerances used by multiple one-way platform implementations
-- (ladder top slab, mover platform deck). Keeping the value in one place
-- prevents silent drift that would cause visual/physical inconsistencies.

local PhysicsTolerance = {}

-- How far (px) below a one-way platform's top edge a player's feet may sit
-- and still count as "standing on" it. Feet more than this below the top
-- means the player is under the deck (jump-through from below).
PhysicsTolerance.LAND_TOL = 6

return PhysicsTolerance
