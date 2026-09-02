-- Shared geometry constants used by entity occupancy/probe queries.

local Geom = {}

-- One tile height (32 px) used as the upward margin when an overlap query
-- needs to detect a standing entity whose feet are on a surface.
Geom.OCCUPANCY_HEIGHT_MARGIN = 32

return Geom
