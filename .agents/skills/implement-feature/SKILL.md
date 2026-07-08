---
name: implement-feature
description: Implement a planned feature using vertical-slice test-driven development, working from `.scratch/feature-name/` docs (PRD, DECISIONS, HANDOFF, issues) produced by the `plan-feature` skill. Use whenever the user wants to build, code, or implement a feature that has already been planned, or says things like "start implementing X", "let's build the feature we planned", "work through the issues for Y", "begin coding the feature", "TDD this feature", or asks to pick up planned work from `.scratch/`. Also trigger when the user references planned issues or a HANDOFF doc and wants to start writing code.
---
 
# Implement Feature
 
Implement a feature using vertical-slice TDD, with all context and requirements loaded from `.scratch/` planning docs. Each issue is confirmed with the user before implementation begins.
 
## When to use this skill
 
Trigger when the user wants to implement a feature that has already been planned. Common surface phrasings:
 
- "let's start building [feature]"
- "implement the [feature] we planned"
- "work through the issues in `.scratch/feature-name/`"
- "TDD this feature"
- "pick up the planned work"
- "start coding the next slice"
Skip this skill if there is no `.scratch/feature-name/` for the feature — that means it hasn't been planned yet. In that case, suggest running the `plan-feature` skill first, or ask the user to point you at the planning docs if they live somewhere else.
 
## Quick Start
 
1. Ask the user which feature to implement (or pick the only one in `.scratch/` if there's one).
2. Load all docs from `.scratch/feature-name/`.
3. **FOR EACH ISSUE IN SEQUENCE:**
   - Preview the issue (what to build, acceptance criteria, affected files)
   - Ask: "Ready to start this issue?"
   - **WAIT FOR EXPLICIT USER APPROVAL BEFORE CODING** ← MANDATORY CHECKPOINT
   - Only if user approves: implement using TDD
   - Show results and ask: "Looks good?"
   - Once approved: mark `Status: done`
   - **STOP AND REPEAT FOR NEXT ISSUE** ← Do not skip ahead or batch issues
4. After all issues complete and approved: end-to-end verification.

**CRITICAL:** Do not implement multiple issues without stopping to ask for user approval after each one. Each issue is a checkpoint where the user can redirect, catch mistakes, or change direction.

## Workflow
 
### Phase 1: Load Context
 
Read these files first, in this order:
 
- `.scratch/feature-name/HANDOFF.md` — implementation order, architecture summary, gotchas
- `.scratch/feature-name/PRD.md` — requirements & spec
- `.scratch/feature-name/DECISIONS.md` — rationale & constraints
- Any ADRs in `docs/adr/` linked from HANDOFF
- `docs/CONTEXT.md` if it exists, otherwise `CONTEXT.md` at project root — domain terminology
If any of these are missing, surface that — don't proceed with an incomplete picture. Missing DECISIONS in particular is a red flag: it usually means trade-offs weren't captured, and you'll re-litigate them mid-implementation.
 
### Phase 2: Issue-by-Issue Implementation

⚠️ **MANDATORY WORKFLOW: Preview → Ask Approval → Implement → Verify → Repeat**

Work through `.scratch/feature-name/issues/` in dependency order (respecting each issue's `Blocked by` field). **You must preview and get explicit approval for EACH issue before implementing.** Do not skip or batch this step.

**Step 1: Preview & Confirm (MANDATORY — STOP HERE UNTIL APPROVED)**
 
- Show the user the issue: what to build, acceptance criteria, affected files
- Ask: "Ready to start this issue?"
- **WAIT FOR EXPLICIT APPROVAL** before moving to Step 2
- If the user says anything other than clear approval (e.g., "make this change first" or "wait, I need to think about this"), do not proceed — address their feedback first
- If user says "yes" or "ready" or equivalent: proceed to Step 2

**Why this matters:** Skipping this checkpoint means you can spend an hour building the wrong thing because the planning doc was slightly stale, the user changed their mind, or your understanding of the requirement is wrong. This is the only guaranteed checkpoint to catch those issues.
 
**Step 2: Plan Before Coding**
 
- Discuss public interfaces (what should the API look like from a caller's perspective?)
- Identify critical behaviours to test
- Map out a test strategy — which slice of behaviour gets the first test?
- **Custom hook/wrapper check:** If the HANDOFF references method calls on custom hooks or wrappers, read the hook source before writing any tests or code. Custom wrappers frequently shadow or redefine methods from the underlying library — assuming the API matches the library docs leads to hard-to-debug test failures. Look for spread patterns like `{ ...libraryResult, customMethod }` where `customMethod` overrides a library method of the same name.
**Step 3: Tracer Bullet (First Test)**

- **Test runner check:** Before running tests for the first time, check `package.json` scripts to find the correct test command and any required flags or env vars (e.g. `NODE_OPTIONS`, `--runInBand`, test group flags). Never assume `npm test` or a bare test-runner invocation is correct — the project may require specific configuration to run at all.
- **Deferred-test check:** If the planning issue says "Test approach: Covered by issue N" or similar, do NOT silently skip TDD. Flag it explicitly: "This issue defers tests to issue N — should I write tests inline here anyway, or follow the planning doc?" Wait for the user to decide before proceeding.
- Write ONE test for the first observable behaviour
- Run it — it should fail (RED)
- Write the minimal code to pass (GREEN)
- **Fixture realism check:** Before marking GREEN, verify your test fixture reflects the actual production input format — not a sanitised version that sidesteps the hard case. Ask: does the real input have special encoding, wrapping, escaping, or structural quirks that the code must handle? If so, the fixture must include them. Common traps: using plain strings when real data is encoded (base64, CDATA, URL-encoded), using flat structures when real responses are nested, or omitting optional fields that the code branches on. A test that passes on a simplified fixture but fails on real data is worse than no test: it gives false confidence and delays discovering the bug until production.
**Step 4: Incremental Loop (Remaining Behaviours)**
 
- Write the next test → it fails
- Write minimal code to pass → it passes
- Repeat until all acceptance criteria are met
- No speculative features. No anticipating future tests.
**Step 5: Refactor (Only After All Tests Pass)**
 
- Extract duplication
- Deepen modules (push complexity behind simple interfaces)
- Apply SOLID where it falls out naturally
- Run tests after each refactor step — if they break, you went too far
**Step 6: Verification & Mark Complete (STOP UNTIL USER CONFIRMS)**
 
- Show the user the test results and any coverage delta
- If it's a TypeScript project, run type-check and confirm no errors
- Ask: "Looks good?" and **WAIT FOR USER APPROVAL**
- If user says "yes"/approves: Update the issue file: change `Status: pending` to `Status: done`
- If user says "no" or asks for changes: Go back to Step 3 (Tracer Bullet) and refine
- **ONLY AFTER USER CONFIRMS THIS ISSUE IS COMPLETE: Move to the next issue**
The `Status: done` update is the contract back to `plan-feature` and to anyone reviewing progress — keep the field exactly as written.

**DO NOT PROCEED TO THE NEXT ISSUE WITHOUT EXPLICIT USER APPROVAL ON THIS ONE.**
 
### Phase 3: End-to-End Verification
 
Once all issues are complete:
 
- Verify the full feature works end-to-end (not just unit-tested in isolation)
- Manual test in the running app — UI should be exercised in a browser/simulator, not just via tests
- Check coverage meets the project standard (if there's an ADR or convention saying e.g. 100% line coverage, enforce it)
- **CI-only failures:** if a CI/CD step (build, lint, deploy) fails in a way that doesn't reproduce locally, reproduce it in an environment matching CI (e.g. the same container image) before changing anything. Guessing at a fix from the error message alone risks a push-fix-push-fix cycle; reproducing first turns it into a single, verified fix.
- **Docs-touching issues:** if the issue creates or edits permanent documentation, grep it for references to ephemeral planning directories (`.scratch/`, `tmp/`, or similar). Those directories get deleted once the phase closes — no permanent doc should depend on a path inside one. Either remove the reference or migrate the referenced content into the permanent doc first.

### Phase 4: Retrospective

After end-to-end verification, ask:

> "Would you like to review the conversation to see if we can extract any improvements — to the skills, CLAUDE.md, CONTEXT.md, ADRs, or other project docs — so that future features require less back-and-forth?"

If the user says yes:
- Review the full conversation for: corrections the user made, things you got wrong first time, conventions you had to be told, back-and-forth that could have been avoided with better upfront context
- Group findings into categories:
  - **Skill improvements** — changes to `plan-feature` or `implement-feature` SKILL.md (e.g. a missing step, a checkpoint that should exist). **Skill changes must be general — applicable to any project, not just this one.** Strip out project-specific details; capture only the underlying principle.
  - **Project conventions** — additions to `frontend/CLAUDE.md`, `backend/CLAUDE.md`, or root `CLAUDE.md`
  - **Domain knowledge** — additions or corrections to `docs/CONTEXT.md`
  - **Architecture decisions** — new ADRs in `docs/adr/` (only when the three-condition gate is met: hard to reverse, surprising without context, genuine trade-off)
  - **Memory** — facts worth persisting across future sessions
- Present the proposed changes to the user before writing anything
- Apply the ones the user approves, to both the user-level skill files (`~/.claude/commands/`) and the repo-level copies (`.claude/commands/`) if both exist

The goal is compounding improvement: each feature implementation leaves the project better documented than it found it, so the next one requires less human guidance.

## TDD Philosophy
 
### Core Principle: Test Behaviour, Not Implementation
 
Tests should verify behaviour through public interfaces, not implementation. Code can change entirely; tests shouldn't.
 
**Good tests** are integration-style: they exercise real code paths through public APIs. They describe WHAT the system does, not HOW. A good test reads like a specification — "user can checkout with valid cart" tells you exactly what capability exists. These tests survive refactors because they don't care about internal structure.
 
**Bad tests** are coupled to implementation. They mock internal collaborators, test private methods, or verify through external means (e.g. querying a database directly instead of using the interface). The warning sign: your test breaks when you refactor, but the behaviour hasn't changed.
 
### Characteristics of Good Tests
 
- Tests observable behaviour (what callers actually care about)
- Uses public API only
- Survives internal refactors without breaking
- Describes WHAT, not HOW
- One logical assertion per test
- Reads like a specification
### Characteristics of Bad Tests
 
- Mocks internal collaborators
- Tests private methods
- Asserts on call counts or call order
- Breaks when refactoring without behaviour change
- Test name describes HOW, not WHAT
- Verifies through external means instead of the interface
### Example: Good vs Bad
 
```typescript
// BAD: Tests implementation details
test("checkout calls paymentService.process", async () => {
  const mockPayment = jest.mock(paymentService);
  await checkout(cart, payment);
  expect(mockPayment.process).toHaveBeenCalledWith(cart.total);
});
 
// GOOD: Tests observable behaviour
test("user can checkout with valid cart", async () => {
  const cart = createCart();
  cart.add(product);
  const result = await checkout(cart, paymentMethod);
  expect(result.status).toBe("confirmed");
});
```
 
### Another Example: Interface vs Bypass
 
```typescript
// BAD: Bypasses interface to verify
test("createUser saves to database", async () => {
  await createUser({ name: "Alice" });
  const row = await db.query("SELECT * FROM users WHERE name = ?", ["Alice"]);
  expect(row).toBeDefined();
});
 
// GOOD: Verifies through interface
test("createUser makes user retrievable", async () => {
  const user = await createUser({ name: "Alice" });
  const retrieved = await getUser(user.id);
  expect(retrieved.name).toBe("Alice");
});
```
 
### Anti-Pattern: Horizontal Slices
 
Do not write all tests first and then all implementation. That is "horizontal slicing" — treating RED as "write all the tests" and GREEN as "write all the code."
 
This produces bad tests:
 
- Tests written in bulk test *imagined* behaviour, not *actual* behaviour
- You end up testing the *shape* of things (data structures, function signatures) rather than user-facing behaviour
- Tests become insensitive to real changes — they pass when behaviour breaks, fail when behaviour is fine
- You outrun your headlights, committing to test structure before you understand the implementation
Correct approach: vertical slices via tracer bullets. One test → one piece of implementation → repeat. Each test responds to what you learned from the previous cycle.
 
```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5
 
RIGHT (vertical):
  RED→GREEN: test1→impl1
  RED→GREEN: test2→impl2
  RED→GREEN: test3→impl3
  ...
```
 
## Interface Design for Testability
 
Good interfaces make testing natural.
 
### 1. Accept Dependencies, Don't Create Them
 
```typescript
// Testable
function processOrder(order, paymentGateway) {}
 
// Hard to test
function processOrder(order) {
  const gateway = new StripeGateway();
}
```
 
### 2. Return Results, Don't Produce Side Effects
 
```typescript
// Testable
function calculateDiscount(cart): Discount {}
 
// Hard to test
function applyDiscount(cart): void {
  cart.total -= discount;
}
```
 
### 3. Small Surface Area
 
Fewer methods = fewer tests needed. Fewer params = simpler test setup. If you need many params, that's a hint the abstraction is wrong.
 
## Deep Modules
 
From *A Philosophy of Software Design*:
 
**Deep module** = small interface + lots of implementation (the goal).
 
```
┌─────────────────────┐
│   Small Interface   │  ← Few methods, simple params
├─────────────────────┤
│                     │
│ Deep Implementation │  ← Complex logic hidden
│                     │
└─────────────────────┘
```
 
**Shallow module** = large interface + little implementation (avoid).
 
```
┌─────────────────────────────────┐
│        Large Interface          │  ← Many methods, complex params
├─────────────────────────────────┤
│  Thin Implementation            │  ← Just passes through
└─────────────────────────────────┘
```
 
When designing interfaces, ask: can I reduce the number of methods? Can I simplify the parameters? Can I hide more complexity inside?
 
## When to Mock
 
Mock at **system boundaries** only.
 
**Do mock:**
 
- External APIs (payment, email, third-party services)
- Databases (sometimes — prefer a test DB)
- Time and randomness
- File system (sometimes)
**Don't mock:**
 
- Your own classes or modules
- Internal collaborators
- Anything you control
If you find yourself mocking your own code to test your own code, the design has a problem — usually a missing seam or a shallow module.
 
### Designing for Mockability
 
At system boundaries, design interfaces that are easy to mock.
 
**1. Use dependency injection**
 
```typescript
// Easy to mock
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}
 
// Hard to mock
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```
 
**2. Prefer SDK-style interfaces over generic fetchers**
 
```typescript
// GOOD: Each function is independently mockable
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  getOrders: (userId) => fetch(`/users/${userId}/orders`),
  createOrder: (data) => fetch('/orders', { method: 'POST', body: data }),
};
 
// BAD: Mocking requires conditional logic inside the mock
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```
 
The SDK approach means each mock returns one specific shape, no conditional logic in test setup, easier to see which endpoints a test exercises, and type safety per endpoint.
 
## Refactor Candidates
 
After a TDD cycle, look for:
 
- **Duplication** → extract function/class
- **Long methods** → break into private helpers (keep tests on the public interface)
- **Shallow modules** → combine or deepen
- **Feature envy** → move logic to where the data lives
- **Primitive obsession** → introduce value objects
- **Existing code** that the new code reveals as problematic
## Test File Organisation

Place test files in `__tests__` subdirectories co-located with their source module, not in a top-level `tests/` directory:

```
✓ src/mcps/google-docs-mcp/__tests__/
  - config.unit.test.ts
  - install.unit.test.ts

✓ src/prerequisites/1password/__tests__/
  - check.unit.test.ts
  - install.unit.test.ts

✓ src/__tests__/
  - integration.integration.test.ts   ← spans multiple modules

✗ tests/
  - config.test.ts   (wrong — not co-located, no type suffix)
```

**File naming:**
- Unit tests: `.unit.test.ts` (TypeScript) / `.unit.test.js` (JavaScript) — tests a single module in isolation, all external dependencies mocked
- Integration tests: `.integration.test.ts` / `.integration.test.js` — tests how multiple modules compose, or tests against built output / real external processes
- Match the source language of the project — `.ts` for TypeScript projects, `.js` for JavaScript-only projects

**What goes where:**
- Single-module tests with mocked deps → `__tests__/` inside that module's directory
- Multi-module composition tests → `src/__tests__/` (or the closest shared parent)
- Post-build smoke tests (import from `dist/`) → project-root `tests/` directory (they can't be co-located with source)

**Vitest config:** Projects should run unit and integration tests separately (`test:unit`, `test:integration`) and together (`test`) via named vitest projects or include patterns. The combined `test` script is what CI uses.

If a project has chosen a different convention, surface the inconsistency rather than silently picking sides.
 
## Status Tracking
 
As each issue completes:
 
- Open `.scratch/feature-name/issues/0X-*.md`
- Change `Status: pending` to `Status: done` (exact spelling — downstream tooling parses it)
- This is the handoff record: anyone reviewing progress reads the issue files
## Checklist Per Cycle
 
```
[ ] Test describes behaviour, not implementation
[ ] Test uses public interface only
[ ] Test would survive an internal refactor
[ ] Code is minimal for this test
[ ] No speculative features added
[ ] Tests pass
[ ] Coverage is adequate
[ ] Type-check passes (if TypeScript project)
```
 
## Opting Out of Approval Checkpoints

**Default behavior:** I will ask for your approval before EACH issue (this is mandatory by default).

**If you want me to skip approval prompts:** You can explicitly tell me at any point:
- "Continue without asking me for approval on each issue" 
- "Just implement all remaining issues"
- "No more checkpoints for this feature"

This must be an explicit, clear instruction from you. I will not infer or assume this from context.

**If you want to re-enable checkpoints:** Simply say "Go back to asking for approval before each issue" and I will resume the checkpoint workflow.

## What to Avoid
 
- Writing all tests upfront (horizontal slicing)
- Anticipating future tests
- Mocking internal functions or private methods
- Adding speculative features
- Refactoring while tests are RED
- Testing implementation details instead of behaviour
- Refactoring before reaching GREEN
- **Implementing multiple issues without stopping for user approval between each one**