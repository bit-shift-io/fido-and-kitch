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
