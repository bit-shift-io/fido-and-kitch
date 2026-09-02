-- bump (src/physics/bump/) is the only supported physics backend; the
-- Box2D/love backend was removed for implementing too little of the
-- Collider contract to actually run the game (see NOTES.md for the
-- rationale if a real Box2D backend is ever wanted again).
local World = require("src.physics.bump.world")
return World
