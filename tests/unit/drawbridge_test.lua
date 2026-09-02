-- Two tiers of coverage for src/entities/drawbridge.lua, both headless:
--
-- 1. Pure decision-helper tests against Drawbridge._internal -- fast,
--    construction-free, one assertion per branch. These used to run
--    against a separate drawbridge_support.lua required directly; now
--    that a full entity can be built headless (see part 2), the helpers
--    stay private locals in drawbridge.lua and are reached via the
--    white-box seam it exposes for exactly this file (see its own comment).
--
-- 2. Entity-level tests that construct a real Drawbridge -- real Sprite,
--    real Collider, a real bump World -- via tests/support/headless_bootstrap,
--    and drive it through Drawbridge:update(dt) the way the game does.
--    This tier didn't exist before headless_bootstrap: constructing the
--    entity needed the class globals (Class, Entity, Sprite, Collider,
--    Sound, ...) src/main.lua normally wires, which nothing in tests/unit/
--    previously supplied.
--
-- The spatial "no fall" / "wrong side blocked" acceptance criteria still
-- belong to tests/e2e/drawbridge_test.lua (real rendering), and the
-- anything-holds-it / enemy-follow-across / reset-on-restart scenarios stay
-- in tests/integration/drawbridge_test.lua (real Game/Map stack) -- this
-- file covers the decision logic and the entity's own wiring, not the
-- surrounding game.
local HeadlessBootstrap = require("tests.support.headless_bootstrap")
local SoundSpy = require("tests.support.sound_spy")

local Drawbridge = require("src.entities.drawbridge")
local D = Drawbridge._internal

--
-- Part 1: pure decision helpers
--

-- The trigger is a thin strip flush against the gap's edge (not a full
-- tile out) -- so the deck visibly starts lowering only once the player is
-- right at the edge, reading as "pushing the gate down" rather than
-- tripping a remote sensor a whole tile away.
test("non-flipped (leftToRight) places the trigger sensor flush against the gap, on the left (arrival side)", function()
	-- tileWidth=32, triggerWidth=8: trigger's right edge (offset + half its
	-- own width) must land exactly on the deck's left edge (half the tile)
	assertEqual(-20, D.triggerOffsetX(false, 32, 8))
end)

test("flipCrossing=true places the trigger sensor flush against the gap, on the right (arrival side)", function()
	assertEqual(20, D.triggerOffsetX(true, 32, 8))
end)

test("a missing flipCrossing falls back to non-flipped (left-to-right)", function()
	assertEqual(-20, D.triggerOffsetX(nil, 32, 8))
end)

test("non-flipped renders unmirrored -- tower on the left, deck lowering rightward over the gap", function()
	assertEqual("right", D.spriteFacing(false))
end)

test("flipCrossing=true renders mirrored", function()
	assertEqual("left", D.spriteFacing(true))
end)

test("a missing flipCrossing renders unmirrored (matches the non-flipped fallback)", function()
	assertEqual("right", D.spriteFacing(nil))
end)

test("the sprite box is the object dimensions, 1:1 (drawbridge.tj: 64x64 art box)", function()
	local width, height = D.spriteBoxDimensions(64, 64)
	assertEqual(64, width)
	assertEqual(64, height)
end)

test("the sprite box derives from the object dimensions, not a hard-coded size", function()
	local width, height = D.spriteBoxDimensions(48, 64)
	assertEqual(48, width)
	assertEqual(64, height)
end)

test("closed state has no walkable deck (the gap is fully exposed, no barrier)", function()
	assertFalse(D.isDeckSolid("closed"))
end)

test("opening, open, and closing states have a solid deck", function()
	for _, state in ipairs({ "opening", "open", "closing" }) do
		assertTrue(D.isDeckSolid(state), state .. " should have a solid deck")
	end
end)

test("the open animation finishing transitions opening to open", function()
	assertEqual("open", D.nextStateOnAnimationFinish("opening"))
end)

test("the close animation finishing transitions closing to closed", function()
	assertEqual("closed", D.nextStateOnAnimationFinish("closing"))
end)

test("animation finish has no effect on closed or open (nothing mid-flight)", function()
	assertEqual("closed", D.nextStateOnAnimationFinish("closed"))
	assertEqual("open", D.nextStateOnAnimationFinish("open"))
end)

test("held is any collider (in the combined trigger+deck overlap set) whose entity is not the bridge itself", function()
	local bridge = {}
	local occupantCollider = { entity = { type = "player" } }
	local ownCollider = { entity = bridge }
	local groundCollider = { entity = nil }

	assertTrue(D.isHeld({ occupantCollider }, bridge))
	assertFalse(D.isHeld({ ownCollider, groundCollider }, bridge))
	assertFalse(D.isHeld({}, bridge))
end)

test("anything holds the bridge, not just players -- eligibility no longer exists", function()
	local bridge = {}
	local enemyCollider = { entity = { type = "enemy" } }
	local pushBoxCollider = { entity = { type = "push_box" } }

	assertTrue(D.isHeld({ enemyCollider }, bridge))
	assertTrue(D.isHeld({ pushBoxCollider }, bridge))
end)

-- Only the trigger tile can break a closed bridge -- not the deck alone.
-- This is what keeps a wrong-side approach a real hazard: a wide collider
-- grazing the far edge of the deck tile (while still standing on solid
-- ground on the wrong side) must not pre-emptively solidify the gap for it.
-- Direction only gates this one edge; every other transition is driven by
-- either zone once the bridge is already moving (see below).
test("only the trigger can break a closed bridge -- deck overlap alone does nothing", function()
	assertEqual("closed", D.nextStateOnHeldChange("closed", false, true))
	assertEqual("opening", D.nextStateOnHeldChange("closed", true, false))
	assertEqual("opening", D.nextStateOnHeldChange("closed", true, true))
end)

-- once already closing (deck still solid throughout), either zone re-holds
-- it -- an occupant who never left the deck, or a fresh trigger touch, both
-- reverse it back to opening
test("either zone reopens a closing bridge", function()
	assertEqual("opening", D.nextStateOnHeldChange("closing", true, false))
	assertEqual("opening", D.nextStateOnHeldChange("closing", false, true))
	assertEqual("closing", D.nextStateOnHeldChange("closing", false, false))
end)

test("unheld in both zones pushes an open or opening bridge toward closing", function()
	assertEqual("closing", D.nextStateOnHeldChange("open", false, false))
	assertEqual("closing", D.nextStateOnHeldChange("opening", false, false))
end)

test("held in either zone has no effect on an already-opening or already-open bridge", function()
	assertEqual("opening", D.nextStateOnHeldChange("opening", true, false))
	assertEqual("open", D.nextStateOnHeldChange("open", false, true))
end)

-- the previously-unreachable path: open -> closing -> opening (reopened
-- mid-close) -> open -> closing (closes again once cleared). No flag, no
-- memory of past occupancy -- held is recomputed fresh every frame.
test("a bridge that reopens mid-close still closes again once cleared (the stuck-down regression)", function()
	local state = "open"

	state = D.nextStateOnHeldChange(state, false, false) -- last occupant leaves
	assertEqual("closing", state)

	state = D.nextStateOnHeldChange(state, false, true) -- re-occupies the deck mid-close
	assertEqual("opening", state)

	state = D.nextStateOnAnimationFinish(state)
	assertEqual("open", state)

	state = D.nextStateOnHeldChange(state, false, false) -- cleared again
	assertEqual("closing", state, "expected the reopened bridge to still be able to close again once cleared")

	state = D.nextStateOnAnimationFinish(state)
	assertEqual("closed", state)
end)

-- the free-play repro (DECISIONS.md Q3): entering only the trigger tile
-- and retreating before ever reaching the deck must not get stuck --
-- unheld-in-both-zones still closes it once the animation finishes to open
test("turning back from the trigger alone, before ever touching the deck, still closes again", function()
	local state = "closed"

	state = D.nextStateOnHeldChange(state, true, false) -- enters the trigger tile
	assertEqual("opening", state)

	-- retreats fully -- neither zone held from here on
	state = D.nextStateOnAnimationFinish(state)
	assertEqual("open", state)

	state = D.nextStateOnHeldChange(state, false, false)
	assertEqual("closing", state, "expected the bridge to raise again once genuinely unheld, never stuck open")
end)

--
-- Part 2: entity-level, against a real constructed Drawbridge
--

-- a bare dynamic collider standing in for an occupant (player/enemy/pushed
-- box) -- mirrors the fake-collider convention in kill_zone_test.lua and
-- tests/integration/drawbridge_test.lua's spawnEnemy. groupIndex must be
-- concrete and distinct from -1 (the players' group), since two colliders
-- that never set one both read groupIndex == nil, and nil == nil is true
-- in Lua -- World.colFilter would otherwise treat them as the same group
-- and never collide them at all.
local function spawnOccupant(x, y)
	local occupant = Collider({
		shape_type = "rectangle",
		shape_arguments = { 8, 30 },
		body_type = "dynamic",
		position = { x = x, y = y },
	})
	occupant.entity = { type = "occupant" }
	occupant:setGroupIndex(100)
	return occupant
end

local function makeBridge(flipCrossing, extraProps)
	HeadlessBootstrap.resetWorld()
	extraProps = extraProps or {}
	local properties = {
		flipCrossing = flipCrossing,
		-- template art merged in-game (res/entities/drawbridge.tj); the
		-- image now comes from the template's inline tileset tile and the
		-- loader injects it into merged properties, so the stub mirrors
		-- that to cut the real 4-frame sheet...
		image = "res/img/entity_drawbridge.png",
		frames = 4,
		duration = 0.3,
		loop = false,
		playing = false,
		-- ...and the gameplay footprint stays one tile (the sprite box is
		-- the 64x64 art box above; the deck/trigger/occupancy colliders
		-- derive from these props, exactly like the real template)
		colliderWidth = 32,
		colliderHeight = 32,
	}
	for k, v in pairs(extraProps) do
		properties[k] = v
	end
	return Drawbridge({
		x = 128,
		y = 96,
		width = 64,
		height = 64,
		properties = properties,
	})
end

test("constructs headless with a real Sprite/Collider/World stack, closed and non-solid", function()
	local bridge = makeBridge(false)

	assertEqual("closed", bridge.state)
	assertTrue(bridge.deck:isSensor(), "closed deck should be a sensor -- gap fully exposed, no barrier")
	assertEqual(4, #bridge.sprite.frames)
end)

test("spriteOffsetX/spriteOffsetY shift only the sprite -- the deck keeps the authored rect", function()
	local plain = makeBridge(false)

	assertEqual(160, plain.sprite.position.x, "no offset: the sprite sits on the art box centre")
	assertEqual(128, plain.sprite.position.y, "no offset: the sprite sits on the art box centre")

	local nudged = makeBridge(false, { spriteOffsetX = 8, spriteOffsetY = -16 })

	assertEqual(168, nudged.sprite.position.x, "positive X offset moves the art right")
	assertEqual(112, nudged.sprite.position.y, "negative Y offset lifts the art")
	local deckPos = nudged.deck:getPositionV()
	assertEqual(144, deckPos.x, "the deck collider never follows the art offset")
	assertEqual(112, deckPos.y, "the deck collider never follows the art offset")
end)

test("colliderOffsetX/colliderOffsetY shift only the gameplay footprint -- the art keeps its centre", function()
	local plain = makeBridge(false)

	local shifted = makeBridge(false, { colliderOffsetX = 8, colliderOffsetY = -16 })

	assertEqual(160, shifted.sprite.position.x, "the art never follows the collider offset")
	assertEqual(128, shifted.sprite.position.y, "the art never follows the collider offset")
	local deckPos = shifted.deck:getPositionV()
	assertEqual(152, deckPos.x, "positive X offset moves the deck right")
	assertEqual(96, deckPos.y, "negative Y offset lifts the deck")
	assertEqual(136, shifted.rect.x, "gameplay rect origin carries the X offset")
	assertEqual(80, shifted.rect.y, "gameplay rect origin carries the Y offset")
	local plainPos = plain.deck:getPositionV()
	assertEqual(144, plainPos.x, "no offset: deck sits on the object corner")
	assertEqual(112, plainPos.y, "no offset: deck sits on the object corner")
end)

test("non-flipped construction places the trigger left of the deck and faces the sprite right", function()
	local bridge = makeBridge(false)

	assertTrue(bridge.triggerCentre.x < bridge.rect:centre().x, "trigger should sit left of the deck centre")
	assertEqual("right", bridge.sprite.facing)
end)

test("flipCrossing=true construction places the trigger right of the deck and mirrors the sprite", function()
	local bridge = makeBridge(true)

	assertTrue(bridge.triggerCentre.x > bridge.rect:centre().x, "trigger should sit right of the deck centre")
	assertEqual("left", bridge.sprite.facing)
end)

test("an occupant entering the trigger zone opens the bridge and solidifies the deck", function()
	local bridge = makeBridge(false)
	local spy = SoundSpy.install()

	-- non-flipped: trigger sits left of the deck, flush against its edge
	spawnOccupant(bridge.triggerCentre.x, bridge.rect.y + 1)
	bridge:update(1 / 60)

	assertEqual("opening", bridge.state)
	assertFalse(bridge.deck:isSensor(), "deck should be solid once opening")
	assertEqual(1, #spy.played)
	assertEqual("open", spy.played[1], "the transition into opening plays the open sound")

	spy.uninstall()
end)

test("clearing both zones closes the bridge back down", function()
	local bridge = makeBridge(false)

	local occupant = spawnOccupant(bridge.triggerCentre.x, bridge.rect.y + 1)
	bridge:update(1 / 60)
	assertEqual("opening", bridge.state)

	occupant:destroy()
	local spy = SoundSpy.install()
	bridge:update(1 / 60)

	assertEqual("closing", bridge.state)
	assertTrue(
		bridge.deck:isSensor() == false,
		"deck stays solid through closing -- an occupant here is still a legitimate reason to reopen"
	)
	assertEqual("close", spy.played[1], "the transition into closing plays the close sound")

	spy.uninstall()
end)

test(
	"reopening mid-close and finishing the animation drives a full opening -> open cycle through real Drawbridge:onAnimationFinish",
	function()
		local bridge = makeBridge(false)

		spawnOccupant(bridge.triggerCentre.x, bridge.rect.y + 1)
		bridge:update(1 / 60) -- closed -> opening

		bridge:onAnimationFinish() -- opening -> open (animation reaches the end)
		assertEqual("open", bridge.state)
		assertFalse(bridge.deck:isSensor())
	end
)
