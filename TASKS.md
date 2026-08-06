# TASKS — Story Entity (speech bubble)

Grill findings in `NOTES.md` (section "Grill Notes — Story Entity").

Scope: a Tiled `story` entity — an **invisible** static-sensor hotspot with a
`text` custom property (`\n` = line break). Pressing `use` while overlapping
toggles a screen-space speech bubble above the entity for that player:
a simple rounded box + tail, centred text, game default font, **per-line NES
typewriter ramp** (first ~4 chars letter-by-letter at 40/s, then whole words
over 0.15s, then the full slab — ~0.25s/line, so ~0.5s for a typical bubble).
`use` mid-type reveals the rest instantly; the next `use` dismisses. Bubble
auto-dismisses when the triggering player's overlap ends. Re-trigger gated by
a **0.5s cooldown counted from dismissal**. Both players can show bubbles on
the same entity simultaneously (one per player). Player keeps full control.
`Sound` component wired with a `blip` key → `res/snd/entity_story_blip.wav`
(missing file is safe: `Sound:play` warns-and-returns). No sprite.

Run in order — each task depends on the previous. Verify each task with the
commands listed before moving on. New test files are registered in later
tasks; until then run them by path.

- [x] Task 1 — Unit test (Red): create `tests/unit/story_test.lua`
      (headless; `tests/support/headless_bootstrap` for the entity-level tier,
      like `tests/unit/drawbridge_test.lua`). Assert on `Story._internal`
      (private helpers the entity exposes to this file only):
      - `_internal.typewriter.revealedCount(line, t)`:
        `revealedCount(line, 0) == 1`; monotonic non-decreasing in `t`; caps
        at `#line`; equals `#line` once `t >= lineDuration(line)`
        (`LETTER_COUNT=4` / `LETTER_RATE=40` letter phase + `WORD_PHASE=0.15` word
        phase); a line shorter than 4 chars reveals by letter-rate only.
      - `_internal.typewriter.visibleText(lines, t)`: multi-line fixture — line 1
        full, line 2 partial, line 3 empty at an intermediate `t`; all full at
        total duration.
      - `_internal.cooldown.canShow(now, cooldownUntil)`: true when
        `cooldownUntil == nil`, false while `now < cooldownUntil`, true at/beyond.
      - Entity tier (real Story built via headless bootstrap, stub player
        entities with real Colliders in a real bump World): `init` wires a
        static sensor collider + `Usable` + `Sound{blip=...}` and reads
        `object.properties.text`; `use(player1)` shows a bubble for player1 only;
        both players show independently; `use` mid-reveal skips to full; next
        `use` dismisses and sets `cooldownUntil`; immediate re-`use` is blocked;
        stepping past 0.5s allows re-show; `_internal.playerOverlaps(...)`
        reflects collider overlap in the World.
      Verify: `./test-unit.sh tests/unit/story_test.lua` FAILS (module
      `src/entities/story` not found).

- [x] Task 2 — Create `src/entities/story.lua`:
      `local Story = Class{__includes = Entity}`; `Story:init(object, map)` calls
      `Entity.init(self, object, 'story')`, reads `self.text = object.properties.text or ''`,
      adds `Collider` (static sensor, `Rect.shapeArgs(object.width, object.height)`
      at `Rect.centreOfMapObject(object)`), `Usable{entity=self, use=...}` (toggle
      logic), and `Sound{sounds={blip='res/snd/entity_story_blip.wav'}}`. State:
      `self.bubbles = {}` keyed by the triggering player's table.
      - `Story:use(user)`: bubble not visible → show if `canShow(now, cooldownUntil)`
        (`revealElapsed = 0`, play `blip`); visible → if not fully revealed, reveal
        instantly (set `revealElapsed` past end), else dismiss
        (`cooldownUntil = now + 0.5`).
      - `Story:update(dt)`: advance each visible bubble's `revealElapsed`; auto-dismiss
        via `_internal.playerOverlaps` when the triggering player's overlap ends
        (`cooldownUntil = now + 0.5`).
      - `Story._internal` seam exposing `typewriter` (`revealedCount`,
        `visibleText`, `lineDuration`), `cooldown` (`canShow`), `playerOverlaps`,
        and bubble geometry helpers (box size given a `measure(line)` fn + padding,
        tail points, `screenPoint(wx,wy,tx,ty,sx,sy)`). Pure Lua, no love calls.
      Constants: `LETTER_COUNT=4`, `LETTER_RATE=40`, `WORD_PHASE=0.15`,
      `COOLDOWN=0.5`. Follow `src/entities/switch.lua`'s shape.
      Verify: `./test-unit.sh tests/unit/story_test.lua` PASSES.

- [x] Task 3 — Register the unit test: append `'tests/unit/story_test.lua',`
      to `tests/unit/run.lua` `defaultTestFiles`.
      Verify: full `./test-unit.sh` passes.

- [x] Task 4 — Integration fixture: create `tests/fixtures/story_room.lua`
      (copy `coin_room.lua`'s collision/floor + game/spawn shape) adding two
      `story` objects in the game layer within walking distance of spawn:
      `properties = { text = 'Hello!' }` and a second with
      `properties = { text = 'Line one\\nLine two' }`. Give each a distinct `id`
      and `name`. No tilesets (matches the fixture precedent).
      Verify: `./test-integration.sh tests/integration/harness_smoke_test.lua`
      still loads all fixtures (no fixture-load regression).

- [x] Task 5 — Integration test: create `tests/integration/story_test.lua`
      (GameHarness + FrameStepper + FakeInput + Queries, mirroring
      `tests/integration/key_test.lua`): start `tests/fixtures/story_room.lua`,
      step to settle, find the story entity via
      `Queries.findEntityByType(map, 'story')`, walk the player onto it with
      `holdFor`, press `use` → assert that player's bubble is visible
      (`story.bubbles[player].visible == true`); step a few frames → assert
      `revealElapsed > 0`; move the player away (`holdFor left`) → step → assert
      dismissed; return + `use` immediately → assert NOT re-shown (cooldown);
      `FrameStepper.step(game, 40)` (~0.67s) → `use` → assert shown again.
      Register the file in `tests/integration/run.lua` `defaultTestFiles`.
      Verify: `./test-integration.sh tests/integration/story_test.lua` PASSES,
      then full `./test-integration.sh`.

- [x] Task 6 — Screen-space draw hook: in `src/entities/story.lua` add
      `Story:drawBubbleScreen(tx, ty, sx, sy)` — for each visible bubble,
      project the entity's world position to screen
      (`_internal.bubble.screenPoint`), size the box from the **currently
      revealed** lines (via the injected default font measure), draw a rounded
      filled rect + border + tail triangle + centred white text using the
      `love.graphics` primitives (`rectangle`, `polygon`, `print`, `setColor`,
      `setFont`, `push`/`pop`). In `src/states/ingame_state.lua` `draw()` (after
      `map:drawEntities(tx, ty, sx, sy)`, before `self.gameHud:draw()`), loop
      `for _, story in ipairs(map:getEntitiesByType('story')) do
      story:drawBubbleScreen(tx, ty, sx, sy) end` (screen space, so bubbles
      follow the entity through pan/zoom and text stays readable at any zoom).
      Verify: `./test-unit.sh` no regressions; `./test-integration.sh
      tests/integration/story_test.lua` still PASSES.

- [x] Task 7 — E2E: create `tests/e2e/story_test.lua` (mirror
      `tests/e2e/harness_smoke_test.lua`): `GameHarness.startGame(
      'tests/fixtures/story_room.lua', {real = true})`, step, walk + `use`, step
      frames, `Capture.capture('story_bubble')`, assert the story bubble became
      visible and no error occurred. Register in `tests/e2e/run.lua` if it keeps
      a file list. Verify: `./test-e2e.sh tests/e2e/story_test.lua` (headed;
      skipped in CI).

- [x] Task 8 — Doc update: in `ARCHITECTURE.md` section 3.8 Map Entities, add
      `story` to the examples list and one line: "**`story`**: invisible
      trigger; shows a screen-space typewriter speech bubble on `use` (see
      CONTEXT.md 'Story entity')."
      Verify: `grep -n "story" ARCHITECTURE.md` shows the additions.
