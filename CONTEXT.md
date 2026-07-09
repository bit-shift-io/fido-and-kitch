# Glossary

## Fast gameplay regression test

**Definition** — A headless Lua test that checks gameplay decisions or math quickly without launching a graphical LÖVE game.

**Boundary** — These tests are for fast feedback on logic regressions. They are not visual tests, full map-loading tests, or packaging tests.

## Testability seam

**Definition** — A small extracted function or module that lets existing behavior be tested without broad runtime mocks.

**Boundary** — A seam should preserve runtime behavior and stay narrowly focused. It is not a broad refactor away from the project's current global-oriented architecture.
