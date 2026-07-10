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

## Background prop

**Definition** — A decorative entity (tree, bush, cloud) spawned from a tile object in a map's `background` objectgroup layer, placed in Tiled via a template backed by the `props` image-collection tileset so the real art shows in the editor. May move (procedurally and/or via frame animation) and react to nearby players.

**Boundary** — Pure visuals: never has a physics collider and never obstructs or affects player movement. Not a gameplay volume (contrast with kill zone) and not a foreground/overlay element.

## Gradient object

**Definition** — A rect object of type `gradient` in the background layer carrying `colorTop`/`colorBottom` colours and a `coverMap` flag; the game draws a vertical colour gradient behind everything (full-map when `coverMap` is set).

**Boundary** — Data authored in the map, rendered in code; Tiled cannot preview it. It is the backmost visual only, not lighting or tinting of other layers.

## Cloud spawner

**Definition** — A rect object of type `cloud_spawner` that, at level load, populates its region with a fixed count of clouds picked from a pool of Tiled templates; clouds drift with the wind and wrap around the map edges.

**Boundary** — Seeds a stable population once; it does not continuously spawn/despawn and is not a weather system.

## Wind

**Definition** — A global per-map value (map custom property `windX`, signed direction+strength, with a code default when absent) that drives background motion — cloud drift and prop sway — scaled per object by a `windScale` multiplier.

**Boundary** — Affects background visuals only; it never applies forces to players or gameplay entities.

## Depth

**Definition** — A number carried by every background element (default 1.0) reserved as its parallax factor for the planned camera rework.

**Boundary** — Stored and plumbed but currently visually inert; it does not control draw order (layer/object order does).

## Proximity component

**Definition** — A generic entity component configured with a radius that watches player distance each update and emits enter/exit signals, letting the owning entity react (e.g. a bush rustles when a player runs past).

**Boundary** — Read-only detection; it creates no collider and applies no gameplay effect itself — reactions belong to the owning entity.
