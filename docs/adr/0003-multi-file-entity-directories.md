# ADR 0003: Multi-file entities live in a directory named after the entity

**Status:** Accepted (drawbridge's own split reversed by ADR 0005; the directory convention documented here still applies to any other multi-file entity, e.g. pushable, pressure_switch)
**Date:** 2026-07-26

## Context

Entities are resolved from Tiled object types at map-load time: `Map:createEntity` walks `self.searchPaths` and `pcall(require, path .. objectType)`, so an object of type `drawbridge` is whatever `src/entities/drawbridge.lua` returns. One type, one file, discovered by name.

Some entities need more than one file. The drawbridge is the first: its pure decision logic lives in `drawbridge_support.lua` so it can be tested in `tests/unit/`, which is pure Lua with no LÖVE surface at all — the entity itself evaluates `Class{__includes = Entity}` and constructs `Sprite`/`Collider` components at require time and cannot be required there. `src/player/ground_support.lua` uses the same split for the same reason.

Flat sibling files (`drawbridge.lua`, `drawbridge_support.lua`) make that relationship invisible: the entity directory listing gives no signal that the two are one entity, and nothing tells the next contributor what to do when their entity needs a third file. Left unanswered, each multi-file entity invents its own prefix convention.

## Decision

An entity that needs more than one file gets **a directory named after the entity type**, containing files that keep their real, descriptive names:

```
src/entities/drawbridge/
  drawbridge.lua
  drawbridge_support.lua
```

To make that resolvable, `Map`'s `searchPaths` becomes a list of *patterns* rather than plain prefixes, with `?` standing in for the object type:

```lua
self.searchPaths = {
  'src.entities.?',    -- src/entities/foo.lua
  'src.entities.?.?',  -- src/entities/foo/foo.lua
}
```

Resolution remains a `pcall(require, ...)` loop over the candidates; the first success wins. Because a failed candidate is now a normal part of resolving a nested entity, the loader only reports an error when *every* candidate fails, instead of printing one per attempt.

Single-file entities are unaffected and stay flat. No `init.lua` is used.

## Alternatives Considered

**A one-line `init.lua` re-export per directory.** Lua's package system already falls back to `a/b/init.lua` for `require('a.b')`, so this needs no loader change at all and carries zero risk. Rejected because every future multi-file entity would carry a stub file whose only content is a `require` of its sibling.

**`init.lua` as the entity plus `support.lua` beside it** — the idiomatic Lua layout, also needing no loader change. Rejected because the meaningful name ends up in the directory while the files themselves read as generic; editor tab bars and stack traces show the filename, and three entities laid out this way give you three tabs called `init.lua`.

**Merge each entity back into one file.** Rejected: it would push the pure-logic tests out of the fast headless unit tier, which is the entire reason the split exists.

**Prefix convention only** (`drawbridge_support.lua` beside `drawbridge.lua`, as today). Rejected as the status quo that prompted this — the grouping is a naming coincidence rather than a structure.

## Consequences

- Multi-file entities have one obvious home, and adding a third file to one needs no thought and no loader change.
- The convention is declared in exactly one place — `Map`'s `searchPaths` — rather than repeated as a stub file per entity.
- Every nested entity load now costs one failed `require` before the successful one. Negligible at map-load time, but it does mean the loader can no longer treat a single failed candidate as an error worth printing.
- Requiring a nested entity's helpers from tests changes path: `src.entities.drawbridge.drawbridge_support`. Moving an entity into a directory is therefore not purely internal — test requires move with it.
- Two ways to lay out an entity now exist (flat and nested). The rule is only "flat until you need a second file", but it is a rule someone has to know; it is documented in `AGENTS.md` for that reason.
