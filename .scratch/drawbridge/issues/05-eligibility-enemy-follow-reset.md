Status: pending

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

- [ ] Eligibility property gates opening; defaults to players only.
- [ ] With the enemy opt-in, an enemy can open the bridge from the correct side.
- [ ] Once open, a second player and an enemy can both cross from either direction.
- [ ] Every drawbridge resets to closed on level restart.
- [ ] A player death/respawn does not force the bridge closed.
- [ ] Integration test passes end-to-end on the fixture map.

## Blocked by

04 (needs the full open/close lifecycle before layering eligibility, enemy-follow, and reset on top).
