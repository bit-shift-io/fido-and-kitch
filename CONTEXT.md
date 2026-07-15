# Glossary

## Auto-zoom camera

**Definition** — The single shared camera that automatically frames all framing targets: zooming in when players are close (never below a 5×5-tile view), out as they spread (up to the full-map view), with smooth frame-rate-independent easing on pan and zoom, always clamped to map bounds.

**Boundary** — One camera for one shared screen; it is not split-screen, not per-player, and does not render parallax (it only exposes the centre/zoom parallax will need). HUD and menus live outside its transform.

## Framing target

**Definition** — Anything the auto-zoom camera must keep in view: each alive player's bounds, plus transient extras such as a dying player's respawn position while the death sequence plays.

**Boundary** — A camera input only; being a framing target has no gameplay effect. Targets are world-space rects, not entities the camera owns.

## Overview toggle

**Definition** — A player-triggered camera mode (spacebar or gamepad Back/Select) that smoothly zooms out to the full-map view for route planning and back again on a second press, while gameplay keeps running.

**Boundary** — A camera mode, not a pause, menu, or minimap; it never stops the simulation.

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

## Pushable

**Definition** — A shared entity component giving a prop the ability to be shoved horizontally by a grounded player walking into it. Handles slide-while-pushed (push box) and momentum-roll-after-a-shove (boulder), the "can this move right now?" gating (grounded pusher holding a direction, nothing pushable on top, no player on top unless opted in, not airborne), and the deterministic fall-and-snap into holes.

**Boundary** — Horizontal only; never lifts or pushes props down. It is the behaviour, not the prop — `push_box` and `boulder` are separate entities that both use it. It does not damage players and does not affect entities other than players and other pushables.

## Push box

**Definition** — A pushable prop (placeholder 32×32 quad) that slides at the player's walk speed only while a grounded player actively pushes into it, stopping the instant they stop or turn away. Falls straight down and snaps to fill a one-tile hole; acts as solid, standable ground.

**Boundary** — Not grid-locked: it rests at arbitrary x and only aligns to a tile on the two forcing events (falling, seating on a pressure switch). Blocked by walls and other pushables; you cannot push a train of two props at once.

## Boulder

**Definition** — A pushable prop that starts moving the same way a push box does (a grounded player walks into it) but keeps rolling on its own at walk speed after contact ends, until it hits a wall, another pushable, or a player, or falls into a gap (snapping like a box). Pushable again once stopped, if there's room.

**Boundary** — Harmless: it never hurts or crushes players or shoves them along — it just stops. Same 32×32 placeholder quad (grey), same fall/snap model as the push box.

## Pressure switch

**Definition** — A weight-activated single-tile plate that turns on while a qualifying weight (a player or a pushable) is substantially on it — its centre-x within a small tolerance of the plate tile's centre — and drives a target entity through the same `target` + `:switch()` mechanism the lever switch uses. Momentary by default (re-drives the target when the last weight leaves); a latching option keeps it on after first activation.

**Boundary** — Distinct from the user-triggered lever `switch` (which the player actively "uses"): a pressure switch reacts to weight/presence, not a button press. Activated by presence only; it applies no force and does not itself move props.

## Ladder mount alignment

**Definition** — When a player presses up/down to mount a ladder off-centre, the horizontal slide that moves them onto the ladder's centre-x before vertical climbing begins. The initial mount from the ground slides at walk speed; re-aligning after an on-ladder slide uses the slower slide speed. Alignment finishes exactly on centre-x.

**Boundary** — Purely a horizontal on-ramp to climbing; it does not move the player vertically. It targets the nearest overlapping ladder's centre. Not a snap — it is a visible slide.

## Ladder slide

**Definition** — Holding left/right while on a ladder to shuffle sideways at a slow, deliberate speed. Sliding can carry the player off a ladder edge, and onto a touching ladder. The player falls (enters FallState) only when the collider fully clears every ladder.

**Boundary** — Horizontal only and gravity stays off while any ladder is under the player. Distinct from ground walking (slower, on a ladder). It never causes a fall while any part of the body still overlaps a ladder.

## Ladder mode

**Definition** — The internal sub-state of `LadderState`: `aligning` (sliding to a ladder centre), `climbing` (centred, moving up/down), or `sliding` (moving sideways). Which mode is active is decided by last-pressed-axis-wins arbitration between the vertical and horizontal keys.

**Boundary** — An implementation-level state inside the single `LadderState`, not a top-level player FSM state. Only meaningful while on a ladder.

## Enemy

**Definition** — A Tiled-placed mobile entity (spider, robot) that hinders players by chasing the nearest valid (alive, unwrapped, un-banned) player at ~70% player speed under player-like physics, navigating by axis alignment: walk to close the X gap, and climb a ladder it already overlaps to close the Y gap. Wanders near its current position when no valid target exists.

**Boundary** — A hindrance, never a direct killer: enemies cost time and control, not lives. Non-solid to players (overlap-based effects), solid to the world. No pathfinding — ladder use is strictly opportunistic. Invincible except for the head stomp.

## Harassment ban

**Definition** — A per-enemy, per-player cooldown (~30s) that starts once an enemy has successfully harassed a player — the spider on landing a wrap, the robot after ~10s of chasing the same target — during which that enemy may not target that player.

**Boundary** — Scoped to the individual enemy instance, not global: another enemy may still target the banned-for player. It gates targeting only; it does not make the player immune to incidental contact effects from other enemies.

## Web wrap

**Definition** — The spider's catch: on overlapping its target, the player is frozen in place (~20s) under a web visual that fades out near expiry, then control returns. The wrapped player ignores input, settles under gravity, stays a camera framing target, can still be killed by kill zones, and cannot be shoved by the robot.

**Boundary** — A timed lockout, not a death or damage: it never costs lives by itself and has no escape mechanic (no struggling, no teammate rescue). The web is a runtime visual entity, never placed in Tiled.

## Head stomp

**Definition** — A player landing on an enemy from above stuns it for ~10s (frozen, visually indicated) and bounces the player upward. The players' only counterplay against enemies.

**Boundary** — A stun, not a kill — enemies cannot be destroyed. Detected geometrically (falling player overlapping from above), since enemies are not solid to players. Does not start a harassment ban.

## Snap alignment

**Definition** — The deterministic forcing of a pushable's x to a tile's centre. Occurs only on two events: the prop's centre-x passing over an unsupported tile (it snaps and falls straight in) and a prop coming to rest on a pressure switch (it snaps on push-release when within tolerance). See ADR 0001.

**Boundary** — Not the normal resting behaviour: props otherwise rest at whatever x they were left at, and the player can push a prop back out of a snapped position.
