Status: pending

# Drawbridge crossing as a headed scenario

## What to build

The drawbridge mechanic's spatial acceptance criteria stop depending on someone launching the game by hand. A contributor (or an AI agent) can run one command and get both a pass/fail verdict and images of the approach, the opening deck, and the completed crossing.

This is the payoff slice — the case that motivated the whole feature. The drawbridge's criteria "the deck becomes solid before the player reaches the gap (no fall)" and "a wrong-side approach does not open the bridge" were explicitly deferred to a manual `love . drawphysics map=drawbridge_fixture.lua` run, because the headless harness can neither show nor capture the crossing.

Concretely, after this issue:

- A headed scenario drives a player from the correct side of the existing drawbridge fixture map, across the gap, asserting the player reaches the far side without dying or falling into the pit.
- A second scenario drives a player at the bridge from the wrong side and asserts they stay blocked — the bridge does not open and they do not cross.
- Both scenarios capture named frames at the meaningful moments: the approach, the opening transition, the fully open deck, and the completed (or blocked) outcome.
- Assertions are on gameplay state via the shared query helpers — position across the gap, no death, bridge state — with captures as supporting evidence, so the test fails on behaviour rather than on appearance.

## Files to create/modify

- tests/e2e/drawbridge_test.lua — new: the correct-side crossing and wrong-side blocked scenarios with their captures
- tests/support/queries.lua — extend if the existing helpers don't cover reading drawbridge state or detecting that a player died/fell
- .scratch/drawbridge/issues/03-open-on-correct-side.md — update its status note: its deferred manual verification is now covered by an automated headed test

## Test approach

The scenarios are themselves the tests, but they must fail for the right reasons. Assert observable gameplay state — the player's position having crossed the gap, no death having occurred, the wrong-side player still on the near side — never the drawbridge component's internals, which the existing unit tests already cover directly.

The no-fall criterion is the sharp one and needs care: a scenario that only checks the final position could pass while the player fell into the pit and respawned back onto solid ground. Assert explicitly that no death or respawn occurred during the crossing, not just where the player ended up.

Cover the timing criterion the manual run existed to check: the deck must be solid *before* the player reaches the gap. A test that walks the player slowly enough would pass even with a late-opening deck, so drive the approach at normal walk speed and assert continuous support across the gap rather than only the end state.

Confirm the captured images actually show the three moments they claim to — that is the artifact a human or agent will rely on when this test goes red, and a mislabelled or blank capture would be worse than none.

Cross-check against the existing headless drawbridge unit tests: this scenario should cover what they cannot (real collision timing, real crossing) and should not duplicate the pure state-machine assertions they already make.

## Acceptance criteria

- [ ] A headed scenario drives a player across the drawbridge from the correct side and asserts they reach the far side.
- [ ] The scenario asserts no death, fall, or respawn occurred during the crossing.
- [ ] The deck is solid before the player reaches the gap, asserted at normal walk speed rather than by walking slowly enough to hide a late open.
- [ ] A second scenario asserts a wrong-side approach leaves the player blocked and the bridge closed.
- [ ] Both scenarios capture named frames at the approach, opening, open, and outcome moments, and the images show those moments.
- [ ] Assertions go through shared query helpers, not drawbridge internals.
- [ ] The drawbridge issue's status note records that its manual verification is now automated.

## Blocked by

04-explicit-frame-capture (needs named captures), which itself needs 02-headed-runner.
