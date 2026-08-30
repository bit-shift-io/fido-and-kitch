# DECISIONS.md

Consolidated, Q-numbered design decisions for Fido and Kitch. Source files,
tests, tools, and test-support modules reference these by `Q#` in their
comments. This document is the single home for those decisions; it grew out
of the historical per-feature `.scratch/<feature>/DECISIONS.md` planning
files, which are no longer in the repo.

The Q-numbers are grouped loosely by the feature that first asked them; they
form one flat namespace across the codebase.

## Key Assumptions

A few load-bearing assumptions the test stack relies on, referenced as
"DECISIONS.md Key Assumptions":

- **Fixed 1/60s timestep** — harnessed frames advance at a fixed 1/60s, never
  wall-clock (see Q8), so results are deterministic across machines.
- **The `love` stub is an assumption, not a guarantee** — the headless
  `love`/`love.graphics` mock (see Q1/Q5) assumes map loading and entity
  construction only touch a scoped set of love APIs. If a later mechanic
  touches a new love surface, the mock must be extended; this is flagged so
  it is verified against real STI output rather than silently trusted.

## Pushables and physics

- **Q1 — Only pushables clear a teleporter's tile.** A teleporter activates
  only if its tile is blocked by a pushable (and *only* pushables, never
  terrain or another gate) that PushableSupport's checks would let be pushed
  away. `teleport.lua`.
- **Q2 — Clear it like a player pushed it out of the way.** A pushable that
  overlaps the target tile's escape cell is nudged out the same way a player
  would have pushed it, so it visibly slides rather than being deleted.
  `pushable_support.lua`.
- **Q2b — No direction / escape-cell logic at the untouched destination.**
  For a teleporter's own source tile and for a resolved destination, there
  is no player present to push anything out of the way, so any overlap at
  all blocks the teleport — no "which side is it on" resolution.
  `pushable_support.lua`, `teleport.lua`.
- **Q3 — No chain push.** Multiple pushables never push *each other*; only
  the first overlapping prop is ever given the push-to-clear treatment, and
  any second prop (or a wall on the escape side) simply means "can't go
  there". `pushable_support.lua`, `teleport.lua`.
- **Q4 — A shove visibly slides; a snap is an event.** When a player clears
  a prop out of the way, or a prop seats (see Q12), it moves continuously
  rather than teleporting; grid-locking and snap-target alignment happen
  only at explicit forcing events. `pushable.lua`.
- **Q7 — Props are not grid-locked.** A prop shoved along flat ground rests
  at whatever arbitrary x it was left at; it does not align to a tile grid.
  `pushable_test.lua`, `teleport_clear_test.lua`.
- **Q8 — No buoyancy.** Water is cosmetic tiles plus a `kill_zone` sensor;
  a prop crosses a sensor rather than being stopped by it, so a prop shoved
  into water passes through rather than floating. `pushable_test.lua`.
- **Q9 — A boulder is a pushable prop that only ever rests.** On contact it
  stops; it never crushes or shoves the player. It differs from the box only
  in art and Pushable's `mode` (`'box'` vs `'roll'`). `boulder.lua`,
  `pushable_prop.lua`.
- **Q10 — Reset semantics.** A level restart returns every prop and pressure
  switch to its spawn state; a player death changes nothing.
  `pushable_reset_test.lua`.
- **Q11 — "Substantially on it".** For a pressure switch to count a weight
  as standing on it, merely overlapping the plate is not enough — the
  weight's centre-x must be within a tolerance of the plate tile's centre.
  `pressure_switch.lua`, `pressure_switch_test.lua`.
- **Q12 — Seating happens on push-release, never mid-push.** The snap that
  seats a prop onto a plate fires on push-RELEASE so it can never fight the
  player's ongoing input while they are still shoving.
  `pressure_switch_test.lua`.
- **Q14 — Real plate art is out of scope.** The pressure switch uses a flat
  placeholder quad; only props that already had real images keep them.
  `pressure_switch.lua`.

## Drawbridge

- **Q3/Q4 — The old flag-based model could get permanently stuck open.** A
  bridge that is toggled when a trigger tile is entered and retreated from
  before ever reaching the deck can get wedged in the open state. The
  current state-machine model recomputes solidity fresh every frame so it
  can never be stuck. `blocker.lua`, `drawbridge.lua`, `drawbridge_test.lua`,
  `e2e/drawbridge_test.lua`.

## Templates, records, and entities

- **Q5 — Real-file authoring assets resolve at runtime.** A Tiled object's
  template reference resolves its real `.tj`/tileset/image paths at load
  time (`tj_template.lua`), and per-map bests record their own field keyed
  by map filename (`level_records.lua`).
- **Q6 — Template/tileset resolution is silent on missing assets.** Path
  files that reference art are normalised at load; a missing piece is
  handled as an assumption to verify, flagged in Key Assumptions.
- **Q16 — Documented-but-unimplemented entities are not emitted.** Objects
  that exist only in CONTEXT.md's glossary but have no implementation in
  `src/` (e.g. a gradient/cloud spawner) are never emitted by the level
  generator; it lays down only things that actually run.
  `tools/level_generator/decorate.lua`, `tools/level_generator/main.lua`.

## Test infrastructure

- **Q1/Q5 — The headless `love` mock is scoped.** It stubs exactly what map
  loading, entity construction, and the update loop touch; if a later
  mechanic touches a new love surface the mock must grow.
  `tests/support/love_mock.lua`.
- **Q3 — Driving the Slab menu UI is out of scope for tests.** The harness
  boots straight into `InGameState`, skipping `MenuState`/`Slab` entirely
  rather than simulating menu input. `tests/support/game_harness.lua`.
- **Q6/Q13 — Frame capture outside the e2e tier is a loud error, not a
  silent no-op.** Calling `Capture.capture` in the unit/integration tiers
  fails explicitly and names the e2e tier as the requirement.
  `tests/support/capture.lua`, `tests/integration/capture_guard_test.lua`.
- **Q7 — e2e frames are genuinely drawn and presented.** The headed runner
  drives frames from a coroutine inside `love.update` so presentation
  actually happens, rather than a synchronous loop that never renders.
  `tests/e2e/run.lua`.
- **Q8 — Deterministic fixed timestep; filmstrip off by default.** The
  harness advances at a fixed 1/60s (never wall-clock), and e2e filmstrip
  capture is off unless explicitly requested so a normal headed run is not
  buried in images. `tests/support/frame_stepper.lua`, `tests/e2e/run.lua`.
- **Q13 — Fake input never reaches real hardware; three distinct e2e
  outcomes.** Simulated key/gamepad input is injected at the input query
  layer so physical input never reaches an entity (`fake_input.lua`), and an
  e2e scenario has three distinct outcomes (pass / fail / aborted when the
  window was closed mid-run), not two (`e2e/run.lua`).

## Level generator

- **Q12 — The movement model is sourced, not duplicated.** Generator math
  reads player speeds from `src/player/movement_constants.lua` so it can
  never drift from the real player's movement. `movement_model.lua`.
- **Q13 — The exit opens when the objectives are met, with no
  bird/actor_count step.** Once every cage is used the exit opens on its
  own; there is no extra actor-count routing step.
  `tools/level_generator/{plan,walkthrough,main}.lua`,
  `level_generator_objective_spine_test.lua`.
- **Q14 — Optional rule flourishes never gate anything.** Flourishes are
  layered on after required objects, never chain, and difficulty scales how
  many are applied, not chain depth. `rule_set.lua`,
  `rules/{switch_disables_teleport,switch_disables_jump_pad,boulder_weighs_plate}.lua`,
  `level_generator_rules_test.lua`.

## A note on HANDOFF

Some Q-references (e.g. `capture.lua`'s "Key Assumptions / HANDOFF gotcha")
point to the historical per-feature `DECISIONS.md`/`HANDOFF.md` planning
docs from `.scratch/<feature>/`. Those per-feature HANDOFF docs are gone;
the surviving, load-bearing decisions were consolidated here, and
`tools/README.md` records that the `.scratch/procedural-level-generation/`
planning directory is no longer in the repo.
