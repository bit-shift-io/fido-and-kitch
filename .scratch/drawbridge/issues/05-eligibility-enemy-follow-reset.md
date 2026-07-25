Status: done

# Configurable eligibility, enemy-follow-across, reset on restart

## What to build

A designer can set *who* may open a drawbridge via a Tiled property — players only by default, with an opt-in to also allow enemies. Eligibility gates opening only: once a player has opened the bridge, the deck is solid to everyone, so a second player and a chasing enemy can both follow across from either direction. Every drawbridge resets to its closed spawn state on level restart (matching the pushable-props reset model); an individual player's death/respawn does not force it closed. A full integration test exercises the mechanic end-to-end on the fixture map.

## Files to create/modify

- src/entities/drawbridge.lua — read the eligibility property (default players-only) and apply it in the trigger check; add spawn-state capture + reset-on-restart hook
- res/templates/drawbridge.tx — add the eligibility property
- res/map/<fixture>.lua — ensure the fixture supports the integration scenario (two spawns, an enemy) or add a dedicated fixture
- tests/drawbridge_test.lua — extend (eligibility matrix, reset)
- tests/<drawbridge integration test> — new, per the project's integration-test convention (loads the real Game/Map/Player stack, drives simulated input)

## Test approach

- Eligibility matrix helper: (entity type ∈ {player, enemy}) × (config ∈ {players-only, players+enemies}) × (side) → may-open decision.
- Reset: after a simulated restart the bridge is closed regardless of prior state; after a single player's death/respawn the bridge state is governed by occupancy, not forced closed.
- Integration test: eligible player crosses from the correct side; wrong-side player is blocked; a second entity crosses while the first holds it open; the bridge closes after the last leaves; an enemy follows across an open bridge.

## Acceptance criteria

- [x] Eligibility property gates opening; defaults to players only. (`allowEnemies` on the Tiled template, already plumbed in slice 03; verified end-to-end here)
- [x] With the enemy opt-in, an enemy can open the bridge from the correct side.
- [x] Once open, a second player and an enemy can both cross from either direction. (real P2 + a synthetic enemy collider, see notes)
- [x] Every drawbridge resets to closed on level restart.
- [x] A player death/respawn does not force the bridge closed. (true by construction — see notes; not a dedicated runtime test)
- [x] Integration test passes end-to-end on the fixture map.

## Blocked by

04 (needs the full open/close lifecycle before layering eligibility, enemy-follow, and reset on top).

## Implementation notes

- **No enemy entity class exists in this project yet.** Eligibility and occupancy only ever look at `collider.entity.type`, so `tests/integration/drawbridge_test.lua` stands a bare dynamic `Collider` in for one (`{type = 'enemy'}`), mirroring the fake-collider convention already used by `tests/unit/kill_zone_test.lua`. When a real enemy entity lands, it just needs to set `.type = 'enemy'` on itself (matching `Player`'s own `.type = 'player'`) and this all keeps working unmodified.
- **Three real physics gotchas surfaced building the integration test for this slice** — all now documented in `tests/README.md`'s new "Physics gotchas when constructing a bare test Collider directly" section: `groupIndex` defaulting to `nil` (and `nil == nil` being `true` in Lua) silently makes any two ungrouped colliders ignore each other; a one-shot `setLinearVelocity` doesn't survive a stray collision the way a real player's continuously-redriven input does; and an exact-integer px/s speed at the fixed 1/60s timestep can land exactly on a tile boundary and trip a genuine `lib/bump` edge case. None of these are drawbridge bugs — they're landmines for anyone next writing a headless test that moves a bare collider around, so they're documented for reuse rather than fixed in the shared physics code (out of scope here, and risky to change without dedicated justification/testing).
- **Reset-on-restart** needed no new code: `GameOverState:activate('restart')` → `InGameState:load` rebuilds `World`/`Map` from scratch (see `HANDOFF.md`), so every entity — the drawbridge included — is a fresh instance starting from `Drawbridge:init`'s `self.state = 'closed'`. `tests/integration/drawbridge_test.lua` proves this (force a bridge open, restart, assert the freshly-found bridge entity is closed and is a different Lua object).
- **Player death/respawn not forcing the bridge closed** is true by construction (`Drawbridge` never subscribes to any player's `deathSignal`, and occupancy is the only thing that ever closes it) rather than a covered runtime scenario — orchestrating a meaningful, non-flaky test for it (distinguishing "death didn't force it closed" from "occupancy naturally closed it because the dying player left") would need a second occupant kept on the deck throughout, real kill-zone-triggered death timing, and real respawn timing, for low incremental confidence over just reading the code. Documented here as a deliberate scope decision, matching the "reset" investigation's own precedent.
- The two-player crossing test (`tests/e2e/drawbridge_test.lua`) uses the fixture's real P1 and P2 (both spawned by its lone spawn point) rather than a synthetic collider, since eligibility is players-only by default and this is exactly the scenario a real designer would hit.
