# Grill Notes — Story Entity (2026-08-05)

## Task

Pin down the `story` entity design (unimplemented, `TODO.md:9`, specced `CONTEXT.md:251-259`) before building `src/entities/story.lua`.

## Verified against code

- No `src/entities/story.lua` exists. `Map.typeIgnores = {'', 'spawn'}` → `story` is not ignored.
- Spec (`CONTEXT.md:251-259`): Tiled type `story`, `text` property (`\n` newlines), speech bubble on use, follows entity on screen, auto-dismiss on overlap end, re-trigger cooldown, player keeps full control.
- Interaction plumbing exists: `Player:checkForUsables` (`src/player/player.lua:152-168`) calls `world:queryOverlap(bounds)` with ±16px box around player, then `usable:canUse(user)`/`usable:use(user)`. Story entity needs a static sensor Collider + `Usable` component to piggyback. Runs every frame.
- `Usable` component (`src/components/usable.lua`) supports `use`/`canUse`/`enabled`; `use` logs, calls `useFunc(user)`.
- `Sound` component (`src/components/sound.lua`): `play(name)` warns-and-returns if `love.filesystem.getInfo(path) == nil` → wiring a not-yet-existing WAV is safe (Log.warn only). `res/snd/` has no story/dialogue asset.
- `res/img/default.png` (32×32) exists but is NOT needed — trigger is invisible.
- Text rendering precedent: `love.graphics.newFont(size)`, `love.graphics.getFont():getWidth()` (used in `game_hud.lua:134`, states). `love_mock` `newFont` returns `{}`; `getWidth` already added to mock fonts.
- Camera: pure math (`src/camera.lua`), `InGameState:draw` (`src/states/ingame_state.lua:213-233`) calls `camera:getDrawParams()` → `tx, ty, sx, sy`; `map:draw2(tx,ty,sx,sy)` + `map:drawEntities(tx,ty,sx,sy)` in world space, then `gameHud:draw()` in screen space. World→screen ≈ `(wx + tx) * sx`.

## Confirmed user answers

- **Trigger visual: NONE (superseded).** Initially "standard image, customisable, default png for now"; later answered the image question with "no image, text only." → Invisible trigger; no sprite. No default image asset needed.
- **Text wrapping: Designer breaks only.** `\n` only; no auto-wrap; bubble sizes to widest line. Designer must insert `\n` for long text; a long unbroken line could run off-screen.
- **Bubble styling: Simple rounded box.** Dark/light fill + game default font, positioned above entity with a small tail pointing at it, text centred; pure `love.graphics` primitives, no art asset.
- **Sound: Wire component, no asset.** Attach `Sound` with a `blip` key pointing at a not-yet-existing WAV (e.g. `res/snd/entity_story_blip.wav`). Safe: `Sound:play` warns-and-returns on missing file. No audible cue until asset added.
- **Re-trigger: 0.5s + toggle.** Use toggles bubble on/off (respecting 0.5s cooldown for re-open after a dismiss); moving away still auto-dismisses. Cooldown counts from dismissal.
- **Typewriter: ramp-up, locked in.** Per line: first ~4 chars letter-by-letter (~40 chars/sec), then word-by-word, then remaining slab drops in at once. Total ~0.5s to full reveal regardless of length. `use` mid-type reveals instantly (next press dismisses). NES-authentic opening but never laggy.
- **Render space: Screen space.** Bubble projected to screen each frame (follows entity through pan/zoom), text readable at any zoom incl. overview. Matches "UI overlay" wording.

## Design notes (implementation decisions)

- **Collider:** static sensor rectangle sized to the Tiled object (so `world:queryOverlap` in `Player:checkForUsables` finds it). `walkable` irrelevant.
- **Usable:** `Usable{use=...}`; `use(user)` toggles that user's per-player bubble state. Spec: one bubble per player per entity; both players can show bubbles simultaneously → track bubble state per player (key by player id/table), not a single boolean.
- **Overlap-end detection:** story entity must detect when its triggering player(s) no longer overlap to auto-dismiss. `Usable` has no overlap-end hook; poll `world:queryOverlap` per frame per active bubble's player, or track via sensor. Spec: "auto-hides when the triggering player's overlap ends."
- **Screen-space draw hook:** bubbles can't be drawn in `map:drawEntities` (world transform active). Need a draw pass after the camera transform (like `gameHud:draw()`): InGameState (or a story-bubble renderer) projects each active bubble's entity world position → screen via `tx,ty,sx,sy`, draws rounded box + tail + centered typewriter text. Likely iterate `map:getEntitiesByType('story')` or a registry of active bubbles.
- **Typewriter state:** per active bubble — line index, revealed char count, phase (letters/words/slab), timer. Reset on dismiss; `use` mid-type jumps to full.
- **`text` property:** read from `object.properties.text` in `init` (entity factory passes `object.properties` as props).
- Tests: unit-test typewriter reveal math and per-player bubble state via `tests/support/headless_bootstrap.lua` (ADR 0005) with `_internal` seam; bubble draw smoke-test with `love_mock` (has `love.graphics.print`, `getWidth`). Integration: overlap → use → bubble state, dismiss on move-away.

## Open questions

None remaining. Grilling complete.
