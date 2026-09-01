-- Rectangle class
local Rect = Class{}

function Rect:init(props)
    self.x = props.x
    self.y = props.y
    self.width = props.width
    self.height = props.height
end

function Rect:centre()
    return Vector(self.x + self.width * 0.5, self.y + self.height * 0.5)
end

function Rect:colliderShapeArgs()
    return {self.width, self.height}
end

-- Centre of a Tiled map object authored as a tile object (dragged from a
-- tileset/template, has a gid): Tiled anchors those at the BOTTOM edge, so
-- the centre is half a height above object.y. This is the position formula
-- most sprite-bearing entities use (coin, key, switch, teleport, cage,
-- jump_pad, exit_door, ...). Zone/area entities authored as plain rectangles
-- (no gid: ladder, kill_zone, drawbridge) are TOP-anchored instead and use
-- Rect(object):centre() -- the two are not interchangeable, see
-- src/components/pushable/pushable_support.lua's PushableSupport.spawnCentre
-- for the gid-aware version of this same split. pressure_switch sees both
-- shapes across the project's maps and branches on object.gid itself rather
-- than picking one of these helpers.
function Rect.centreOfMapObject(object)
    return Vector(object.x + object.width * 0.5, object.y - object.height * 0.5)
end

-- Collider shape_arguments for a rectangle of the given size -- dimensions
-- only; collider position is supplied separately (Collider props.position),
-- never as part of the shape arguments.
function Rect.shapeArgs(width, height)
    return {width, height}
end

return Rect