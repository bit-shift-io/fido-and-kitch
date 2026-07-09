Status: done

# Add custom Lua test runner

## What to build

Create a small dependency-free test runner that can execute fast Lua unit tests from the repository root. The runner should provide enough assertion helpers for the initial gameplay tests and should produce clear pass/fail output.

After this slice, a developer can run one command and see whether the fast test suite passes.

## Files to create/modify

- `tests/run.lua`
- `tests/README.md` or README/agent docs if documenting immediately

## Test approach

Manual verification is sufficient for the runner itself:

- Add one temporary/passing sample test while building, or include a minimal self-test if useful.
- Confirm the runner exits `0` when tests pass.
- Confirm the runner exits non-zero when a test fails.

## Acceptance criteria

- [ ] `tests/run.lua` exists and can be run from the repository root.
- [ ] The runner loads test files deterministically.
- [ ] The runner supports basic assertions such as equality and truthiness.
- [ ] Passing tests print concise success output.
- [ ] Failing tests print the failing test name and message.
- [ ] The runner exits non-zero on failure.
- [ ] No external Lua test framework is required.

## Blocked by

None — can start immediately.
