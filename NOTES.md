# Fido and Kitch — Movable Platform Feature: Confirmed Requirements

Grill notes (2026-08-10). Feature: a rideable moving platform entity that
travels along a path defined in Tiled and carries standing players with it.

## Related code (grounding)

- `res/img/entity_mover_platform.png` — platform art already exists (never
  wired up). `generic_platformer_tiles.png` also available.
- `src/npc/npc_base.lua:398` — NPCs already anticipate `isMovingPlatform`
  (reads `other.collider:getLinearVelocity()`); `ridePlatforms` config flag
  in `npc_config.lua` (default false; rabbit is the only `true`).
  This is pre-wired but nothing sets `isMovingPlatform` yet.
- `src/components/path.lua` — `Path{polyline=...}` from a Tiled polyline
  object; `getPositionV(percent)` is `love.math.newBezierCurve:evaluate` —
  **a bezier**. For linear point-to-point motion we must NOT use
  `Path:getPositionV`; do own per-segment constant-speed interpolation.
- `src/components/path_follow.lua` — drives a sprite/collider via
  `duration = path.length / speed`, advancing `timePercent`; finishes and
  restores gravity/velocity. One-shot; bezier-based; used by
  `jump_pad.lua:75` on the *player* (offset from path start).
- `src/components/timeline.lua` — supports `loop`, `bounce`, `hold`,
  `events`, `finish` signal. Candidate for motion driver but position is not
  linear under its `timePercent`; likely hand-rolled segment stepping is
  cleaner.
- `src/components/switchable.lua` — `switchable:switch(switch, user)` +
  `onStateChange`; drawbridge uses a `Switchable` with `latchedOpen`
  (`drawbridge.lua:204`), default enabled = true. Switch resolves target via
  `map:getObjectById(object.properties.target.id)` (`switch.lua:38`).
- Ground detection is **boolean-only**: `PlayerSensors.queryOnGround`,
  `GroundSupport.hasGroundAt`/`isFullySupported` return true/false — no
  "which collider" answer. Delta-carry detection must be done by the
  platform itself (own-collider overlap vs. each player, or per-player ground
  probes against platform bounds), not by reading queryOnGround's result.
- No one-way platform exists anywhere yet. Drawbridge is a solid walkable
  deck (`collider.walkable = true`, `sensor` toggles only for open/closed);
  bump has no native directional one-way collision. One-way top-only needs a
  mechanism (e.g. solid only when the player's feet are above the top edge).
- `walkable = true` on the platform's collider is REQUIRED or standing
  players get stuck in FallState (drawbridge gotcha).
- Entity naming: Tiled object `type` maps to `src/entities/<type>.lua`.
  Art is named `entity_mover_platform.png`; NPCBase checks `isMovingPlatform`.
  Artwork/template conventions from `res/templates/*.tx`.

## Confirmed decisions (asked + answered)

1. **Core semantics**: "Rideable moving platform" — travels a path; a
   standing player is carried along. Classic puzzle lift.
2. **Motion model**: "Freeform path following" — flexible path, configurable
   end behavior + pauses.
3. **End-of-path behavior**: user-configurable **`endBehavior` = 'pingpong'
   | 'loop'** (default **'pingpong'**). Plus pauses at certain points.
4. **Carry mechanic**: "Delta-carry standing riders" — platform translates a
   standing player by exactly its own per-frame move delta (smooth, no
   slip). Player can walk off / free-will ends the ride.
5. **Collision**: "One-way top-only" — land on top; jump up through from
   below; pass through from the sides.
6. **Tiled authoring**: `path` property referencing a polyline object
   (exact jump_pad convention) + custom props on the platform object
   (`speed`, `endBehavior`, `pause`). The polyline is the **deck line** —
   the platform hangs half its height below it (top riding surface rides
   exactly on the drawn line), so an author draws the path along floor
   heights with no half-height mental math.
7. **Pauses**: single `pause` custom property (seconds) applies at EVERY
   path point including both ends.
8. **Carry scope**: players only (P1/P2). Boxes/boulders/physics props just
   collide normally (slide or stop). NPCs not carried (pre-wired
   `ridePlatforms` NPC path is out of scope unless trivial).
9. **Activation**: always-on once running (default enabled) + switch
   start/stop via `Switchable` (drawbridge latched pattern).
10. **Interpolation**: LINEAR point-to-point at constant pixel speed, turning
    at each corner — NOT the bezier in `Path:getPositionV`/PathFollow.
11. **Blockage**: clip through everything — moves linearly regardless of
    terrain/entities in the way; level designer keeps the route clear
    (matches "map code is trusted" posture).
12. **Config props**: `speed` (px/sec — reference: jump_pad uses 400; pick a
    sensible default, e.g. 100) and `endBehavior` ('pingpong' default |
    'loop'), plus `pause` (default 0).

## Open / deferred

All planning items are now **settled and implemented** (`type=mover_platform`,
one-way via per-collider `colFilterFn`, carry via platform-own overlap probe,
switch start/stop with stop-in-place + resume). Remaining out of scope:

- **NPC `ridePlatforms`/`isMovingPlatform`**: pre-wired in NPCBase but never
  activated by the platform (no NPC get carried; they collide solidly).
- **Loading note (implemented)**: STI re-anchors a polyline object's points
  in place on map load (lib/sti/init.lua convertObjectShapesToPolygons adds
  the object's x/y to every vertex), so the points a From-Game entity
  resolves off `map:getObjectById` are already **absolute** — jump_pad's
  `use` of `polyline[1]` as an absolute launch origin relies on this same
  contract. New code resolving paths must not re-add the object origin.

## Risks / gotchas for implementation

- **Bezier vs linear**: reusing `Path:getPositionV` or `PathFollow` gives
  curved, non-constant-speed motion — violates decision 10. Write own
  per-segment speed-based stepper.
- **Discrete AABB (bump)**: fast platforms can tunnel a rider on a single
  frame's delta; keep speeds moderate or apply carry before physics step.
- **One-way framing**: without a mechanism, "one-way top-only" degenerates
  into a full solid box (side/under block) or a sensor (no standing).
- **`walkable = true` mandatory**: else riders stick in FallState.
- Static-body manual moves: set position directly each frame; do not rely on
  bump impulses for the platform itself.

## Who reads this

Target implementation against a new `src/entities/<type>.lua`, the
`Switchable` component, Tiled `.tmx` polyline objects, and the existing
`collider.walkable` ground system. Run `./test-unit.sh` +
`./test-integration.sh`; add unit tests alongside.