---
name: entity-atomic-draw-and-tint
description: Tint/FlashEffect rely on Entity:draw()'s two-pass (all draw(), then all postDraw()) loop running back-to-back for one entity's components — don't split an entity's draw across other entities' draws without checking this.
metadata:
  type: convention
---

**Why:** `Tint`/`FlashEffect` (`src/components/tint.lua`, `src/components/flash_effect.lua`) call `love.graphics.setColor` in `draw()` and reset it in `postDraw()`. `Entity:draw()` (`src/entity.lua`) calls every component's `draw()` in add-order, then every component's `postDraw()` — this only stays color-safe because one entity's components run back-to-back with no other entity's draw interleaved in between. The `renderOrder` global draw sort ([[render-order]]) keeps this invariant by drawing most entities as one atomic unit; only an entity that explicitly gives 2+ of its own `Sprite` components different `renderOrder` values splits into separate draw units. That combination with `Tint`/`FlashEffect` is unsupported and NOT guarded with a fallback — the split still happens, so the resulting color bleed is real and visible, and only a `Log.error` flags the misuse.

**How to apply:** Before making entity draws interleave at a finer grain than "one whole entity," check whether that entity (or any entity it could now interleave with) uses `Tint` or `FlashEffect` — splitting those color-state components apart from their sibling `Sprite` will bleed color onto whatever draws in between, and nothing currently prevents it beyond a log line. Also preserves the `speedStreak`-before-`animations` component-order guarantee in `tests/integration/mesh_ribbon_draw_order_test.lua`.
