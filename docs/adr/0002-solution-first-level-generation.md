# ADR 0002: Solution-first level generation with a modular puzzle-rule library

**Status:** Accepted
**Date:** 2026-07-15

## Context

Levels are hand-authored in Tiled and expensive to produce. A standalone generator tool will emit complete, playable levels for designers to hand-tweak. The central risk of generated puzzle levels is unsolvability: with keys behind their own cages' doors, boxes that must reach holes, and momentary switches far from what they gate, it is easy to emit levels that look right but cannot be finished. A second, slower-burning risk is architectural: the game's prop vocabulary grows steadily (pushables, pressure switches, and enemies are landing next), and a generator whose puzzle logic is woven through its core would need surgery for every new prop.

## Decision

1. **Solvability is guaranteed by construction.** The generator first builds an abstract solution plan — an ordered dependency graph of objectives (key → cage → bird action → … → exit) assigned to connected zones — then realises terrain around that plan using a conservative reachability model derived from the game's real movement constants, then decorates. There is no post-hoc solvability checker; the plan *is* the proof, and it is emitted as a human-readable solution walkthrough beside each level.
2. **Puzzle patterns are pluggable rule modules.** Each pattern (lever-opens-door, pressure-switch-held-by-partner, box-fills-hole, bird-flicks-switch, …) is one self-contained module with a uniform interface: requirements, effects, expansion into terrain/entities, and contributed walkthrough steps. Co-op-required generation works by choosing rules that spatially separate interdependent elements under a two-agent plan.

## Alternatives Considered

- **Generate freely, then validate and reject.** Rejected: a correct solvability checker for two-agent pushable-prop puzzles is substantially harder than constructing solutions, and an incorrect one silently ships broken levels.
- **Human as validator (catch broken levels while hand-tweaking).** Rejected: quietly converts "playable" into "probably playable" and spends designer time on exactly the failure the tool exists to prevent.
- **Monolithic generator with hard-coded puzzle logic.** Rejected: every new game prop would require core changes; a rule library makes new props additive.

## Consequences

- Every emitted level is completable, and the walkthrough makes playtesting fast.
- Layouts are shaped by the plan, so raw output can feel constructed rather than organic; hand-tweaking is the intended remedy and stays cheap because tweaks rarely break the solution spine.
- The movement model must stay conservative and honest to `src/` constants; if it overpromises (claims an impossible jump), the by-construction guarantee is void. This is the invariant to protect with tests.
- New puzzle mechanics require writing a rule module before the generator can use them; until then, generated levels simply don't contain that prop.
- The generator is coupled (narrowly) to game source for constants — an accepted cost to prevent drift between the model and real physics.
