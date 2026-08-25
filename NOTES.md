# Ladder remodel: no-gravity zone + standable top

Grill notes (2026-08-24). Scope: climbing/mounting; the core bug is
side-entry fall-through — a player falling into a ladder volume passes
through it instead of catching. Today mounting also requires terrain blocks
under ladder tops so the player can walk along the top.

## Confirmed model (asked + answered)

1. **Ladder volume = no-gravity zone.**
2. **Catch rules:** auto-catch any falling player overlapping the volume
   (no input needed). Grounded players are NEVER auto-caught — walking
   through a base column behaves like normal ground. `up`/`down` mounts
   from ground still work as today.
3. **Alignment:** auto-align to centre-x ONLY while `up`/`down` held;
   `left`/`right` passes through the column without aligning.
4. **Ladder top = one-way platform** on the lead rung: top-only collision
   via `colFilterFn` + `walkable=true` (mover_platform pattern).
   Standable/walkable with NO terrain beneath; press down on top to
   descend inside.
5. **NPCs:** players-first; verify spider/robot/rabbit unaffected,
   minimal patch only on regression.

## Carried defaults (veto here if wrong)

- Switch-off (hidden) ladders: no catch, no top platform.
- Edge keys are no-ops (user directive, vetoed the old down→FallState
  default): pressing down at the bottom of a ladder / up at the top is
  ignored — the player stays mounted. Leaving is by sliding off the side.
- Base arrival dismounts (user directive, refines the edge-key no-op):
  touching down on real (non-ladder) ground at the bottom auto-ejects to
  walking; up-at-top remains a no-op hover on the slab.
- Existing maps keep terrain under ladder tops harmlessly (flush surfaces).

## Touchpoints seen during codebase recon

- `src/entities/ladder.lua` — add top collider
- `src/player/player_states.lua` — LadderState canTransition/update
- `src/player/player_sensors.lua` — catch query
- `src/entities/mover_platform.lua` — one-way colFilterFn pattern reference

---

# Teleporter Travel FX (2026-08-25)

Grill notes. Scope: replace instant teleport with cinematic travel along a
generated curve.

## Confirmed model (asked + answered)

1. **Travel is cinematic (locked):** player input disabled during travel;
   a `TeleportTravelState` takes over until arrival.
2. **Path = auto-generated wobbly curve:** gentle 1/2 sine wave with
   perpendicular wiggle for magical feel. Control points computed from
   source/destination positions — no Tiled authoring needed.
3. **Duration scales with distance:** base ~0.8s + ~0.002s per world pixel
   (tunable). Min ~0.5s, max ~3s.
4. **Player hidden, particles only:** player entity becomes invisible;
   a custom particle effect (`TeleportTrail`) travels the curve, emitting
   wavy/oscillating magical particles. No ghost sprite.
5. **Parallel co-op travel:** both players can travel simultaneously on
   independent curves with independent particle effects.
6. **New particle preset:** `src/fx/teleport_trail.lua` — oscillating
   particles along a parametric curve (sine wave + perpendicular noise).
7. **No beam/link between pads:** only the travel particles; teleporter
   entities themselves unchanged visually.
8. **Sound:** keep existing `in`/`out` sounds at source/destination; add
   optional travel loop sound if asset exists.

## Touchpoints

- `src/entities/teleport.lua` — `use()` becomes async; spawns travel effect,
  sets player into `TeleportTravelState`
- `src/player/player_states.lua` — new `TeleportTravelState` class
- `src/player/player.lua` — add travel state to FSM, handle visibility toggle
- `src/fx/teleport_trail.lua` — new particle preset (curve + oscillating emit)
- `src/fx/manager.lua` — register travel effect via `map.fx:add()`
- `src/map/init.lua` — ensure `map.fx` accessible for teleport to add effect
