# ADR 0006: Instant raycast-chain laser beams

**Status:** Accepted
**Date:** 2026-09-02

## Context

Laser props need a beam that can bounce off mirrors, be blocked by moving obstacles (doors, drawbridges, moving platforms, pushable props), and destroy boulders/destructible tiles — all of which can change state frame to frame. The feature request calls for the beam to travel "very fast."

## Decision

Resolve the beam as an instant raycast chain, recomputed from scratch every frame: cast a segment from the emitter, classify what it hits, and if it's a correctly-facing mirror, cast the next segment from there, repeating up to a fixed bounce cap. The full path (all bounces) is known within a single frame — "very fast" is implemented as literally instantaneous, not a fast-but-finite travel speed.

## Alternatives Considered

- **Finite-speed traveling projectile**: the beam head advances at a large px/s value across multiple frames before reaching full extension. Rejected — adds a stateful projectile-position system, and edge cases around retracting the beam when the laser turns off mid-flight or a mirror's state changes while the beam is still in transit. No gameplay requirement calls for the beam to be visibly "in flight."

## Consequences

- Every frame independently answers "where does this beam currently reach and what does it hit" with no memory of the previous frame's path — consistent with how `blocker`/`drawbridge`/`pressure_switch` already recompute their own state fresh every frame (see their own DECISIONS.md/NOTES.md discussions of why memory-based flags caused bugs).
- The beam cannot be "faster" or "slower" as a tunable — only its power-up telegraph (a separate state machine) has any visible timing.
- If a future feature genuinely needs a visibly traveling beam (e.g. a slow charging cannon), it is a different mechanism, not a variant of this one.
