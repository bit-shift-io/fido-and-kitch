# Fix audit findings (AUDIT.md 2026-09-02)

Plan to resolve the issues surfaced in the 2026-09-02 audit. Each task touches
at most 1–2 files so it can be executed and verified independently. Run
`./test-unit.sh` / `./test-integration.sh` after each phase; re-verify
`./test-e2e.sh` after anything touching rendering/physics. Mark items `[x]` as
they land. Task ordering favours the highest-risk items first.

## Phase 1 — Stale cross-references (Medium, low-risk)

Clean 16 dangling references to deleted `.scratch/` planning dirs, `HANDOFF.md`,
and the superseded `NOTES.md 2026-08-24` date.

- [x] All stale `.scratch/`, `HANDOFF.md`, and `NOTES.md 2026-08-24` references
  were already cleaned before this audit. Verified zero remaining matches in
  `src/` and `tests/`. One straggler in `tests/README.md:137` (`.scratch/drawbridge/`)
  was fixed → replaced with `DECISIONS.md Q3/Q4`.

## Phase 2 — Dead code deletion (Medium)

- [x] `src/utils/constants.lua` was already deleted before this audit (verified
  no require references exist). Nothing to do.
- [x] `src/components/pickup.lua:24` — removed commented-out
  `-- utils.instanceOf(entity, Player)`.

## Phase 3 — Extract shared utilities (Medium)

- [x] `formatTime` was already extracted to `src/utils/format.lua` (`Format.time`)
  by a prior session. Both callers (`level_complete_state.lua`, `map_card.lua`)
  already use `Format.time()`. Removed dead `MapCard.formatTime = Format.time`
  export (zero callers).
- [x] `MEDAL_COLORS` deduplicated: extracted to `Format.MEDAL_COLORS` in
  `src/utils/format.lua`. Updated `level_complete_state.lua` and `map_card.lua`
  to use `Format.MEDAL_COLORS` instead of local copies.
- [x] `isHeadless()` extracted to `src/utils/headless.lua` (`Headless.isGraphics()`,
  `Headless.isAudio()`). Updated `sound.lua`, `tint.lua`, `sprite.lua`,
  `laser_beam.lua`. Removed dead local `isHeadless()` in `sprite.lua` (defined
  but never called).
- [x] `OCCUPANCY_HEIGHT_MARGIN` was already extracted to `src/utils/geom.lua`
  (`Geom.OCCUPANCY_HEIGHT_MARGIN`). Both callers already use it. Nothing to do.

## Phase 4 — Named constants (Low)

- [ ] Introduce `TILE_SIZE = 32` constant for the 25+ bare `32` tile-size literals
- [ ] `src/player/player_sensors.lua`, `src/player/ground_support.lua` — extract
  repeated probe/margin literals (`+4`, `-4`, `or 4`, `or 5`) into named constants
- [ ] `src/components/timeline.lua:45`, `src/components/sprite.lua:248` — replace
  bare `1/60` fallback with named `FRAME_DT` constant

## Phase 5 — Minor polish (Low)

- [ ] Remove stale `AGENTS.md:65` list of deleted fx presets (`dust_burst.lua`,
  `spark_trail.lua`) or update to reflect current `src/fx/` presets
- [ ] Update AGENTS.md layout section (currently missing `src/npc/`, `src/ipc/`,
  `src/emitters/`, `src/player/states/`, `src/utils/level_records.lua`)

## Phase 6 — Run full test suite

- [x] Unit tests: 745 passed, 1 failed (pre-existing `ladder.tj frames` mismatch,
  not caused by these changes)
- [x] Integration tests: 209 passed, 4 failed (all pre-existing: conf.debug bake,
  laser mirror bend, destructible tile safe-position)
- [ ] E2E tests: pending (requires headed LÖVE window)
