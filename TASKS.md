# PLAN - Rework Replicator to the confirmed switch-pulse contract (NOTES.md)

A switch-linked gate mechanism embedded flush in a ceiling (usual) or floor: a
32px tile that, **on every press of a linked toggle `Switch`**, emits a
pushable box (default) once. No timer, no interval cadence. Reuse the proven
runtime spawn path `self.map:loadEntity(spawnType, layer, mockObject)` (the
same one `GameAPI.spawnEntity` and `src/entities/cage.lua` drive), with the
mock object top-anchored (NO `gid`) so the spawned prop's centre lands at the
emit point and it falls/settles immediately as a normal physics body.

Confirmed decisions live in `NOTES.md` (2026-08-10 grill). Key contract:
`maxSpawns` budget (default 1, no refunds), spawn fires from every switch
press regardless of the switch's on/off state, emit point from Tiled
`rotation` (0 = ceiling → one tile below the surface; 180 = floor → one tile
above) unless an optional object `polyline` overrides the exact spawn point,
spawned item is sized to the replicator's authored `width`/`height`, and the
spawned prop materialises as an instant solid drop.

Verified grounding:
- `src/entities/replicator.lua` + `tests/unit/replicator_test.lua` +
  `tests/integration/replicator_test.lua` + `tests/fixtures/replicator_room.lua`
  + `res/templates/replicator.tx` ALL implement the old timer design and must
  be reworked (NOTES.md "Rework of the existing code").
- `Switchable` (src/components/switchable.lua) sets `enabled` then fires
  `onStateChange(enabled, switch, user)` on EVERY `switchable:switch(switch,
  user)` call; `Switch:use` (src/entities/switch.lua:38) resolves
  `map:getObjectById(object.properties.target.id)` and calls
  `switchable:switch(self, user)`. The replicator's handler ignores `enabled`
  and spawns on every callback while budget remains.
- `PushableSupport.spawnCentre(object)` (pushable_support.lua:49): no `gid` →
  top-anchored, centre = `object.x + w/2, object.y + h/2`. `pushable_prop.lua`
  sizes sprite+collider from `object.width/height` and starts `dynamic`.
- Polyline points ARE absolute when entities read them: `Tmx.parse` emits raw
  relative points, but `Map:new` feeds the result through `sti(Tmx.parse())`
  and lib/sti/init.lua `setObjectCoordinates` (lines 473-478) adds
  `layer.x + object.x` to every vertex in place (fixture
  `mover_platform_room.lua` path at x=192,y=160 proves it: relative
  `{0,0},{128,0}` re-anchors to deck line y=160). Do NOT add the object origin
  again — same contract as `mover_platform`/`jump_pad` (jump_pad.lua:71).
- `rotation` (degrees) is already parsed by tmx.lua:128 and untouched by STI.
- Emit geometry (bottom-anchored tile object, `object.y` is the bottom edge):
  rotation 0 → machine underside at `object.y`, box top edge one tile below →
  `emitY = object.y + object.height`; rotation 180 → machine top face at
  `object.y - object.height`, box top edge two tiles up → `emitY =
  object.y - 2*object.height`. Unknown rotation treated as ceiling.
  Polyline override: mock `x`/`y` = `object.polyline[1]` directly (absolute).

Each task touches at most 1-2 files. Run `./test-unit.sh` after task 3,
`./test-integration.sh` after task 4. Baselines for no-regression check:
unit 463 pass, integration 98 pass + 7 known pre-existing failures.

- [x] 1. Rework `res/templates/replicator.tx` (1 file): drop `interval` and
  `enabled` properties; keep `spawnType` (string, default 'push_box'); add
  `maxSpawns` (int, default 1); rotate the gid tile so the default template
  reads as a ceiling mount (rotation 0).
- [x] 2. Rework `src/entities/replicator.lua` (1 file): remove the timer
  machinery (`interval`, `elapsed`, `dueSpawns`, `enabled`, `maxTotal`); read
  `spawnType` (default 'push_box') and `maxSpawns` (default 1, clamp to >= 0,
  nil means unlimited); keep the Sprite (default.png, bottom-anchored, no
  collider) and the `Switchable` component, but its `onStateChange` must
  **spawn on every press** (call `self:spawn()` whenever budget remains,
  ignoring the `enabled` value — the switch's on/off state is irrelevant);
  track `self.spawned`; `spawn()` builds a top-anchored mock object (no gid,
  `properties = {}`, `layer = self.spawnLayer`), `type`/`name` = `spawnType`,
  `width`/`height` = the replicator's authored dims, `x` = `object.x`, `y` =
  the rotation- or polyline-derived emit value (rotation 0: `object.y +
  object.height`; rotation 180: `object.y - 2*object.height`; polyline
  present → `object.polyline[1]`), then hands it to `map:loadEntity` and
  increments `self.spawned`. Expose pure emit-y/spawn logic via a
  `Replicator._internal` white-box seam (drawbridge/pressure_switch
  convention) with `DEFAULT_SPAWN_TYPE`, `DEFAULT_MAX_SPAWNS`, and
  `emitY(object)`.
- [x] 3. Rework `tests/unit/replicator_test.lua` (1 file, keep the
  `stubMap`/`makeReplicator` harness): drop all cadence/interval tests;
  add: prop defaults (`spawnType` push_box, `maxSpawns` 1), override props
  (`spawnType` boulder, `maxSpawns` 4), press→spawn (calling
  `switchable:switch({state='on'}, user)` and `{state='off'}` BOTH spawn once
  each — the on/off state is irrelevant), budget capped at `maxSpawns` with
  further presses inert once spent, `emitY` rotation 0 == `y+height` and
  rotation 180 == `y-2*height`, polyline override uses `polyline[1]`
  verbatim/as absolute, and the spawned mock-object contract
  (`type`/`name`, `width`/`height` = authored dims, `layer` = object layer,
  `gid` nil, `properties` empty).
- [x] 4. Rework fixture + integration test (2 files): update
  `tests/fixtures/replicator_room.lua` — a floor, a ceiling-mounted
  `replicator` (rotation 0, high in the air, `spawnType` 'push_box',
  `maxSpawns` 1) and a `switch` object targeting it via `properties.target =
  {id = ...}`; update `tests/integration/replicator_test.lua` (already
  registered in `tests/integration/run.lua:40`) — a `switch:use(player)`
  immediately spawns one push_box that falls and lands on the floor (dynamic
  body), a second `switch:use` spawns nothing (budget spent) and further
  presses stay inert; assert spawned box geometry (lands at the floor).
- [x] 5. Demo in `res/map/sandbox.tmx` (1 file): add a `replicator` template
  object (bump `nextobjectid`) embedded flush in the roof above a clear floor
  area where a falling box is observable, `maxSpawns` set to a visible number,
  plus a `switch` object targeting it; verified via a temporary integration
  check through the real stack — a `replicator_switch` press spawns a new
  push_box that falls onto the floor below. (`./run.sh map=sandbox` analog.)
  Task note: the demo was placed floating in the air (not literally embedded
  in a roof) per the user's simplification request.
- [x] 6. Docs + final validation (2 files): add a `replicator` bullet to
  `AGENTS.md` (switch-pulse contract — every switch press spawns once until
  `maxSpawns` is spent; emit point from rotation 0/180 or polyline; mock
  objects top-anchored, no gid; polyline points are absolute post-STI, do not
  re-add the origin) and confirm `NOTES.md` captures the design; then
  `./test-unit.sh` and `./test-integration.sh` green with no regression
  (unit 481 pass / 0 fail, integration 100 pass + 7 known pre-existing
  failures).