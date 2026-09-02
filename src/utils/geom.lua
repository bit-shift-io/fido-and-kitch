-- Shared geometry constants used by entity occupancy/probe queries.

local Geom = {}

-- The game's world tile size in pixels/units (32). Doubles as the default
-- dimension for anything that otherwise defaults to a single-tile footprint.
Geom.TILE_SIZE = 32

-- One tile height used as the upward margin when an overlap query needs to
-- detect a standing entity whose feet are on a surface.
Geom.OCCUPANCY_HEIGHT_MARGIN = Geom.TILE_SIZE

return Geom
