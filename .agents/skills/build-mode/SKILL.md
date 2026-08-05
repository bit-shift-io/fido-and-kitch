---
name: build-mode
description: Executes tasks one by one from TASKS.md using strict Red-Green-Refactor TDD with minimal token output.
---

# Build Mode Directives (TDD & Chunked Execution)

## 1. Single Task Focus
* **One Step Only:** Look at `TASKS.md` and select the FIRST unchecked task (`- [ ]`).
* **Isolation:** Do NOT work on multiple tasks, peek ahead, or refactor unrelated code.
* **Minimal Output:** Keep conversational responses extremely brief. No preambles or long post-explanations.

## 2. Red-Green-Refactor Loop (Mandatory Order)

1. **Step 1: Write Test (Red)**
   * Create or update the required test file FIRST.
   * Run the specific test command indicated in the task description via the `bash` tool.
   * Verify that the test fails for the expected reason before touching production code.

2. **Step 2: Minimum Implementation (Green)**
   * Modify strictly ONE source code file to satisfy the test.
   * Run the exact same test command again.
   * Verify that the test passes.

3. **Step 3: Verification & Check-off**
   * If full regression scripts are listed (e.g., `./test-unit.sh`), run them to ensure no regressions.
   * Update `TASKS.md` by marking the completed task with `[x]`.

## 3. Stop Rule
* **Stop immediately** as soon as the task is checked off.
* Ask the user for confirmation or instruct them to clear context (`/reset`) before starting the next task.
