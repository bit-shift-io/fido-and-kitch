Status: pending

# 10: NPC Teleport/Blink on Player Respawn or Excessive Distance

## What to build
NPCs teleport to player with visual blink (alpha fade) when: (a) distance to target > `teleportDistance` (20 tiles), or (b) player respawns (safe position updated).

## Files to create/modify
- Modify: `src/components/npc_follow.lua` (add teleport check in update)
- Modify: `src/player/player.lua` (emit event on respawn, or NPC watches safe position)
- Test: `tests/unit/npc_teleport.unit.test.lua`

## Interfaces
- Consumes: `player.safePosition` (or respawn event), `config.teleportDistance`
- Produces: NPC position = player position + offset; alpha tween 0→1 over 0.2s

## Test approach
- Unit test: distance > threshold → teleport triggers
- Unit test: player respawn (safePosition change) → teleport triggers
- Unit test: blink alpha animation (0→1 over 0.2s)
- Unit test: teleport offset prevents overlap (small random or fixed offset)
- Integration: kill player, verify NPCs blink to safe position

## Acceptance criteria
- [ ] In `update(dt)`: if `distance(npc, targetPlayer) > teleportDistance` → teleport
- [ ] Teleport: `npc.x, npc.y = player.x + offsetX, player.y + offsetY` (offset: ±8px random)
- [ ] Blink: `npc.alpha = 0`, `Tween(0.2, npc, {alpha=1})` (uses global Tween)
- [ ] Player respawn detection: watch `player.safePosition` change OR listen for `player_respawned` event
- [ ] Dead players ignored (NPC waits for alive target)
- [ ] No teleport spam: cooldown 1s between teleports

## Blocked by
- Issue 01: NPCFollowComponent (core update loop)
- Issue 03/05: NPC entities exist