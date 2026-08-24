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

**Definition** — A designer-placed invisible volume, drawn as a rectangle on a Tiled object layer, that kills any player or enemy who touches it. Each kill zone carries a death type.

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

## Integration test

**Definition** — A headless Lua test that loads a real (usually small, dedicated fixture) map through the actual `Game`/`InGameState`/`Map`/`Player` stack, drives simulated keyboard or joystick input across many stepped frames the way a human would, and asserts on resulting gameplay state. Runs outside the real LÖVE runtime via a minimal `love.*` mock, through its own command.

**Boundary** — The middle of three test tiers (unit, integration, e2e), and the headless one. Distinct from a fast gameplay regression test: that category deliberately avoids loading maps or the LÖVE surface; integration tests deliberately load real maps and simulate real input. Not a visual/rendering test (`love.graphics` calls are no-ops, and frame capture is unavailable) and not a menu/UI-navigation test (tests start directly in `InGameState`, skipping `MenuState`/Slab). A test needing real rendering is a headed test instead.

## Headed test

**Definition** — An end-to-end test that runs the same kind of scripted, deterministic scenario an integration test does — same simulated input, same fixed timestep, same gameplay assertions — but under the real LÖVE runtime with a real window and real rendering, so it can be watched while it runs and can capture frames to disk. Advances as fast as it can by default, with a flag to pace it to real time for watchable playback.

**Boundary** — The outermost of the three test tiers, and the only one where frame capture works. A test belongs to exactly one tier: there is no running the same file both headless and headed, so a scenario asserting only gameplay state stays an integration test. Gameplay input is scripted and real physical input is ignored, so it is not a manual playtest. Closing the window reports the run as cancelled, not failed.

## Frame capture

**Definition** — A still image of a rendered frame written to disk by a headed test, as evidence a human or an AI agent can read afterward without having been present when the test ran. Triggered three ways, freely combined: an explicit named capture from scenario code, an automatic capture at the point an assertion fails, and an optional every-Nth-frame filmstrip whose interval is configurable and which is off by default.

**Boundary** — A debugging artifact, not a baseline: captures are gitignored and never compared against committed reference images, so this is not visual regression testing. Still images only, not video. Unavailable in the headless tier, where attempting a capture is a loud error rather than a silent no-op.

## Fixture map

**Definition** — A small, dedicated Tiled-style map authored specifically for integration tests — e.g. a flat ground room, a room with one pressure switch — kept minimal and shared across tests where its layout fits. Hand-authored `.lua` STI-shaped maps are used as fixtures (maintained without a Tiled round-trip); their ladder objects follow the same per-rung, bottom-anchored format as `.tmx` maps.

**Boundary** — Not a real playable level; it is never shipped or referenced from `res/map/`. Distinct from the separate "load every real map" smoke test, which exercises actual shipped levels instead of fixtures.

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

**Boundary** — Horizontal only and gravity stays off while any ladder is under the player. Distinct from ground walking (slower, on a ladder). Within the last half-tile below the top a side press finishes the climb to the top hover, then continues across (a platform is likely adjacent there); deeper below the top, a side press slides off the side and falls — a normal dismount. Leaving sideways also happens from the exact-top hover; arriving at the bottom dismounts onto the platform. Releasing mid-slide holds position. Only a fresh directional press slides — a direction already held when the player caught or mounted the ladder is ignored until re-pressed or released, so walking/falling into a ladder while steering doesn't immediately carry you back out of it.

## Ladder mode

**Definition** — The internal sub-state of `LadderState`: `aligning` (sliding to a ladder centre), `climbing` (centred, moving up/down), or `sliding` (moving sideways). Which mode is active is decided by last-pressed-axis-wins arbitration between the vertical and horizontal keys.

**Boundary** — An implementation-level state inside the single `LadderState`, not a top-level player FSM state. Only meaningful while on a ladder.

## Ladder no-gravity zone

**Definition** — A merged ladder's collider acts as a zero-gravity climbable volume instead of a catcher of falls: a player inside it hangs in place when input is neutral (gravity suspended), climbs with up/down, slides with left/right, and leaves only by climbing/walking out or by a switched-off toggle removing the volume under them. The ladder's top edge carries a thin one-way standable slab, so a player falling onto the bare top lands standing on it (and can walk onto flush adjacent terrain); pressing down on the top descends into the zone below.

**Boundary** — Players-only affordances: props and NPCs pass through both the volume and the top slab (enemies still climb opportunistically via their own AI). Terrain tiles under/around a ladder top are optional for support — the slab is the floor. A switched-off ladder provides neither the zone nor the slab.

## Enemy

**Definition** — A Tiled-placed mobile entity (spider, robot) that hinders players by chasing the nearest valid (alive, unwrapped, un-banned) player at ~70% player speed under player-like physics, navigating by axis alignment: walk to close the X gap, and climb a ladder it already overlaps to close the Y gap. Wanders near its current position when no valid target exists.

**Boundary** — A hindrance, never a direct killer of players: enemies cost time and control, not lives. Non-solid to players (overlap-based effects), solid to the world. No pathfinding — ladder use is strictly opportunistic. Immune to permanent harm except a kill zone, which kills it the same way it kills a player (see [[Enemy death and respawn]]); the head stomp only stuns.

## Harassment ban

**Definition** — A per-enemy, per-player cooldown (~30s) that starts once an enemy has successfully harassed a player — the spider on landing a wrap, the robot after ~10s of chasing the same target — during which that enemy may not target that player.

**Boundary** — Scoped to the individual enemy instance, not global: another enemy may still target the banned-for player. It gates targeting only; it does not make the player immune to incidental contact effects from other enemies.

## Web wrap

**Definition** — The spider's catch: on overlapping its target, the player is frozen in place (~20s) under a web visual that fades out near expiry, then control returns. The wrapped player ignores input, settles under gravity, stays a camera framing target, can still be killed by kill zones, and cannot be shoved by the robot.

**Boundary** — A timed lockout, not a death or damage: it never costs lives by itself and has no escape mechanic (no struggling, no teammate rescue). The web is a runtime visual entity, never placed in Tiled.

## Head stomp

**Definition** — A player landing on an enemy from above stuns it for ~10s (frozen, visually indicated) and bounces the player upward. The players' only counterplay against enemies.

**Boundary** — A stun, not a kill — enemies cannot be destroyed. Detected geometrically (falling player overlapping from above), since enemies are not solid to players. Does not start a harassment ban.

## Enemy death and respawn

**Definition** — An enemy that touches a kill zone dies using the same flash-and-fade sequence a player death uses, then stays gone (invisible, non-solid, no behaviour) for a fixed 30-second window before respawning at its original Tiled spawn position and facing with the same flash-and-fade-in a player respawn uses. Respawn is a full reset: no stun, chase target, or harassment ban carries over.

**Boundary** — No lives, score, HUD, or camera-framing effect — scoped entirely to the enemy's own sprite, collider, and behaviour FSM. The 30-second gone-window is the player's payoff for the kill, not a checkpoint or damage system. Being stunned does not grant kill-zone immunity. If a spider dies while it has a player wrapped, the wrap ends immediately rather than waiting for the web's own expiry or the spider's respawn.

## Cage objective

**Definition** — The completion spine of a level: players collect colored keys to unlock matching cages (each release spawns a bird or rabbit ally that cosmetically follows the releasing player — no scripted path). The level's `InGameState` counts cages on load and listens for each cage's `cage_unlocked` event; once every cage has been used it emits `all_cages_unlocked`, which the exit door opens on directly. The level ends when all players exit through it.

**Boundary** — The structural objective, not a scoring system: coins and other pickups are optional extras. The exit door also carries a legacy `actor_count` `Variable` and `exitInstant`/`exitThroughDoor` methods from an earlier bird-path design; neither is wired to anything and both are dead code — the `all_cages_unlocked` event is the real mechanism.

## Level generator

**Definition** — The standalone offline CLI tool that produces complete, playable-but-bland levels (a Tiled `.tmx` plus a solution walkthrough) for designers to hand-tweak in Tiled and ship through the normal pipeline. The game loads `.tmx` directly, so a generated or hand-tweaked file is immediately playable with no export step.

**Boundary** — A design-time tool, never part of the shipped game or its runtime. It generates new maps; it does not validate or repair hand-made ones.

## Solution-first generation

**Definition** — The level generator's construction discipline: build the abstract solution plan (objectives placed into zones a movement model already guarantees are connected by walking and/or ladders — the player has no jump) first, realise terrain and entities around it, and decorate last — so every emitted level is solvable by construction.

**Boundary** — There is no post-hoc solvability checker; validity is implied by construction. It constrains generation, not hand-editing — a designer can still break a level in Tiled afterwards.

## Puzzle rule

**Definition** — A pluggable module in `tools/level_generator/rules/`, auto-discovered (a new file needs no registration), encoding one optional flourish — a lever or pressure plate that can turn something already-working on or off — through a uniform interface: what zone it needs, what it places, and the walkthrough step it contributes. Deliberately never gating: nothing in `Switchable` (teleport, jump pad, drawbridge) can be authored to start blocked from map data alone except via the one seam added for the coop dial (see Cage objective's neighbour, Level generator), so a rule can only ever take something that already works and let a lever turn it off and back on.

**Boundary** — Generator-side only, and distinct from the coop dial's pressure-plate vault, which *is* a real, required gate — that's a standalone mechanism (`tools/level_generator/coop.lua`), not a puzzle rule, precisely because rules are never allowed to block completion. Not a runtime scripting system.

## Solution walkthrough

**Definition** — The ordered, human-readable completion steps the level generator emits alongside each generated level, derived directly from its solution plan, used to playtest candidates quickly.

**Boundary** — A testing aid for designers, not shipped game content and not a hint system.

## Snap alignment

**Definition** — The deterministic forcing of a pushable's x to a tile's centre. Occurs only on two events: the prop's centre-x passing over an unsupported tile (it snaps and falls straight in) and a prop coming to rest on a pressure switch (it snaps on push-release when within tolerance). See ADR 0001.

**Boundary** — Not the normal resting behaviour: props otherwise rest at whatever x they were left at, and the player can push a prop back out of a snapped position.

## Drawbridge

**Definition** — A single-tile, one-way crossing entity placed in Tiled over a real gap. It starts closed, leaving the gap fully exposed — there is no barrier, so approaching from the wrong side means falling in, like any other pit. It lowers into solid, walkable ground while it is *held*, and raises (the open animation played in reverse) once it is not. Its `crossingDirection` property names the direction of travel it permits — `leftToRight` or `rightToLeft` — and places the lead-in trigger tile on the arrival side accordingly. While open it is solid to everyone from either direction. Resets to closed on level restart. It occupies one tile in Tiled and one tile of collision, but *draws* 3×3 tiles centred on that tile, so the art can overlap its neighbours and key into the surrounding environment.

**Boundary** — A local directional crossing, not a switch: it never drives a remote `target`/`:switch()`. The 3×3 draw area is purely visual — only the single deck tile is standable and only the single trigger tile is a lead-in. Direction gates *where the hold zone's lead-in tile sits*, not who may use the bridge — there is no entity-type eligibility at all, and an opened deck is solid to all. Single tile, horizontal, over a designer-authored gap (it neither creates the pit nor the hazard). Not grid-locked movement and not a multi-tile bridge.

## Hold zone (drawbridge)

**Definition** — The union of a drawbridge's lead-in trigger tile and its own deck tile. Any entity overlapping either one *holds* the bridge, which lowers while held and raises while not; an interruption in either direction reverses the animation from the current frame rather than snapping. Anything counts — players, enemies, pushed boxes — so a box shoved into the trigger opens the bridge exactly as a player would.

**Boundary** — Presence, not events: it is evaluated every frame from overlap, so an entity that has triggered a bridge but not yet walked onto the deck is still holding it. Not an eligibility filter (nothing is excluded) and not a memory of past use (the bridge has no notion of having been used before). One asymmetry survives: only the trigger tile can break a *closed* bridge — deck-tile overlap alone cannot, or a wide collider grazing the deck's far edge from the wrong side would pre-emptively solidify the gap for it. Once the bridge is moving, either zone governs every other transition.

## Reversible timeline

**Definition** — The bidirectional playback capability on the `Timeline`/`Sprite` components: an animation can be played forward from the start, played in reverse from the end, or reversed from the current frame mid-playback, with a finish signal that fires at both the forward and the reverse end. Lets one authored animation serve an open/close pair (first used by the drawbridge).

**Boundary** — A playback/timing capability only; it plays existing frames in either direction and does not generate or transform art. Forward-only consumers are unaffected. Ping-pong looping is enabled by the API but not used by any shipped entity yet.

## Story entity

**Definition** — A Tiled-placed entity of type `story` with a `text` custom property (supports `\n` newlines). When a player overlaps it and presses the use key (P1: right-shift, P2: Q), a speech bubble appears above the entity showing the text. The bubble follows the entity on screen, auto-dismisses when the player moves away (overlap ends), and has a short re-trigger cooldown. Player retains full control while the bubble is visible.

**Boundary** — Single-bubble, non-branching narrative delivery. Not a cutscene (no camera take, no input lock, no animation sequence). Not a quest tracker. Configured entirely via Tiled object properties; no code changes needed per instance.

## Speech bubble

**Definition** — A transient UI overlay rendered above a story entity while its dialogue is active. Draws the entity's `text` property in a styled bubble anchored to the entity's screen position, updating each frame to follow the entity through camera pan/zoom. Auto-hides when the triggering player's overlap ends.

**Boundary** — Pure visual feedback; no gameplay effect, no input consumption, no pause. Distinct from HUD (lives, keys) and menus (Slab). One bubble max per story entity; multiple entities can show bubbles simultaneously (one per player per entity).

## Sound component

**Definition** — An entity component that loads WAV audio files on initialization and plays them by name with a configurable random pitch variation (±10% by default). Attached to entities requiring sound effects (player, coin, drawbridge, switch, key, cage, exit door, jump pad, enemies, kill zone, teleport, ladder, pressure switch, story). API: `init(props.sounds, props.pitchVariation)`, `play(name)`, `destroy()`.

**Boundary** — SFX only; no music, ambience, spatial audio, mixing, or pooling. Creates a new `love.audio.Source` per play; GC handles cleanup. Distinct from `love.audio.Source` (the LÖVE object) and from any future audio manager.

## SFX (sound effect)

**Definition** — A short, non-looping audio clip triggered by a discrete gameplay event (jump, pickup, death, switch toggle). Format: WAV, loaded as static source. Distinguished from music (streamed, looping, crossfaded) and ambience (layered, continuous).

**Boundary** — Not a music track, not an ambience layer, not a spatial audio emitter. Purely event-driven playback via Sound component.

## External tileset

**Definition** — A Tiled tileset saved to its own `.tsx` file and referenced from a map rather than embedded in it (Tiled's default, recommended workflow since 1.0). The vendored map loader resolves a referenced `.tsx` at load time — parsing its XML and producing a tileset table shaped identically to an embedded tileset — covering both a single shared image on a grid (e.g. `generic_platformer_tiles.tsx`) and an image-collection tileset with one (optionally cropped) image per tile (e.g. `props.tsx`).

**Boundary** — A loading-time concern only; once resolved, an external tileset is indistinguishable from an embedded one to every downstream consumer (tile rendering, animation, `Map:getTileProperties`). Per-tile collision-editor shapes resolve for parity but are not consumed by this project's collision model, which comes entirely from map-level object layers. Distinct from an **object template** — a separate Tiled feature, resolved by the map parser rather than by tileset resolution.

## Tiled map source

**Definition** — The `.tmx` file a map is authored in, and the format the game loads directly. A map parser reads the XML — resolving referenced object templates and external tilesets — and produces the same map table that Tiled's Lua export plugin produces, so nothing downstream of loading needs to know which format a map came from.

**Boundary** — `.tmx` is the sole source of truth for anything authored in Tiled: both levels and parallax background presets. It is not exported to `.lua`; there is no derived artefact and no export step. Hand-authored `.lua` maps remain permanently supported for test fixtures maintained without a Tiled round-trip, chosen by file extension at load time. Loading is confined to the constructs this project uses plus grouped layers and ellipse/point objects; anything else (CSV tile data, infinite or chunked maps, unrecognised layer types) fails loudly at load time naming the file and the construct, rather than loading a partial map.

## IPC Server

**Definition** — A non-blocking TCP server embedded in the LÖVE game that listens on localhost (127.0.0.1) and accepts simple text commands from external tools (e.g., OpenCode). Enables programmatic control: resize window, move players, query state, restart level, return to menu.

**Boundary** — Opt-in via `ipc` launch flag; disabled by default. One command per connection (short-lived). Plain text protocol, line-delimited. No authentication (localhost trust model). Not a WebSocket, HTTP, or persistent connection server.

## CommandHandler

**Definition** — Module that parses incoming command lines, dispatches to registered handler functions, and formats responses (`OK: ...` or `ERROR: ...`). Delegates game operations to GameAPI.

**Boundary** — Pure Lua, no LÖVE dependencies. Stateless per-command. Unknown commands and malformed args return ERROR without crashing.

## GameAPI

**Definition** — Module exposing safe game operations to IPC commands: `resize(w, h)`, `movePlayer(idx, dx, dy)`, `getState()`, `getPlayerPos(idx)`, `restartLevel()`, `goToMenu()`. Operates on global game state (`game`, `map`, `world`, `love`).

**Boundary** — Only functional in `InGameState` (returns error in `MenuState`). Direct position manipulation (not input simulation). Read-only queries for state. No entity spawning or physics modification.

## OpenCode Tools

**Definition** — TypeScript tool definitions in `.opencode/tools/fido-kitch-ipc.ts` that expose IPC commands as callable functions to the OpenCode agent. Each tool connects via TCP to the game, sends a command, parses the response, and returns typed results.

**Boundary** — Project-local (not global plugin). Uses `@opencode-ai/plugin` `tool()` factory. Configurable port via `FIDO_KITCH_IPC_PORT` env var. One TCP connection per tool call.

## Object template

**Definition** — A Tiled `.tx` file declaring a reusable object — its class/type, name, size, tile image and default custom properties — which maps then place instances of. Nearly every interactive prop in this project is placed this way. An instance inherits everything from its template and may override any attribute; custom properties merge with the instance winning; and the template's tile reference is remapped from the template's own tileset numbering into the map's.

**Boundary** — Resolved by the map parser at load time, **not** by Tiled's Lua export plugin, which silently drops the template-derived class/type and so blanks the type on every template-placed object. Since entity construction selects a class purely from an object's type, that defect turned whole maps into inert scenery — including spawning zero players — which is the reason `.tmx` is loaded directly. A template's tileset is auto-registered if the map does not declare it, matching Tiled's own behaviour. Distinct from an [external tileset](#external-tileset) (`.tsx`), which describes tiles rather than objects.

## NPC (Non-Player Character)

**Definition** — A visual-only companion entity that follows players. Two types: Bird (flies freely, ignores all collision, raycast+steer navigation) and Rabbit (hops behind player, follows breadcrumb trail for reliable ladder/puzzle navigation). No gameplay interaction — no collision with players/enemies/tiles, no use action, no damage.

**Boundary** — Purely cosmetic; never affects gameplay state, physics, or win conditions. Spawned from cages, persists until level exit.

## Cage Spawn Type

**Definition** — Tiled custom property `spawn_type` on cage objects determining which NPC spawns when unlocked. Values: `"bird"` | `"rabbit"` (default: `"bird"`). Set per-cage in Tiled.

**Boundary** — Map authoring concern only; read once at cage unlock. No runtime mutation.

## Breadcrumb Trail

**Definition** — Timestamped position history recorded by Player (circular buffer, 120 frames = 2 seconds at 60Hz). Used by Rabbit NPC to follow the player's exact path through ladders and puzzles.

**Boundary** — Player-internal state; exposed via `player:getPositionHistory()` for NPC consumption only. Not a replay system or network sync.

## All Cages Unlocked Event

**Definition** — Event bus signal (`all_cages_unlocked`) emitted when the last cage in a level is unlocked. Listened by exit door to become usable. Payload: `{totalCages=N}`.

**Boundary** — One-way signal from `InGameState` to exit door. Level must have exit door entity; if missing, event fires but nothing consumes it (safe).

## Blocker

**Definition** — A switch-gated barrier blocking horizontal passage through a gap in the terrain. Locked (solid) by default; passable only while its linked switch reports `on`. Blocks players, enemies and pushable props alike, with no entity-type eligibility. Opening is slow and late — a plain 1s timer keeps the barrier solid after the switch flips and stops blocking only once that delay elapses (the gate-rising animation plays alongside the timer in reverse, purely cosmetic — blocking is never tied to animation playback) — while closing is instant: the moment the switch reads off, the barrier snaps back to solid in the same frame, with no closing animation and nothing to slip through mid-close.

**Boundary** — Not the exit door and not a level-completion object: a blocker gates movement inside a level. It is never something to stand on, is opened only by a linked switch (not by keys, use, or contact), and mirrors switch state both ways rather than latching. There is no `closing` state and no occupancy check — a close cannot be deferred, by design.

## Exit door

**Definition** — The level-completion entity players and rescued actors leave through. Opens when its actor counter reaches zero or on the `all_cages_unlocked` event, and cannot be closed again once open for the player.

**Boundary** — Distinct from a blocker in every respect: it is a level objective, not a barrier, and is never wired to a switch. Named `exit_door` uniformly — in the type, the asset filenames, the Tiled template and the object name.
