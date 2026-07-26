Status: done

# Drawbridge moves into its own entity directory

## What to build

A Tiled object of type `drawbridge` still loads, renders and behaves exactly as it does today — but its two source files now live together in `src/entities/drawbridge/`, keeping their existing names, and the entity loader understands that layout as a general convention rather than a special case.

No behaviour changes in this slice. It is a move plus a loader capability, verifiable by every existing drawbridge test still passing and the sandbox still running.

`drawbridge_support.lua` gains a header comment stating why it is a separate file: `tests/unit/` is pure Lua with no LÖVE surface, and the entity constructs `Sprite`/`Collider` components at require time, so merging the two would silently push the decision-logic tests down a tier. Without that comment the split reads as arbitrary.

`Map`'s `searchPaths` becomes pattern-based, with `?` standing in for the object type:

```lua
self.searchPaths = {
  'src.entities.?',    -- src/entities/foo.lua
  'src.entities.?.?',  -- src/entities/foo/foo.lua
}
```

Resolution stays a `pcall(require, ...)` loop, first success wins. Because a failed candidate is now normal, only report an error when *every* candidate fails — today each failure prints a full `package.path` dump, which the integration run already shows for `push_box`.

## Files to create/modify

- `src/entities/drawbridge/drawbridge.lua` (moved from `src/entities/drawbridge.lua`; require path for the helper updated)
- `src/entities/drawbridge/drawbridge_support.lua` (moved from `src/entities/drawbridge_support.lua`; why-separate comment added)
- `src/map.lua` (pattern-based `searchPaths`, single error on total failure)
- `tests/unit/drawbridge_test.lua` (require path)
- `AGENTS.md` (document the flat-until-you-need-a-second-file convention)
- `docs/adr/0003-multi-file-entity-directories.md` (already written during planning — link it from `AGENTS.md`)

## Test approach

Existing coverage is the test: all three tiers already exercise the drawbridge end to end, so a clean move is proved by `./test-unit.sh`, `./test-integration.sh` and `./test-e2e.sh` all passing unchanged.

Add one integration assertion that a nested entity resolves — the existing `every real map under res/map/ loads and steps a few frames without error` scenario covers it implicitly, so make it explicit only if it can be done without contorting the harness.

Confirm by eye that a successful nested load prints no `Entity Error:` line, and that a genuinely unknown entity type still prints exactly one.

## Acceptance criteria

- [ ] `src/entities/drawbridge.lua` and `src/entities/drawbridge_support.lua` no longer exist; both files live under `src/entities/drawbridge/` with names unchanged.
- [ ] No `init.lua` and no stub file anywhere in the new directory.
- [ ] `drawbridge_support.lua` carries a comment explaining why the split exists and what breaks if it is merged.
- [ ] `src/map.lua` resolves both `src/entities/foo.lua` and `src/entities/foo/foo.lua` from object type `foo`.
- [ ] A successful nested load prints nothing; an unresolvable type prints one error naming the type.
- [ ] `AGENTS.md` documents the convention and links ADR 0003.
- [ ] All three test tiers pass with no test-behaviour changes beyond the require path.

## Blocked by

None — can start immediately.
