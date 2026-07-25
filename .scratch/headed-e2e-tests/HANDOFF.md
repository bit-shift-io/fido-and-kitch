# Handoff: Headed E2E Tests and Frame Capture

## Summary

The integration harness runs fully headless against a `love.*` mock, so a failing gameplay test yields only a line of text — you cannot see what happened. This feature adds a third test tier that runs the same scripted, deterministic scenarios under the **real LÖVE runtime** with a real window and real rendering, so a scenario can be watched while it runs and can capture frames to image files. Those images are the point: a human can eyeball them and an AI agent can read them, neither needing to have been present when the test ran.

The suite is reorganised into three tiers — `tests/unit/`, `tests/integration/`, `tests/e2e/` — sharing one set of support modules (`tests/support/`) and fixture maps (`tests/fixtures/`), with a command per tier plus a CI-aware `./test-all.sh`. A test belongs to exactly one tier; there is no running the same file both ways. The existing headless suite is untouched behaviourally and stays just as fast.

The payoff slice is the drawbridge crossing (issue 07). Its spatial acceptance criteria — the deck turning solid before the player reaches the gap so no fall occurs, and a wrong-side approach staying blocked — are currently deferred to a manual `love . drawphysics map=drawbridge_fixture.lua` run, which is why drawbridge issue 03 sits marked as blocked on repro-ability. This feature is what makes that check automated and reviewable.

## Suggested Implementation Order

1. **01-tier-restructure** — everything depends on it, and it's pure move-and-repoint with no new behaviour. Landing it first means the riskier work starts from a clean layout. Watch the known pre-existing `tests/camera_test.lua` failure: confirm the same single failure before and after, and don't let the move mask or multiply it.
2. **02-headed-runner** — the big one, and where all the real unknowns live (getting LÖVE to run a test file, driving frames from the engine's own update callback, shimming input in front of real LÖVE, reporting three outcomes back to the shell). Prove it with the trivial smoke scenario before layering anything on top.
3. **04-explicit-frame-capture** — do this before 03/05/06. It carries the feature's load-bearing assumption (writing an image to an arbitrary project path from inside LÖVE), and both 05 and 06 build directly on its writer. Verify that assumption before building the API on it.
4. **03-realtime-pacing-flag**, **05-capture-on-failure**, **06-filmstrip-capture** — all small and mutually independent once 02 and 04 are in. Order among them is free; take them in whatever order suits.
5. **07-drawbridge-headed-scenario** — last, since it consumes everything above and is the acceptance demo for the whole feature.

## Links

- [PRD.md](PRD.md)
- [DECISIONS.md](DECISIONS.md)
- [issues/01-tier-restructure.md](issues/01-tier-restructure.md)
- [issues/02-headed-runner.md](issues/02-headed-runner.md)
- [issues/03-realtime-pacing-flag.md](issues/03-realtime-pacing-flag.md)
- [issues/04-explicit-frame-capture.md](issues/04-explicit-frame-capture.md)
- [issues/05-capture-on-failure.md](issues/05-capture-on-failure.md)
- [issues/06-filmstrip-capture.md](issues/06-filmstrip-capture.md)
- [issues/07-drawbridge-headed-scenario.md](issues/07-drawbridge-headed-scenario.md)
- No ADR was created. The significant choices here (three tiers, real-LÖVE e2e, capture-not-baseline) are all reversible at modest cost and are recorded in DECISIONS.md; none clears the hard-to-reverse + surprising + genuine-trade-off gate. The closest candidate — putting test-awareness into the production entry point (Q11) — is a small, easily-undone coupling rather than a one-way door.

## Gotchas / Implementer Notes

- **Verify the capture-write path before building on it (issue 04).** LÖVE's filesystem writes are normally confined to a save directory, so writing an image to an arbitrary path in the project tree is the feature's load-bearing assumption. The likely route is encoding the frame's image data in memory and writing it out through plain Lua file I/O rather than the engine's write API. Note the existing screenshot handler in `src/game.lua` (the F12 path) passes an absolute path directly to the engine's capture call — do not assume that pattern actually works as intended; check it rather than copying it.
- **Locating the LÖVE binary.** Follow `run.sh`'s existing logic: prefer `bin/love.AppImage` if present, else `love` on PATH. On macOS the Homebrew cask install may not put `love` on PATH at all (it lands inside the app bundle), so the discovery step needs to cope with that. Decide and document what happens when no binary is found outside CI — the CI case is handled by the `CI` skip, but a local developer with no LÖVE installed still needs a clear message rather than a confusing failure.
- **Real rendering means real assets.** The headless mock returns fake images for everything; under real LÖVE, actual image files must load. Expect asset-path and missing-file problems to surface in the e2e tier that the integration tier never saw. Note `lib/` is gitignored and may be empty in a fresh clone (`./setup.sh` populates it).
- **STI's graphics module decides its behaviour once, at require time**, from whether `love.graphics` exists (`lib/sti/graphics.lua` sets `isCreated` at load). Under real LÖVE it will take the real path, including tileset image caching and canvas creation that the headless run skipped entirely. `Map:resize()` also currently skips canvas creation when no window exists — under a real window it won't, so that path runs for the first time in tests.
- **The input shim must sit in front of real LÖVE's own implementations.** `Player:isDown` reads `love.joystick.getJoysticks()` and `love.keyboard.isDown` directly. If any input path bypasses the shimmed surface, a watched scenario will drift from its headless equivalent — worth checking explicitly during issue 02 rather than trusting it.
- **Determinism must survive pacing (issue 03).** Keep the simulated timestep fixed regardless of pacing mode; the flag should only control whether the runner waits between frames. The test for this is comparing final gameplay state across both modes, not just that both passed.
- **Three outcomes, not two.** Pass, fail, and cancelled are distinct. Window-close is cancelled and must not mark outstanding tests failed — easy to get wrong if cancellation is implemented as an error.
- **Announce every skip.** `./test-all.sh` skipping the e2e tier in CI must print that it did. A silently skipped tier reads as "everything passed" when a third of the suite never ran.
- **Keep the headless tier untouched behaviourally.** Issue 01 changes its file paths and imports only; no test logic changes. `./test-integration.sh` should stay exactly as fast as it is today.
- **Don't drift into visual regression.** Captures are debugging artifacts, gitignored, never diffed against baselines. Assert that images exist and are non-trivial; asserting on image *content* is explicitly out of scope and would pull in baseline management and platform rendering differences.
- **Docs to update as you go**, not at the end: `tests/README.md` (three tiers, four commands, capture location) and `AGENTS.md` (its Commands section currently documents `./test.sh`, which issue 01 renames). Neither should reference anything inside `.scratch/` — that directory is deleted once this feature ships.
