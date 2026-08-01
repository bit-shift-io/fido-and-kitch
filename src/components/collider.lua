-- bump (src/physics/bump/) is the only supported physics backend; see
-- src/world.lua for why the Box2D/love backend was removed.
local Collider = require('src.physics.bump.collider')
return Collider
