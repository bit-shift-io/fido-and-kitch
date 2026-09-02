-- Headless bootstrap for tests/unit/: wires up the class globals a map
-- entity's `init` reaches for (Class, Entity, Sprite, Collider, Sound, ...)
-- the same way src/main.lua does for the real game, plus a fresh bump
-- `world`. This is what makes a full entity (composing real Sprite/Collider
-- components, e.g. src/entities/drawbridge.lua) constructible and drivable
-- directly in the unit tier, not just its extracted pure-logic helpers.
--
-- What this does NOT do is stand in for love.graphics/love.audio -- `love`
-- stays nil throughout the unit tier, and Sprite/Collider/Sound already
-- degrade to headless-safe no-ops on their own when it's absent (see
-- Sprite's isHeadless, Sound's silentMode). The gap this file closes is
-- narrower: the *class* globals and a world instance, not love itself.
--
-- Idempotent (X = X or require(...)) so requiring this from several test
-- files in one process doesn't re-require needlessly -- matches the
-- existing `Class = Class or require('lib.hump.class')` convention already
-- used ad hoc in kill_zone_test.lua and ground_support_test.lua; this file
-- just gives that convention one shared home covering the full set an
-- entity (rather than a bare Collider) needs.
tbl = tbl or require("src.utils.tbl")
Class = Class or require("lib.hump.class")
Vector = Vector or require("lib.hump.vector")
utils = utils or require("src.utils.utils")
Log = Log or require("src.utils.log")
Signal = Signal or require("src.utils.signal")
Rect = Rect or require("src.utils.rect")
Entity = Entity or require("src.entity")
Tween = Tween or require("lib.tween.tween")
Timeline = Timeline or require("src.components.timeline")
Sprite = Sprite or require("src.components.sprite")
Collider = Collider or require("src.components.collider")
Sound = Sound or require("src.components.sound")
Usable = Usable or require("src.components.usable")
Switchable = Switchable or require("src.components.switchable")

local World = require("src.world")

local HeadlessBootstrap = {}

-- Fresh `world` per test, not a shared one: World is a singleton-shaped
-- instance (colliders/queryRects live on it, not the module), so reusing
-- one across tests would leak colliders from a previous test into the
-- next query. Assigns the global directly -- matching every other
-- World:new(...) call site (Map, ingame_state, kill_zone_test,
-- ground_support_test) -- and returns it too for callers that prefer a
-- local.
function HeadlessBootstrap.resetWorld()
	world = World:new(0, 0, true)
	return world
end

return HeadlessBootstrap
