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
- **Why:** Matches the repo; can `require` game source for ground-truth constants (tile size, walk/climb speeds) instead of duplicating numbers that drift.
- **Alternatives considered:** Python (rejected: every gameplay constant duplicated by hand, guaranteed drift).

### Q8: Entity palette timing
**Decision:** Design for the full palette including pushables, pressure switches, and enemies. Those features will ship in the game **before** this tool is implemented.
- **Why:** Surfaced during grill: the glossary documents them but `src/` does not contain them yet — they are designed-not-shipped.
- **Implication:** This feature is **blocked on** pushables/pressure-switch/enemies landing. The rule library absorbs later props without core changes.
**Update (2026-08-08):** Resolved — `src/entities/push_box.lua`, `boulder.lua`, `pushable_prop.lua`, `pressure_switch.lua`, `npc_spider.lua`, `npc_robot.lua` all exist now. Issues 06/07/08 are unblocked.

### Q9: Objective model (from code, confirmed by user)
**Decision:** Colored keys unlock matching cages; each cage releases a bird ally that follows a generated polyline path and may perform actions (e.g. flick a switch) before exiting; the exit door's `actor_count` variable counts down as birds exit; releasing the last cage opens the door; all players exiting ends the level.
- **Why:** This is the game's actual completion mechanic (`cage.lua`, `exit_door.lua`, `bird.lua`).
- **Implication:** The generator authors bird path objects and `object:exec` event snippets, exactly as hand-made maps do.

### Q10: Size and difficulty dials
**Decision:** `--size small|medium|large` (roughly 20×15 up to ~60×40 tiles) and `--difficulty 1..5` scaling cage count, chain depth, hazard and enemy density together; bigger maps generally mean more complexity.
- **Why:** Matches existing bite-sized levels while allowing growth; one coherent dial beats many fiddly ones for v1.

### Q11: Playtest loop / export
**Decision (superseded 2026-08-08):** Emit `.tmx` only. No Tiled CLI, no `.lua` export step.
- **Why:** Original decision assumed STI only loads `.lua`; the user corrected this mid-implementation — the game now loads `.tmx` directly (`src/map/init.lua` calls `Tmx.parse()` then `sti()` when the path ends in `.tmx`). The Tiled-export subsystem this decision originally called for (CLI detection, `export.lua`, degrade-without-Tiled warning) is unnecessary.
- **Implication:** `tools/level_generator/export.lua` and Tiled-binary detection are dropped from the file structure. `love . map=generated/<name>.tmx` is the playtest command, not `.lua`.

### Q16: Dressing uses the real `background` property, not gradient/cloud_spawner (2026-08-08)
**Decision:** Generated levels set the map's `background` property to one of the three real pre-authored options (`res/backgrounds/night_forest.tmx`, `mushroom_cave.tmx`, `sky.tmx` — `src/map/init.lua` loads whichever is named). No gradient, cloud_spawner, or wind objects are emitted.
**Why:** CONTEXT.md's glossary documents "Gradient object", "Cloud spawner", and "Wind" as implemented features, but grepping `src/` for `gradient`/`cloud_spawner`/`windX` turns up nothing — no entity, no renderer, no handling anywhere. `entity_factory.lua` fails a `require` for any unrecognised object `type` and just logs an error (not a crash), so authoring these objects wouldn't break a generated level, but it would spam error logs for props that render as nothing — worse than the "bland is fine" baseline. Same shape as Q8/Q13/Q14: a doc describing a mechanic that isn't actually wired up.
**Implication:** Dressing is scoped down to what actually renders: the `background` property (a real, working three-way choice) plus coins and enemies (both real, shipped entities).

### Note: NPC entities don't reliably set self.name/self.type (found 2026-08-08, not fixed)
`src/npc/npc_base.lua`'s `NPCBase:init(props, tiledObject)` only gets a real `tiledObject` when the subclass forwards it — `npc_spider.lua`/`npc_robot.lua`/`npc_bird.lua` all call `NPCBase.init(self, merged)` with just one argument, so `tiledObject` is always nil, and `Entity.init` ends up called with the merged config table instead of the real Tiled object — `self.name` is therefore always nil and `self.type` always defaults to `'entity'`. `NPCRegistry.spawn` does reliably set `npc._typeName`, which is what `tests/integration/level_generator_dressing_test.lua` uses to count spawned enemies instead of `Map:getEntitiesByType`/`Queries.findEntityByType`. Left unfixed — out of this feature's scope — but it's the same root cause as the pre-existing spider integration test failures (see the 16-failure baseline noted throughout this doc).

### Q15: Coop dial needs a real gate, so the Switchable seam landed after all (2026-08-08)
**Decision:** Added the small seam declined in Q14, but scoped to `teleport.lua` only: `object.properties.enabled` now forwards into both `Usable{enabled=...}` and `Switchable{enabled=...}` at construction (previously hardcoded to always start enabled). `--coop required` builds a walled-off "vault" entirely beyond the layout's own width (`tools/level_generator/coop.lua`) — structurally unreachable by walking/climbing — containing one objective's key+cage, entered only through a teleport gated `enabled=false` by default and driven by a momentary pressure plate placed far away (ground zone) targeting it.
**Why:** Issue 06's acceptance criteria requires a puzzle a lone player genuinely cannot complete, verified programmatically — issue 04's non-gating flourishes couldn't satisfy that. Asked the user again specifically for this issue; they approved the seam this time (Q14's flourish-only answer was scoped to issue 04, not a blanket refusal).
**Implication:** Solvability is by construction, not a graph solver: `pressure_switch.lua` is momentary by default (`nextActivation` follows weight presence every frame, no latch), so the plate deactivates the instant its weight leaves — a lone player physically cannot be on the distant plate and at the teleport simultaneously. `tests/unit/teleport_start_disabled_test.lua` and `tests/integration/switchable_teleport_test.lua`'s existing "starts enabled" case both confirm the change is backward-compatible (every existing map authors no `enabled` property, so nothing changes for them).
**Alternatives considered:** A dependency-graph single-agent-vs-two-agent solver (rejected: unnecessary — the vault's structural unreachability plus the plate's momentary release already prove unsolvability, matching the project's "solvable by construction, no post-hoc checker" philosophy from Q3).

### Q14: No real blocking-gate rule this pass (scope correction, 2026-08-08)
**Decision:** Rules are optional, non-gating flourishes (switch-disables-teleport-shortcut, switch-disables-jump-pad-hop), never required to complete the level. No Layout changes, no source changes.
**Why:** Checked `Switchable`'s real targets (`teleport.lua`, `jump_pad.lua`, `drawbridge.lua`, `pressure_switch.lua`): none forward an `enabled`/start-disabled option from Tiled object properties into their `Switchable{...}` construction — they always start `enabled=true`. So nothing can be authored as "closed until switched" from map data alone; a real gate would need a small source change (forwarding `object.properties.enabled` into `Switchable`). Asked the user: build the source seam to make gating real, or ship non-gating flourishes instead. They chose the latter, to avoid scope creep beyond the tool itself.
**Implication:** `switch:use()` toggling a target's `Switchable.enabled` still does something real (it can turn an always-on teleport/jump-pad off, then back on) — that's what the two shipped rules use. Neither rule ever sits on the only path to an objective, so `--coop optional`-style solo completability isn't affected by whether the player touches any switch.
**Alternatives considered:** Forwarding `object.properties.enabled` into `Switchable` for teleport/jump_pad (small, backward-compatible source seam) — rejected for this pass per user direction, worth revisiting if a future feature wants real switch-gated puzzles.

### Q13: The exit opens on "all cages unlocked", not a bird/actor_count countdown (correction, 2026-08-08)
**Decision:** Generated cages release a bird purely as flavour (matches current game behaviour: `cage.lua` spawns it and sets `actor:setTarget(user)`, making it follow the releasing player). No polyline path, no `object:exec` snippet, no reliance on `actor_count`. The exit opens automatically once every cage has been used.
**Why:** Checked the actual win-condition code at implementation start: `src/states/ingame_state.lua` counts cages on load, listens for each cage's `cage_unlocked` event, and once all are unlocked emits `all_cages_unlocked`, which `src/entities/exit_door.lua` listens for directly and opens on (`ExitDoor:onAllCagesUnlocked` → `self:open()`). The `actor_count` `Variable` and `ExitDoor:exitInstant`/`exitThroughDoor` (the mechanic PRD/HANDOFF/earlier decisions described — birds decrementing a counter, last one opens the door) are never called anywhere in the codebase. `cage.lua`'s `path` object property (present in `sandbox.tmx`) is also read by nothing. This is the same shape as Q8: docs described a mechanic that isn't actually wired up.
**Implication:** Issue 03's planner only needs to place keys and matching cages in reachable zones; solvability is "every key and cage reachable, keys placed independent of cage state" (no zone is gated by cage/key state yet, so ordering is automatically satisfied). The walkthrough describes key→cage steps ending in "all cages used, exit opens automatically" rather than routing a bird to the door. `actor_count` is still emitted (as 0, matching the "open immediately" convention from issues 01/02) but is understood to be inert authored data, not a live mechanic.
**Alternatives considered:** Implementing real path-following + `object:exec` firing on the bird NPC in `src/`, so the docs' original mechanic becomes real. Rejected for this feature: out of PRD's stated scope ("the game codebase stays untouched except possibly small testability seams for constants"), and not needed since the actual win condition already works without it.

### Q12: Movement model has no jump (correction, 2026-08-08)
**Decision:** The movement model's reachability graph is walk-adjacency within a zone plus ladder edges between zones. No bare gap crossing exists in v1 (issue 02); jump pads, drawbridges, and pushables extend reachability in their own later issues (05/07/08).
**Why:** Earlier drafts of this doc and the PRD assumed a player jump ("max jump height/distance"). Checked `src/player/player_states.lua`, `player_movement.lua`, `player.lua` at implementation start: there is no jump input, impulse, or state anywhere in the codebase. Player traversal is only walking (falls off ledges under gravity) and ladder climbing; jump pads launch the player along an authored polyline path via `Usable`, not a physics jump.
**Implication:** Issue 02's movement model and every later issue that reasons about reachability must use ground+ladder connectivity, not jump arcs. Gaps without a ladder (or a later-issue bridge) are simply not part of the layout.

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
