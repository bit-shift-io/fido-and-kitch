# Decisions — Procedural Level Generation

Grill session 2026-07-15.

### Q1: What problem is generation solving?
**Decision:** Content velocity — a standalone offline tool; generated levels are hand-tweaked in Tiled afterwards. Not shipped in the game.
- **Why:** The bottleneck is producing credible starting points, not runtime variety.
- **Implication:** No game-code integration; output must be Tiled-editable source (`.tmx`), and the game codebase stays untouched except possibly small testability seams for constants.
- **Alternatives considered:** Runtime roguelite mode (rejected: different feature entirely); in-level variation of hand-made skeletons (rejected: less leverage).

### Q2: How complete is a generated level?
**Decision:** Playable-but-bland, end to end — terrain, ladders, spawns, full objective chain, hazards, enemies, dressing.
- **Why:** "The more the generator can do the less we have to do."
- **Implication:** The generator must understand every placeable entity's Tiled contract, including bird paths and `object:exec` snippets.

### Q3: Solvability guarantee
**Decision:** Guaranteed by construction; the tool also emits a solution walkthrough per level.
- **Why:** A broken level costs more tweak time than a bland one; a construction-first generator knows the solution, so emitting the walkthrough is nearly free.
- **Implication:** Solution plan is built first, terrain realised around it; no post-hoc solvability checker exists.
- **Alternatives considered:** Generate-then-validate (rejected: validating pushable-prop puzzles is genuinely hard); human-as-validator (rejected: silently degrades "playable" to "probably playable").
- Promoted to ADR 0002.

### Q4: Co-op model
**Decision:** `--coop required|optional` dial.
- **Why:** Some levels should demand teamwork (the game's identity), others should be soloable.
- **Implication:** `required` needs a two-agent solution model; `optional` restricts plans to single-agent-solvable.

### Q5: What makes a puzzle co-op?
**Decision:** Players are mechanically identical; co-op pressure comes from spatially separating interdependent elements (e.g. momentary pressure switch far from the door it holds open). Puzzle patterns live in a modular rule library so new props drop in as new rules.
- **Why:** No asymmetric abilities exist or are planned; modularity future-proofs the tool.
- **Implication:** Rule interface must express requires/unlocks/placement/walkthrough-steps uniformly. This is the second half of ADR 0002.

### Q6: Workflow and invocation
**Decision:** Seeded one-shot CLI with `--count N` batch; no GUI/interactive mode.
- **Why:** Cheap to build, covers both browse-many and regenerate-one workflows.
- **Implication:** Determinism is a hard requirement: same seed + flags ⇒ identical output; batch item i derives its seed from the base seed so each item is independently reproducible.

### Q7: Language and runtime
**Decision:** Plain Lua (LuaJIT-style), in a new `tools/` directory, launched by a shell script (`tools/generate.sh`).
- **Why:** Matches the repo; can `require` game source for ground-truth constants (tile size, jump reach, speeds) instead of duplicating numbers that drift.
- **Alternatives considered:** Python (rejected: every gameplay constant duplicated by hand, guaranteed drift).

### Q8: Entity palette timing
**Decision:** Design for the full palette including pushables, pressure switches, and enemies. Those features will ship in the game **before** this tool is implemented.
- **Why:** Surfaced during grill: the glossary documents them but `src/` does not contain them yet — they are designed-not-shipped.
- **Implication:** This feature is **blocked on** pushables/pressure-switch/enemies landing. The rule library absorbs later props without core changes.

### Q9: Objective model (from code, confirmed by user)
**Decision:** Colored keys unlock matching cages; each cage releases a bird ally that follows a generated polyline path and may perform actions (e.g. flick a switch) before exiting; the exit door's `actor_count` variable counts down as birds exit; releasing the last cage opens the door; all players exiting ends the level.
- **Why:** This is the game's actual completion mechanic (`cage.lua`, `exit_door.lua`, `bird.lua`).
- **Implication:** The generator authors bird path objects and `object:exec` event snippets, exactly as hand-made maps do.

### Q10: Size and difficulty dials
**Decision:** `--size small|medium|large` (roughly 20×15 up to ~60×40 tiles) and `--difficulty 1..5` scaling cage count, chain depth, hazard and enemy density together; bigger maps generally mean more complexity.
- **Why:** Matches existing bite-sized levels while allowing growth; one coherent dial beats many fiddly ones for v1.

### Q11: Playtest loop / export
**Decision:** Emit `.tmx` + auto-export `.lua` via the Tiled CLI (`tiled --export-map lua in.tmx out.lua`); fall back to `.tmx`-only with a clear warning when Tiled isn't found.
- **Why:** STI loads only `.lua`; manual Tiled export per candidate is painful in batch mode. Verified locally: Tiled 1.12.2 at `/Applications/Tiled.app` supports `lua` export via CLI.
- **Alternatives considered:** Writing our own `.lua` serializer (rejected: second serializer to keep in lockstep with Tiled's export format).

## Key assumptions

- The Tiled CLI's `.lua` export is byte-compatible with what the editor's export produces (same code path in Tiled).
- Gameplay constants needed by the movement model are requirable from `src/` headlessly, or can be made so with small testability seams.
- The upcoming pushable/pressure-switch/enemy implementations will match their glossary definitions and ADR 0001 closely enough to design rules against now.
- `exit_door.actor_count` equals the number of birds; birds not exiting through the door call `exitInstant` — either way the counter reaches zero when all cages are released.

## Trade-offs explicitly considered

- **Construction-first vs organic layouts:** guaranteed solvability constrains how freeform terrain can feel; accepted because hand-tweaking restores character cheaply, while brokenness is expensive.
- **Reading constants from `src/` vs full standalone:** couples the tool to game source layout, accepted to prevent constant drift; the coupling surface is deliberately small (a constants-access module).

## CONTEXT.md entries added

- **Level generator** — the standalone offline tool; not part of the game.
- **Solution-first generation** — plan the solution, then realise the level; solvability by construction.
- **Puzzle rule** — a pluggable module encoding one puzzle pattern (requires/unlocks/placement/walkthrough steps).
- **Solution walkthrough** — the ordered human-readable completion steps emitted alongside each generated level.
- **Cage objective** — the game's completion spine: release all cages; the last opens the exit; all players exit.
