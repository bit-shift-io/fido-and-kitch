# ADR 0001: Bake computed jump pad trajectories into .tmj source files in debug mode

**Status:** Accepted
**Date:** 2026-08-30

## Context
Jump pad paths are hand-drawn polylines, tedious to author realistically. The
fix is a `target` point plus computed arc, but Tiled runs no Lua, so nothing
computed by the game can preview live inside the editor. The designer still
wants to see the resulting arc in Tiled after the fact.

## Decision
The running game, when launched with the existing `debug` flag, writes the
computed trajectory back into the level's own `.tmj` source file on map load
— turning it into a real polyline object plus a `path` property, exactly as
if a designer had hand-drawn it. A standalone offline CLI tool performs the
same bake without running the game at all. Either route skips any pad that
already has a `path`.

## Alternatives Considered
- **Runtime-only, debug overlay** — render the computed arc in-game via
  `Path:draw()`-style debug drawing, never persisted. Rejected: the designer
  explicitly wants it visible back in Tiled, not just in a debug overlay.
- **IPC-triggered bake** — expose a bake command through the existing debug
  IPC server (`GameAPI`), triggered on demand instead of automatically on
  load. Rejected in favor of automatic bake-on-load for simplicity; may
  revisit if automatic bake proves too eager in practice.
- **Offline tool only** — skip the in-game route entirely. Rejected: the
  user wants to playtest and have what they saw reflected on disk without a
  separate manual step.

## Consequences
- The game gains a debug-mode side effect that writes to its own source
  asset files — unusual for this codebase, and worth flagging to anyone
  unfamiliar with it (a game process should not normally mutate its own
  shipped content on disk).
- Reuses the `debug` launch flag's existing meaning ("designer authoring
  session") rather than introducing a new flag.
- Any automated test that loads a map with `conf.debug = true` risks
  mutating fixture `.tmj` files on disk; test suites must keep `conf.debug`
  false unless a test is specifically exercising this bake path.
- Re-baking after moving a target requires manually deleting `path` first —
  there is no "force regenerate" affordance in this version.
