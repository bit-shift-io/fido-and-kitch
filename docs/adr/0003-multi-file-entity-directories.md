# ADR 0003: Multi-file entity directory pattern (real filenames, no init.lua)

**Status:** Accepted
**Date:** 2026-08-30

## Context
An entity that grows beyond a single file needs a home for its extra
modules. Lua convention often wants an `init.lua` and dot-module requires,
but this codebase keeps real, descriptive filenames so a file's purpose is
readable in the editor and in tracebacks.

## Decision
When an entity (or a shared component) needs more than one file, it is a
**directory named after the entity/component type** (`src/entities/<type>/`,
`src/components/<component>/`) containing the real file and its siblings.
The entrypoint keeps its own real filename (e.g. `src/entities/<type>/<type>.lua`),
**no `init.lua`** is introduced, and modules are required by their real path
(e.g. `require('src.components.pushable.pushable_support')`). A single-purpose
entity stays a single flat file until a second file is actually needed.

## Alternatives Considered
- **`init.lua` + dot-module convention** — `src/entities/drawbridge/init.lua`
  plus `require'drawbridge.foo'`. Rejected: hides the entrypoint behind a
  generic filename, and the directory derives its name from convention rather
  than content.
- **Suffix-everything flat** — cram helpers into one file with an
  `_support`/`_internal` suffix. Rejected as the general rule: splitting logic
  that is only voluminous, not behaviourally distinct, to dodge headless
  construction indicated the wrong split (see ADR 0005).

## Consequences
- A reader can always tell which file is the entity entrypoint from its
  name.
- Tests and code require files by real names, so `require` paths stay
  auditable and grep-able.
- The directory exists only to group related files; removing it never
  changes behaviour.
