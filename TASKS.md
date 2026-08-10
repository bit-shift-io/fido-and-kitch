# PLAN - Replicator entity (spawn boxes from the roof)

A ceiling-mounted machine that periodically spawns a box (or any entity archetype) that
falls into the room. A `replicator` Tiled object with an `interval` (seconds),
`spawnType` (default `push_box`), optional `maxTotal` capability cap, and `Switchable`
start/stop (a `switch` can toggle spawning). Spawn reuses the proven runtime-spawn path
in `src/entities/cage.lua` (`self.map:loadEntity(spawnType, layer, mockObject)`) —
the same path `GameAPI.spawnEntity` (src/ipc/game_api.lua:363-406) uses. Mock object has
NO `gid` so `PushableSupport.spawnCentre` treats it top-anchored and the box centre lands
exactly at the replicator's position; the spawned collider auto-registers in the bumps
`world` global via `Collider:init`→`world:newCollider`.

Key facts (verified): `EntityFactory:loadEntity` (entity_factory.lua:109-145) constructs
`err(object, self.map)`, sets `entity.mapData`/`object.entity`, and appends to
`layer.entities` (so the spawned box updates/draws/falls immediately). `object.layer` is the
Tiled objectgroup the replicator lives in — spawn into it. `PushableSupport.spawnCentre`
(object without gid → top-anchored: centre = object.y + height*0.5). `Switchable` component
(used by mover_platform) wires start/stop; stop in place means freeze the timer, resume
keeps accumulated time. `Map:loadEntity(entityName, layer, object)` is a passthrough to the
factory (init.lua:195).

Each task touches at most 1-2 files. Run `./test-unit.sh` after logic changes,
`./test-integration.sh` after map/entity behavior changes.

- [ ] 1. Thin template `res/templates/replicator.tx`: object with `type="replicator"`,
  `gid` referencing the default.png tile in props.tsx (gid 11, 32x32), width=32 height=32,
  and tile properties `interval` (float, default 3.0), `spawnType` (string, default
  'push_box'), `enabled` (bool, default true). No new art needed — default.png is fine.
- [ ] 2. New entity `src/entities/replicator.lua` skeleton: `init(object, map)` via
  `Entity.init`; read props `interval` (default 3.0), `spawnType` (default 'push_box'),
  `enabled` (default true), `maxTotal` (optional); store `self.map`, `self.object`,
  `self.spawnLayer = object.layer`, timer accumulator `self.elapsed = 0`, `self.spawned =
  0`; add a Sprite (default.png, 32x32, bottom-anchored via `Rect.centreOfMapObject`) and a
  `Switchable` component wired to run/stop the timer (initially enabled). NO collider
  (it's a ceiling machine; only spawned boxes collide). No spawning yet.
- [ ] 3. Spawn logic in `Replicator:update(dt)`: when enabled, `self.elapsed += dt`; while
  `self.elapsed >= interval` (and under `maxTotal` when set), fire once: build mockObject
  `{type=spawnType, name=spawnType, x=object.x, y=object.y, width=32, height=32,
  properties={}, gid=nil, layer=self.spawnLayer}`, call
  `self.map:loadEntity(self.spawnType, self.spawnLayer, mockObject)`, `self.spawned += 1`,
  `self.elapsed -= interval` (keeps cadence on long frames). When switched off, freeze the
  accumulator (stop in place); on re-enable, resume from the saved elapsed. Expose the pure
  ticks-to-first-fire / cadence math via a `Replicator._internal` white-box seam
  (drawbridge/pressure_switch convention) for unit tests.
- [ ] 4. Add `tests/unit/replicator_test.lua` (headless via
  `tests/support/headless_bootstrap.lua` + a stub `map` recording `loadEntity` calls):
  prop defaults (`interval`/`spawnType`/`enabled`/`maxTotal`), first spawn fires exactly at
  `interval`, cadence stays at `interval` (no drift over long frames), disabled does not
  fire, re-enable resumes from saved elapsed, `maxTotal` stops spawning at the cap, spawned
  mockObject carries the right `type`/`x`/`y`/`width`/`height`/`layer` and nil `gid`.
- [ ] 5. Fixture + integration test: `tests/fixtures/replicator_room.lua` (STI-shaped room
  with a floor, a `replicator` object mounted high in the air above the floor, and a
  `switch` object targeting the replicator) + `tests/integration/replicator_test.lua`
  (GameHarness + FrameStepper): after ~`interval` seconds a `push_box` entity appears in
  the layer and falls to the floor (dynamic body); spawning cadence ≈ interval; switch off
  stops new spawns; switch on resumes. Register in `tests/integration/run.lua`.
- [ ] 6. Demo in `res/map/sandbox.tmx`: add a `replicator` template object (bump
  `nextobjectid`) mounted in the roof above an open floor area where falling boxes are
  visible, plus a `switch` object targeting it; set `interval` so drops are observable.
  Verify with `./run.sh map=sandbox` (boxes drop, can be pushed; switch stops/starts).
- [ ] 7. Docs + final validation: update `AGENTS.md` (new `src/entities/replicator.lua`
  bullet + gotcha: runtime-spawned entities go through `map:loadEntity` into `object.layer`;
  mock objects must be top-anchored — no `gid` — so spawned push-boxes land at the spawn
  point) and `NOTES.md` (replicator decisions section); then `./test-unit.sh` and
  `./test-integration.sh` green and confirm no regression (baselines: unit 463 pass,
  integration 98 pass + 7 known pre-existing failures).