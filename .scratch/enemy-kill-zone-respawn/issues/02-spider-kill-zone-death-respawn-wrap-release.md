Status: done

# Spider dies in a kill zone, releasing any wrapped player immediately

## What to build

End-to-end: a Spider that touches a kill zone dies and respawns using the same shared
sequence built in issue 01 (flash/fade out, 30s gone window, respawn at origin with original
facing, full state reset). Additionally, if the Spider currently has a player wrapped when it
dies, that player is released immediately — their FSM returns to `WalkIdleState` and the web
visual is cleared — rather than waiting for the web's own expiry timer or the spider's
respawn.

## Files to create/modify

- `src/entities/spider.lua` — track `self.wrappedTarget` when `wrapOverlappingTarget` succeeds
  (clear it on wrap expiry), and force-release that target's wrap when the Spider enters its
  death state.
- `src/npc/npc_states.lua` (if the release hook needs a Spider-specific override/callback
  point in the shared `DeadState`)
- `src/player/player.lua` or `src/player/player_states.lua` (if a clean `Player:releaseWrap()`
  is worth adding rather than reaching into `WrappedState` internals from `Spider`)

## Test approach

- Unit/integration test: Spider wraps a player, then dies (simulate kill zone contact) —
  assert the player's `wrapped` flag clears and FSM returns to `WalkIdleState` well before the
  web's normal expiry duration.
- Integration test: Spider walking/pushed into a kill zone dies and respawns at its origin,
  mirroring the Robot integration test from issue 01.
- Confirm a Spider that dies with no one wrapped behaves identically to a Robot (reuses the
  same shared path, no special-casing needed when there's nothing to release).

## Acceptance criteria

- [ ] A Spider that touches a kill zone dies and respawns the same way a Robot does (shared
      sequence, 30s delay, origin + facing restore, full state reset).
- [ ] A Spider that dies while it has a player wrapped releases that player immediately.
- [ ] A Spider that dies with no wrapped target behaves identically to a Robot, with no extra
      steps or side effects.

## Blocked by

01-robot-kill-zone-death-respawn.md (shared death/respawn sequence, NPC origin capture, and
kill-zone polling must exist first).
