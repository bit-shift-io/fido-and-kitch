# Tests

Run the fast headless Lua tests from the repository root:

```sh
./test.sh
```

The runner is dependency-free and exits non-zero if any test fails. You can also run a specific test file by passing it as an argument:

```sh
./test.sh tests/runner_smoke_test.lua
```

`test.sh` forwards its arguments to `lua tests/run.lua`.

These tests are intended for quick gameplay regression checks and should avoid launching a LÖVE window.
