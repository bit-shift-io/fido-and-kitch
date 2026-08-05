# TASKS — Switchable Component (switch-controlled props)

Grill findings in `NOTES.md` (section "Grill Notes — TODO List Review").

Scope: a shared `Switchable` component (`enabled` flag defaulting to true + a
`:switch(switch, user)` method) that a linked lever/pressure switch drives, so
teleporters and jump pads become unusable until switched on and a drawbridge
locks permanently open (2-way) while switched on. Only entities a switch is
linked to become switchable; everything else stays as-is. No disabled visual.

Run in order — each task depends on the previous. Verify each task with the
commands listed before moving on. New test files are registered in later
tasks; until then run them by path.

- [x] Task 1 — Switchable component unit test: create `tests/unit/switchable_test.lua`
      (headless; just `Class = Class or require('lib.hump.class')` +
      `local Switchable = require('src.components.switchable')`, no love, no
      EventBus clears). Assert:
      - `init` defaults `enabled == true` when `props.enabled` is nil; honours
        `props.enabled == false`.
      - `:switch({state='on'})` sets `enabled == true` and calls
        `onStateChange(true)`; `:switch({state='off'})` sets `enabled == false`
        and calls `onStateChange(false)`.
      - `:switch` forwards its `switch`/`user` args when invoking
        `onStateChange` (assert the received args).
      Use a stub `entity`/`onStateChange` captured via a local table, mirroring
      the `fakeSource` idiom in `tests/unit/sound_test.lua`.
      Verify: `./test-unit.sh tests/unit/switchable_test.lua` FAILS (module not
      found).

- [x] Task 2 — Create `src/components/switchable.lua`:
      `local Switchable = Class{}`; `init(props)` sets `self.type='switchable'`,
      `self.entity = props.entity`, `self.onStateChange = props.onStateChange`,
      `self.enabled = (props.enabled == nil) and true or props.enabled`;
      `function Switchable:switch(switch, user)` sets
      `self.enabled = (switch.state == 'on')` then calls
      `self.onStateChange(self.enabled)` if present (forwarding the original
      `switch`/`user` args). Follow the shape of `src/components/usable.lua`.
      Verify: `./test-unit.sh tests/unit/switchable_test.lua` PASSES.

- [x] Task 3 — Register the global: add `Switchable = require('src.components.switchable')`
      in `src/main.lua` next to `Usable = require('src.components.usable')`
      (line 63), and add `Switchable = Switchable or require('src.components.switchable')`
      to `tests/support/headless_bootstrap.lua` (idempotent, matches the
      existing globals block).
      Verify: full `./test-unit.sh` still passes (no behavior change).

- [x] Task 4 — Register the unit test: append `'tests/unit/switchable_test.lua',`
      to `tests/unit/run.lua` `defaultTestFiles`.
      Verify: full `./test-unit.sh` passes.

- [x] Task 5 — Wire teleport: in `src/entities/teleport.lua`, store the Usable
      as `self.usable = self:addComponent(Usable{ ... })` (currently discarded),
      then add `self:addComponent(Switchable{ entity = self, onStateChange =
      function(enabled) self.usable.enabled = enabled end })`. Existing behavior
      with no switch unchanged (default on).
      Verify: `./test-unit.sh` no regressions.

- [x] Task 6 — Wire jump pad: in `src/entities/jump_pad.lua`, same change —
      store `self.usable = self:addComponent(Usable{ ... })` and add the
      `Switchable` component with the same `onStateChange` wiring as Task 5.
      Verify: `./test-unit.sh` no regressions.

- [x] Task 7 — Wire drawbridge: in `src/entities/drawbridge.lua`, add
      `self.latchedOpen = false` in `init` and add the `Switchable` component
      (`onStateChange` sets `self.latchedOpen = enabled`). In `Drawbridge:update`
      (line 209), short-circuit when latched: if `self.latchedOpen` then force
      `self:setState('open')` (deck permanently solid, crossable both ways) and
      return without `checkHeld`; otherwise the existing hold FSM runs as today
      (one-way bridge).
      Verify: `./test-unit.sh tests/unit/drawbridge_test.lua` PASSES, then full
      `./test-unit.sh`.

- [x] Task 8 — Switch dispatch: in `src/entities/switch.lua` (lines 58-62) and
      `src/entities/pressure_switch.lua` (lines 160-165), replace the
      `if self.target.entity.switch then ... end` check with: find the
      `Switchable` component on the target
      (`local switchable = self.target.entity:getComponent(Switchable)`); if
      present call `switchable:switch(self, user)`; else fall back to the legacy
      `target.entity.switch` method (ladder's map-snippet hook still uses the
      method form). Preserve the existing `target == nil` guard.
      Verify: full `./test-unit.sh` passes, then
      `./test-integration.sh tests/integration/switch_sound_test.lua tests/integration/pressure_switch_test.lua`
      still pass.

- [x] Task 9 — Integration fixture: create `tests/fixtures/switchable_teleport_room.lua`
      (copy `teleport_room.lua`'s flat-floor/spawn/teleport-pair shape) with an
      extra `switch` object whose `properties.target = { id = <teleport A's id> }`.
      Verify: `./test-integration.sh tests/integration/harness_smoke_test.lua`
      still loads all fixtures (no fixture-load regression).

- [x] Task 10 — Integration test: create `tests/integration/switchable_teleport_test.lua`
      mirroring `tests/integration/switch_sound_test.lua` (GameHarness +
      FrameStepper + Queries): start the fixture map, find the switch and
      teleporter, assert the teleporter's `usable.enabled` is true before any
      switch use, call `switch:use(player)` → assert `enabled == false`, call
      `switch:use(player)` again → assert `enabled == true`. Register the file in
      `tests/integration/run.lua` `defaultTestFiles`.
      Verify: `./test-integration.sh tests/integration/switchable_teleport_test.lua`
      PASSES, then full `./test-integration.sh`.

- [x] Task 11 — Doc update: in `ARCHITECTURE.md`, add `Switchable` to the
      components list (line 46) and to the component descriptions (line 89-95
      block, next to `Usable`): "**`Switchable`**: gate an entity on/off driven
      by a linked switch's state (`:switch(switch, user)`, `enabled` default
      true)."
      Verify: `grep -n "Switchable" ARCHITECTURE.md` shows both additions.
