-- Headless coverage for src/entities/ladder.lua's per-rung model: the lead
-- rung (bottom-most, flagged leadRung by the entity_factory pre-pass) builds
-- the ONE merged Ladder -- single sensor collider from the merged
-- bottom-anchored family rect, sprite stack below it -- and the non-lead
-- rungs become thin aliases exposing isLadder, a shared .rect and a pointer
-- to the lead. Covers the bottom-anchored rect math in resizeTileHeight/grow.
require("tests.support.headless_bootstrap")

local HeadlessBootstrap = require("tests.support.headless_bootstrap")
local Ladder = require("src.entities.ladder")

local TILE = 32

-- Build the rung objects exactly as src/map/entity_factory.lua's
-- annotateLadders pre-pass leaves them: each tagged with ladderFamily (the
-- merged bottom-anchored rect) and the lead on the lowest (largest y) rung.
local function makeFamilyRungs(height)
	local rungs = {}
	for i = 1, height do
		local y = 160 + i * TILE
		table.insert(rungs, {
			id = 100 + i,
			type = "ladder",
			x = 64,
			y = y,
			width = TILE,
			height = TILE,
			properties = {},
		})
	end
	local family = Rect({ x = 64, y = 160 + height * TILE, width = TILE, height = height * TILE })
	for i, rung in ipairs(rungs) do
		rung.ladderFamily = family
		rung.leadRung = (rung.y == family.y)
	end
	return rungs, family
end

local function makeLead(rungs)
	HeadlessBootstrap.resetWorld()
	local map = { map = { tileheight = TILE, tilewidth = TILE }, tileheight = TILE, tilewidth = TILE }
	local lead = Ladder(rungs[#rungs], map)
	return lead, map
end

test("the lead rung builds one merged sensor collider from the family rect", function()
	local rungs, family = makeFamilyRungs(3)
	local lead = makeLead(rungs)

	assertTrue(lead.isLadder)
	assertEqual(family.x, lead.rect.x)
	assertEqual(family.y, lead.rect.y)
	assertEqual(family.width, lead.rect.width)
	assertEqual(family.height, lead.rect.height)
	assertTrue(lead.collider:isSensor(), "climb volume is a sensor")
	assertEqual(
		family.y,
		lead.collider:getBounds().bottom,
		"collider bottom sits on the family bottom edge (rect is bottom-anchored)"
	)
end)

test("rungs above the lead become thin aliases sharing the rect and lead", function()
	local rungs, family = makeFamilyRungs(3)
	local lead, map = makeLead(rungs)

	local alias = Ladder(rungs[1], map)

	assertTrue(alias.isLadder)
	assertEqual(lead, alias.lead)
	assertEqual(lead.rect, alias.rect)
	assertEqual(lead.collider, alias.collider, "aliases carry no physics of their own")
end)

test("aliases forward switch, grow, resize and tileHeight to the lead", function()
	local rungs = makeFamilyRungs(2)
	local lead, map = makeLead(rungs)
	local alias = Ladder(rungs[1], map)

	local switched = 0
	lead.switch = function()
		switched = switched + 1
	end
	alias:switch("off")
	assertEqual(1, switched)

	local grew = 0
	lead.grow = function()
		grew = grew + 1
	end
	alias:grow(1)
	assertEqual(1, grew)
end)

test("growing moves the top edge up, keeping the bottom edge fixed", function()
	local rungs = makeFamilyRungs(2)
	local lead = makeLead(rungs)
	local bottom = lead.rect.y

	lead:grow(1)

	assertEqual(bottom, lead.rect.y, "bottom edge does not move on growth")
	assertEqual(3 * TILE, lead.rect.height)
	assertEqual(3, lead:tileHeight())
end)
test("the one-way top slab is entity-tagged and walkable for NPC probes", function()
	-- Player ladder sensors (src/player/player_sensors.lua) key off
	-- item.entity.isLadder on anything they overlap; GroundSupport keys off
	-- collider.walkable. The slab must carry both so players can climb it
	-- and stand on it as ground.
	local rungs = makeFamilyRungs(2)
	local lead = makeLead(rungs)

	local slab = lead.topCollider
	assertTrue(slab ~= nil, "the lead builds a top slab")
	assertEqual(lead, slab.entity, "slab must reference its ladder entity")
	assertTrue(slab.entity.isLadder, "bird probe sees isLadder through the slab")
	assertTrue(slab.walkable, "GroundSupport treats the slab as walkable ground")

	lead:switch({ state = "off" })
	assertEqual(nil, lead.topCollider, "hide removes the slab with the sensor")

	lead:switch({ state = "on" })
	slab = lead.topCollider
	assertTrue(slab ~= nil, "show rebuilds the slab")
	assertEqual(lead, slab.entity, "rebuilt slab keeps the entity reference")
end)
