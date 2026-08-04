# Friendly NPC Respawn & Sprite Flash Design

## Goal

Rescued NPCs (birds, rabbits) should respawn at the player's position with a visual blink/fade when the player moves too far away or when the NPC dies. The flash effect moves from separate Flash/Tween components into the Sprite component.

## Requirements

1. Friendly NPCs respawn instantly (no delay) when the followed player exceeds a configurable distance
2. After respawning, the NPC keeps following the same player
3. Death respawn for friendly NPCs targets the followed player's position, not the original spawn point
4. The blink/fade visual effect is owned by the Sprite component, not external Flash/Tween components
5. The old Flash and DeathFlash components are removed

## Design

### 1. Sprite Component Enhancement

Add two methods to `src/components/sprite.lua`:

- `Sprite:blink(interval, blinks, onComplete)` — toggles `self.visible` at the given interval for N blinks, then calls `onComplete`. Uses an internal timer managed in `Sprite:update`.
- `Sprite:fadeIn(duration)` — tweens `self.alpha` from 0 to 1 over the given duration. Uses an internal tween managed in `Sprite:update`.

Both methods are no-ops if `self` has no image/frames (headless mode).

`Sprite:update` is extended to tick the blink timer and fade tween when active.

### 2. NPC Config

Add `despawnDistance` to `NPCConfig.Defaults`:

```lua
despawnDistance = 0,  -- 0 = disabled
```

Set `despawnDistance = 400` in `npc_bird.lua` and `npc_rabbit.lua` defaults. Hostile NPCs (spider, robot) leave it at `0`.

### 3. NPCBase:despawnToTarget()

New method on `src/npc/npc_base.lua`:

```lua
function NPCBase:despawnToTarget()
    local tx, ty = self:getTargetPos()
    if not tx then return end
    self.x = tx
    self.y = ty
    if self.collider then
        self.collider:setPosition(tx, ty)
        self.collider:setLinearVelocity(0, 0)
    end
    self.target = self.target  -- keep target for continued following
    self.stateMachine:setState('IdleState')
    if self.sprite then
        self.sprite:fadeIn(0.15 * 8)  -- DeathFlash.FADE_DURATION
        self.sprite:blink(0.15, 8)     -- DeathFlash constants
    end
end
```

### 4. Distance Check in NPCBase:update

Add after the player detection block (line ~170) and before utility calculation:

```lua
if self.config.despawnDistance > 0 and self.target and not self:isDead() then
    local tx, ty = self:getTargetPos()
    if tx then
        local dx = tx - self.x
        local dy = ty - self.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > self.config.despawnDistance then
            self:despawnToTarget()
        end
    end
end
```

### 5. DeadState Update

Update `src/npc/states/dead_state.lua` to use `npc.sprite:blink()` + fade instead of `DeathFlash.startDeath()`:

```lua
function DeadState:enter()
    local npc = self.entity
    if npc.collider then
        npc.collider:setType('kinematic')
    end
    npc.homeX = npc.x
    npc.homeY = npc.y
    npc.deathTimer = -1
    npc.deathType = npc.deathType or 'unknown'
    -- Use sprite's own blink + fade
    if npc.sprite then
        npc.sprite:blink(0.15, 8, function()
            npc.deathTimer = 0
        end)
        -- Alpha fade out handled by sprite update
    else
        npc.deathTimer = 0
    end
    EventBus.emit('npc_death', {npc = npc, source = npc.deathType})
end
```

### 6. Remove Flash/DeathFlash

- Delete `src/components/flash.lua`
- Delete `src/components/death_flash.lua`
- Update all call sites:
  - `DeadState` (src/npc/states/dead_state.lua)
  - `respawn()` in NPCBase (src/npc/npc_base.lua)
  - Any other callers (grep for `DeathFlash` and `Flash`)

### 7. Files Changed

| File | Change |
|------|--------|
| `src/components/sprite.lua` | Add `blink()`, `fadeIn()`, internal timers in `update` |
| `src/npc/npc_config.lua` | Add `despawnDistance = 0` default |
| `src/npc/npc_base.lua` | Add `despawnToTarget()`, distance check in `update`, update `respawn()` |
| `src/entities/npc_bird.lua` | Add `despawnDistance = 400` |
| `src/entities/npc_rabbit.lua` | Add `despawnDistance = 400` |
| `src/npc/states/dead_state.lua` | Use `npc.sprite:blink()` instead of `DeathFlash` |
| `src/components/flash.lua` | Delete |
| `src/components/death_flash.lua` | Delete |

### 8. Testing

- Unit tests: Add test for `Sprite:blink` and `Sprite:fadeIn` timer behavior
- Unit tests: Add test for `despawnToTarget` teleport + velocity reset
- Unit tests: Add test for distance check triggering despawn
- Integration: Verify bird follows player, respawns when player moves far away
- E2E: Visual verification of blink/fade on respawn and death
