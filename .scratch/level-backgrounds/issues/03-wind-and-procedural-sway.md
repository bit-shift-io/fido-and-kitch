Status: pending

# Global wind and procedural tree sway

## What to build
Trees in sandbox sway gently. A map custom property `windX` sets the level's global wind (signed: direction + strength); when absent, a code default applies. Each prop's effective motion is global wind × its `windScale`. The sway is procedural — a gentle sine skew/rotation of the drawn quad — so it works on single-frame art. Setting `windX` high makes the whole level stormy; a prop with `windScale=0` stays still.

Sandbox map updated: `windX` set as a map property (and one tree given a non-default `windScale` to demonstrate variation).

## Files to create/modify
- src/entities/tree.lua (or shared prop base) — sway motion
- src/map.lua (read `windX` map property, expose wind to entities)
- res/map/sandbox.tmx + res/map/sandbox.lua (map `windX` property, per-tree `windScale`)
- tests/ (new test file)

## Test approach
Headless: wind default applies when `windX` absent; map value overrides it; effective sway amplitude scales with wind × `windScale` (assert on the entity's computed offset/rotation after simulated update ticks, not on pixels); `windScale=0` produces no motion.

## Acceptance criteria
- [ ] Trees visibly sway in sandbox
- [ ] `windX` map property controls sway strength/direction; default applies when absent
- [ ] Per-object `windScale` multiplies the global wind
- [ ] Motion is purely visual — collision and gameplay unaffected

## Blocked by
02 (prop entities must exist).
