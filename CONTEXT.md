# Glossary

## Kill zone

**Definition** — A designer-placed invisible volume, drawn as a rectangle on a Tiled object layer, that kills any player who touches it. Each kill zone carries a death type.

**Boundary** — Kill zones are gameplay volumes decoupled from visual tile layers (the drawn water is not the kill zone). They are instantly fatal; they are not damage sources, slow hazards, or per-tile collision.

## Death type

**Definition** — A string property on a kill zone (e.g. `water`) naming the kind of death it causes, carried through the kill event so death presentation can vary per hazard later.

**Boundary** — Currently informational only; all deaths share one presentation. It is not a damage category or physics behaviour.

## Lives pool

**Definition** — The shared count of remaining deaths for all players in a level, shown as a row of hearts top-left. Starts at the default (2) on every level load. A death while the pool is at zero triggers game over.

**Boundary** — Shared between players and scoped to a single level load; it is never per-player and never persists across levels or restarts.

## Last safe position

**Definition** — A player's most recent position recorded after being continuously grounded for a stability threshold; where that player respawns on death.

**Boundary** — Per player, and only updated on stable ground (not mid-air, not the instant of touching ground). It is not a checkpoint system and is not shared between players.

## Fast gameplay regression test

**Definition** — A headless Lua test that checks gameplay decisions or math quickly without launching a graphical LÖVE game.

**Boundary** — These tests are for fast feedback on logic regressions. They are not visual tests, full map-loading tests, or packaging tests.

## Testability seam

**Definition** — A small extracted function or module that lets existing behavior be tested without broad runtime mocks.

**Boundary** — A seam should preserve runtime behavior and stay narrowly focused. It is not a broad refactor away from the project's current global-oriented architecture.
