Status: done

# Kill zones in the map, detected by the player

## What to build

The sandbox level gains invisible kill-zone volumes over the water, and the game knows the moment a player touches one. After this slice, running the sandbox map and walking a player into the water fires a visible debug print naming the player and the death type (`water`). Nothing kills the player yet — this slice is the hazard sensing layer end-to-end (Tiled data → entity → player query).

## Files to create/modify

- `res/map/sandbox.tmx` — add a new objectgroup (map header currently has `nextlayerid="19"`, `nextobjectid="78"` — bump both). Give the layer a name like `kill`, and add one or more rectangle objects with `type="kill_zone"` covering the water at the bottom of the map, positioned so the player can sink partway into the visible water before overlapping. Each object gets a string property `deathType` = `water`. Follow the existing objectgroup patterns in the file (`ladder` layer at line ~30, `collision` layer at line ~112).
- `res/map/sandbox.lua` — the game loads this Lua export, not the tmx (see `InGameState:load`, which defaults to `res/map/sandbox.lua`). Re-export from Tiled if available, otherwise hand-edit the Lua to mirror the tmx change, following the structure of the existing objectgroup entries.
- `src/entities/kill_zone.lua` — new entity, modelled directly on `src/entities/ladder.lua`: `Entity`-based, static sensor `Collider` from the object rect, `self.isKillZone = true`, `self.deathType = object.properties.deathType or 'unknown'`. No sprites. Object type `kill_zone` is auto-loaded by `Map:createEntitiesFromObjectGroupLayers` → `Map:loadEntity` (search path `src.entities.`), so no map.lua changes should be needed.
- `src/player/player.lua` — add `Player:queryKillZone()`, modelled on `Player:queryLadder()` (`world:queryBounds` over the collider bounds, return the entity with `isKillZone`, else nil). Call it from `Player:update` for now and print when it returns a zone (temporary until issue 04 consumes it).

## Test approach

Manual: run `./run.sh` (sandbox map), enable `conf.drawphysics` if helpful to see the sensor volume, walk/fall a player into the water, observe the debug print with the correct `deathType`. Verify the other player triggers it independently, and that standing next to (not in) the water does not trigger. Headless tests: none for this slice — it is world-query plumbing; the decision logic gets its seams in later slices.

## Acceptance criteria

- [ ] sandbox.tmx and sandbox.lua both contain the kill objectgroup with `deathType="water"` rectangles over the water
- [ ] A player overlapping a kill zone is detected every frame (debug print), with the zone's death type available
- [ ] The kill volume is positioned so a player visibly sinks into the water before detection fires
- [ ] Ladders, teleports, and existing map entities still load and behave normally

## Blocked by

None — can start immediately.
