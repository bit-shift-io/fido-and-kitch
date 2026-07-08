---
name: plan-feature
description: Design a software feature end-to-end before implementation — grill out requirements, produce a PRD, break the work into vertical-slice issues, and capture the rationale in `.scratch/`. Use whenever the user wants to plan, spec, scope, or design a feature, write a PRD, break work into tickets/issues, or "think through" something before building. Trigger on phrasings like "plan this feature", "spec out X", "let's design Y", "break this down into tickets", "write a PRD", "what's the architecture for", "I want to think this through", or any request to organise requirements before coding starts.
---
 
# Plan Feature
 
Design a feature from requirements through issue breakdown, with all documentation saved to `.scratch/` for handoff to the `implement-feature` skill.
 
## When to use this skill
 
Trigger when the user wants to design or plan a feature before writing production code. Common surface phrasings:
 
- "plan this feature" / "let's design X" / "spec out Y"
- "write a PRD" / "draft the requirements"
- "break this into issues" / "split this into tickets"
- "what's the architecture for…"
- "I want to think this through before I build it"
- "let's scope this out properly"
Skip this skill for bug fixes, small refactors, or one-off scripts — they don't need the scaffolding and the overhead gets in the way.
 
## Quick Start
 
1. Ask the user to describe the feature.
2. Grill on requirements, edge cases, and constraints — one question at a time.
3. Ask: "Is there anything else, or are you happy for me to start writing the documentation?" Loop until the user explicitly clears you to proceed.
4. Produce `.scratch/feature-name/`:
   - `PRD.md` — complete requirements & spec
   - `DECISIONS.md` — grill Q&A and rationale
   - `HANDOFF.md` — implementation order & architecture summary
   - `issues/01-*.md` … `issues/0N-*.md` — vertical-slice issues, each starting with `Status: pending`
5. Update `CONTEXT.md` inline as domain terms resolve.
6. Create ADRs in `docs/adr/` only when the three-condition gate (below) is met.
7. Close by telling the user the exact command to paste into a new chat.
If the project has no `.scratch/`, `CONTEXT.md`, or `docs/adr/` yet, create them as needed. `.scratch/` lives at the project root; `CONTEXT.md` goes in `docs/` if that directory exists, otherwise at the project root; ADRs live in `docs/adr/`. Don't ask permission — these are the conventions this skill assumes, and committing to them early is part of the value.
 
## Workflow
 
### Phase 1: Grill Session
 
Ask one question at a time. Wait for the answer before the next question. Cover:
 
- Requirements and user flow
- Edge cases and error scenarios
- Constraints (performance, compliance, deadlines)
- Design decisions (UX, architecture, API surface)
- Dependencies on existing systems
The reason for one-at-a-time is that each answer changes which question makes sense next. Batching questions makes the user answer vague high-level ones and miss the sharp follow-ups — you end up with a PRD that looks complete but is hollow.
 
If `docs/CONTEXT.md` exists, load it; otherwise check for `CONTEXT.md` at project root. Challenge terminology against it. If the user uses a term that means something different in this project's glossary, surface the conflict — don't paper over it. Update the glossary inline as terms resolve; don't batch updates to the end (they get forgotten or sloppily written).

### Phase 1.5: Readiness Check (MANDATORY — loop until cleared)

Before writing any documentation, ask:

> "Is there anything else, or are you happy for me to start writing the documentation?"

**Wait for the response. Do NOT start writing docs yet.**

- If the user raises anything new — answer it, address it, ask any necessary follow-up questions, then ask the readiness question again.
- If the user says "yes", "go ahead", "proceed", "write it", "start", "that's everything", or similar confirmation — proceed to Phase 2.
- If the response is ambiguous — treat it as a new point and respond to it before asking again.

**The purpose of this loop:** The user often thinks of something right after pressing Enter. A single pause isn't enough — the loop ensures they've had enough time to surface everything before documentation is locked in. Keep looping until the user explicitly clears you to proceed. Never infer clearance from silence or a short reply.

### Phase 2: Write the PRD
 
Save to `.scratch/feature-name/PRD.md`. Use this exact structure:
 
```
# [Feature Name]
 
## Problem Statement
[The problem the user faces, from their perspective.]
 
## Solution
[The solution, from the user's perspective.]
 
## User Stories
1. As an <actor>, I want a <feature>, so that <benefit>
2. As an <actor>, ...
[Be extensive — a long list is better than a short one. Cover happy paths and edge cases.]
 
## Implementation Decisions
- Modules built or modified
- Interfaces and their signatures
- Architectural decisions
- Schema changes
- API contracts
 
## Testing Decisions
- What makes a good test for this feature (external behaviour, not implementation)
- Which modules will be tested
- Prior art (similar tests already in the codebase)
- File naming: unit tests use `.unit.test.ts` (TypeScript) or `.unit.test.js` (JavaScript); integration tests use `.integration.test.ts` / `.integration.test.js` — match the source language of the project
- File location: co-locate in `__tests__/` inside the module directory; multi-module tests go in the nearest shared `__tests__/`; post-build smoke tests (importing from `dist/`) are the only exception that belongs in a top-level `tests/` directory
 
## Out of Scope
[Explicitly what is NOT being built.]
 
## File Structure (if relevant)
[Layout of new directories/files.]
 
## Acceptance Criteria
- [ ] Must-have behaviour 1
- [ ] Must-have behaviour 2
 
## References
[Links to ADRs, glossary entries, legacy code, prior PRDs.]
```
 
Do not include specific file paths or code snippets in the PRD — they go stale fast and turn the doc into a maintenance liability. Exception: if a prototype produced a snippet that precisely encodes a decision (state machine, schema, type shape), inline it and note it came from a prototype. Keep snippets to decision-rich parts only.
 
### Phase 3: Capture Decisions
 
Save to `.scratch/feature-name/DECISIONS.md`. Capture each grill Q&A with rationale:
 
```
### Q1: API endpoint
**Decision:** Use `/api/endpoint`
- **Why:** Existing endpoint already used by legacy app
- **Implication:** No client-side transformation needed
- **Alternatives considered:** New `/v2/endpoint` — rejected because legacy clients can't migrate this quarter
```
 
Also capture:
 
- Key assumptions
- Trade-offs explicitly considered
- Updated `CONTEXT.md` entries (just the new terms, with definitions)
The point of this file is so that six months from now, someone (including future-you) can reconstruct *why* the feature looks the way it does, without re-running the grill.
 
### Phase 4: Issue Breakdown
 
Break the work into **vertical-slice issues** — narrow but complete paths through every layer (schema → API → UI → tests), each demoable on its own. Horizontal slices (e.g., "all the schemas first", "all the components") produce piles of half-done plumbing and nothing shippable until the very end.
 
Vertical slice rules:
 
- Each slice cuts end-to-end through all relevant layers
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones — granularity is cheap, regret is expensive
#### Issue file format
 
Save each as `.scratch/feature-name/issues/0N-short-name.md`:
 
```
Status: pending
 
# [Short title]
 
## What to build
[End-to-end behaviour for this slice. Describe what the user or caller can do after this is done, not which files change.]
 
## Files to create/modify
- path/to/file.ts
- path/to/other.tsx
 
## Test approach
[Which behaviours to test, how to verify the slice works.]
 
## Acceptance criteria
- [ ] Behaviour 1
- [ ] Behaviour 2
 
## Blocked by
[Issue numbers this depends on, or "None — can start immediately".]
```
 
The `Status: pending` line at the top is a contract with the `implement-feature` skill, which flips it to `Status: done` as each slice completes. Keep the field exactly as written — downstream tooling parses it literally.
 
#### Checkpoint: Confirm breakdown with user
 
Before finalising issues, present the proposed list and ask the user explicitly:
 
- Does the granularity feel right (too coarse / too fine)?
- Are the dependency relationships correct?
- Should any slices merge or split?
- Are the blockers accurate?
Iterate until the user approves the list. Skipping this step produces issues that look fine on paper but don't match what the user actually wants to demo or ship first.
 
### Phase 5: Update Project Docs
 
#### CONTEXT.md
 
Add new domain terms as they resolve during the grill. Each entry:
 
- **Definition** — how the term is used in this project
- **Boundary** — what it is and isn't
Only add terms meaningful to domain experts. Don't couple to implementation details — those go stale and turn `CONTEXT.md` into a junk drawer. Update inline as terms resolve, not in a batch at the end.
 
If `CONTEXT.md` doesn't exist yet, create it in `docs/` if that directory exists, otherwise at the project root. Use a `# Glossary` header and start adding entries.

**Never link permanent docs into `.scratch/`.** `.scratch/feature-name/` is ephemeral — it gets deleted once the feature ships. If `CONTEXT.md`, an ADR, or any other doc outside `.scratch/` needs something from the grill (an assumption, a rationale, a data point), copy the substance into the permanent doc rather than pointing at `DECISIONS.md` or `HANDOFF.md` by path. The same applies to `implement-feature` when it later updates these docs.
 
#### docs/adr/
 
Create an ADR only when **all three** are true:
 
1. **Hard to reverse** — changing your mind later has meaningful cost.
2. **Surprising without context** — a future reader will ask "why did they do it this way?"
3. **Result of real trade-off** — genuine alternatives existed and you picked one for reasons.
If any one is missing, skip the ADR — log it in `DECISIONS.md` instead. ADRs are expensive to maintain, so the gate is what keeps them valuable. A repo full of low-stakes ADRs trains everyone to ignore them.
 
Format:
 
```
# ADR 000N: Title
 
**Status:** Accepted
**Date:** YYYY-MM-DD
 
## Context
[Background and the problem.]
 
## Decision
[What was decided and why.]
 
## Alternatives Considered
[Other options and why they were rejected.]
 
## Consequences
[Implications, including downsides.]
```
 
If `docs/adr/` doesn't exist, create it. Link each ADR from `HANDOFF.md` and from any issue it constrains.
 
### Phase 6: Write the Handoff
 
Save to `.scratch/feature-name/HANDOFF.md`. This is what the `implement-feature` skill reads first, so make it usable on its own:
 
- Short summary of the feature (1–2 paragraphs)
- Suggested implementation order (which issues first, why)
- Links to PRD, DECISIONS, and any ADRs
- Anything implementer-specific (gotchas, test setup quirks, known external blockers)

### Phase 7: Close

After writing all docs, close with this message (substituting the real feature directory name):

> All planning docs are saved. In a new chat, run:
> `/implement-feature .scratch/feature-name/`

This gives the user a single line they can cut and paste to kick off implementation in a fresh context.

## Directory Structure
 
```
.scratch/feature-name/
├── PRD.md
├── DECISIONS.md
├── HANDOFF.md
└── issues/
    ├── 01-short-name.md     # Status: pending
    ├── 02-short-name.md     # Status: pending
    └── 0N-short-name.md     # Status: pending
```
 
## Philosophy
 
- **One question at a time.** Each answer changes the next question. Batching loses sharpness.
- **Challenge terminology.** If the glossary says X means Y but the user seems to mean Z, name the conflict early — it's much cheaper to resolve before the PRD is written than after.
- **Update docs as you go.** `CONTEXT.md` and `DECISIONS.md` get sloppy or forgotten when batched.
- **Sparse with ADRs.** The three-condition gate is what keeps them worth reading.
- **Vertical slices.** Each issue is a complete path through all layers, not a layer unto itself.
- **Concrete examples.** Use specific scenarios to probe edge cases — abstract questions get abstract answers.
- **Cross-reference with code.** If the user states how something works, check the code agrees. Surface contradictions before they make it into the PRD.
 