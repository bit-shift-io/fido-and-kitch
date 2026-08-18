---
name: build-all
description: Autonomously executes ALL unchecked tasks in TASKS.md sequentially using strict TDD, updating TASKS.md and todowrite after each step.
---

# Autonomous Loop Directives (build-all)

## Core Directive
Work sequentially through `TASKS.md` from top to bottom. Do NOT pause or ask for user input between tasks. Proceed automatically until all items are marked `[x]`.

## Task Execution Loop

1. **Scan:** Read `TASKS.md`. Identify the first task marked `- [ ]`.
2. **Update UI:** Call `todowrite` to reflect remaining items and mark the active task in-progress.
3. **Red (Test First):**
   * Create or update the required test file.
   * Run the test command via `bash`. Verify it **fails**.
4. **Green (Implementation):**
   * Edit strictly necessary source code to satisfy the test.
   * Run the test command via `bash`. Verify it **passes**.
5. **Persist State:**
   * Edit `TASKS.md` and check off the item (`- [x]`).
   * Call `todowrite` to mark the task completed.
6. **Loop:** Immediately repeat from Step 1 for the next task.

## Completion
Stop ONLY when every single item in `TASKS.md` is marked `- [x]`. Provide a 2-line completion summary.
