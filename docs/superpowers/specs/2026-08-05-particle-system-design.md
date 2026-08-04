# Particle System Design

Date: 2026-08-05
Status: Implemented

## Overview

A small, dependency-free particle system that fits the game's component
architecture: a pure emitter engine plus a set of composable "fx" preset
components, driven by a map-owned effect manager so one-shot bursts keep
animating after the entity that spawned them is destroyed (e.g. a coin's
sparkle continues while the coin itself is recycled).

The system is deliberately minimal: no SpriteBatches, no shaders, no
external libraries. Each particle is a filled `love.graphics.rectangle`
whose size and color are linearly interpolated over its lifetime.

## Architecture

Three layers, each with one clear job:

### 1. `src/particles.lua` — emitter engine

Pure Lua, no globals, each emitter fully independent. Returns a module
table exposing `Particles.new_emitter(opts) -> emitter` with
`emit(n)`, `update(dt)`, `draw()`, and `done()`.

- `update(dt)` integrates every particle semi-implicit Euler style
  (velocity += gravity*dt, then position += velocity*dt, age += dt) and
  drops any particle whose age exceeds its lifetime. Removal happens
  in-place, so there is no per-frame table churn.
- `draw()` only touches `love` (via `love.graphics.setColor` /
  `love.graphics.rectangle`); `update`/`emit` are headless-safe.
- Hard cap of 500 particles per emitter; `emit()` never grows past it.

Because `.end` is a Lua keyword, the `size.end` / `colors.end` options
are read and written as `["end"]`.

Options (all optional): `position` `{x,y}`, `lifetime` `{min,max}`
(seconds), `speed` `{min,max}` (px/s), `direction` `{angle,spread}`
(radians), `gravity` `{x,y}` (px/s²), `size` `{start,end}` (px, lerped),
`colors` `{start,end}` `{r,g,b,a}` (lerped).

### 2. `src/fx/` — preset effect components

Each preset is a hump `Class` (so it composes like every other component)
with a shared base:

- `src/fx/base.lua` — `FxBase`: builds a `Particles` emitter from the
  subclass's `config()`, handles shared `emit`/`update`/`draw`/`done`,
  and auto-bursts `emitCount()` particles at construction unless the
  caller passes `hold`.
- `src/fx/coin_pickup.lua` — yellow-gold sparkle fountain; `emitCount() == 12`.
- `src/fx/dust_burst.lua` — soft brown puff; `emitCount() == 10`.
- `src/fx/spark_trail.lua` — continuous emitter that does not auto-burst;
  a persistent owner calls `emit()` per frame.
- `src/fx/manager.lua` — `FxManager`: the persistent registry. Holds the
  active effects, runs `update`/`draw` on each, and reaps effects whose
  `done()` returns true. Exposes `add(fx)` and `burst(preset, opts)`.

A preset can be used two ways:

- One-shot burst via the manager: `map.fx:burst(CoinPickup, {x,y})`.
- Continuous via component attach: `self:addComponent(SparkTrail{})` on a
  persistent entity (its `update`/`draw` are forwarded by the entity).

### 3. Map ownership

The `Map` owns exactly one `FxManager` (`self.fx`), `Map:new` builds it,
`Map:update` advances it (after the object layers update), and
`Map:drawEntities` draws it inside the same world-space transform so
effects render on top of pickups in the correct screen position.

## Why a map-owned manager (the key decision)

`Entity:update`/`Entity:draw` only run while an entity sits in its Tiled
object layer. A pickup (coin/key) is `queueDestroy()`'d on contact and
destroyed on the next map update — so a burst emitter owned by the dying
entity would be torn down before it ever drew a frame. The `FxManager`
is the persistent home that decouples an effect's lifetime from the
entity that spawned it.

## Integration with the component system

`PickupProp.define` gains an optional `pickupFx` spec field. When set,
`PickupProp` connects to the entity's `destroySignal` and, on destroy,
hands a burst to `map.fx`:

```lua
map.fx:burst(spec.pickupFx, { x = position.x, y = position.y })
```

`src/entities/coin.lua` simply declares `pickupFx = CoinPickup`. Because
`PickupProp` is the shared archetype for `coin` and `key`, other pickups
can opt in the same way with no new code.

Module globals (`Particles`, `FxManager`, `CoinPickup`, `DustBurst`,
`SparkTrail`) are wired in `src/main.lua`, following the existing global
class convention.

## Testing

- `tests/unit/particles_test.lua` (registered in `tests/unit/run.lua`):
  emitter cap, position integration, semi-implicit-Euler gravity, headless
  `draw()` against the love mock, and `FxManager` burst/reap lifecycle.
  Uses `tests/support/love_mock.lua`, which already stubs
  `love.graphics.setColor`/`rectangle`.
- Verified end-to-end via the integration harness: a real map with coins
  (`res/map/ll1.tmx`) loads, destroying a coin spawns one
  `coin_pickup` burst in `map.fx`, and the burst is reaped after the
  particles expire.

## Constraints honored

- Pure Lua, no external libraries.
- No globals in `particles.lua`; each emitter is independent.
- `love.graphics.setColor` / `love.graphics.rectangle` only — no
  SpriteBatches, no shaders.
- 500-particle cap per emitter.