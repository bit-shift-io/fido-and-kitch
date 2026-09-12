# ADR 0007: Centred split line with centroid-anchored panes

**Status:** Accepted
**Date:** 2026-09-12

## Context
The Voronoi split-screen renders each player into a full-window canvas and composites the two with a screen-space shader. The shader was given the two players' projected positions as Voronoi sites and drew their perpendicular bisector.

Two problems followed. The sites came from the shared merged camera's projection while the canvases were drawn with the per-player cameras, so the two could disagree and a player could be rendered on the far side of the dividing line — off screen from their own point of view. And because each pane centred its player in the *full window* rather than in the half it actually occupies, the player drifted toward the line as it moved.

The bisector also wandered off screen centre whenever the shared camera was clamped at a map edge, whenever a dying player's respawn point was an extra framing target, and during any camera ease — producing lopsided halves for reasons that carry no information for the player.

## Decision
Pass the dividing **line** to the shader — a point and a unit normal in screen pixels — rather than two sites. `CameraManager` is the single owner of that geometry.

Pin the line to screen centre and let it only rotate, giving two equal halves. Model its position as a signed offset along the normal and ship that offset at zero, so a travelling line remains one function away.

Anchor each pane camera so its player renders at the **centroid of that player's region** — the half-plane on their side of the line, intersected with the screen rect. A region so formed is convex, and a convex region's centroid lies strictly inside it, so the player is contained by construction.

## Alternatives Considered
- **Keep sites, add centroid anchoring.** Reduces drift but cannot rule it out: the line and the canvases are still derived from different camera projections.
- **Sites = each player's drawn position on its own canvas.** Self-consistent, because a site always falls on its own side of its own bisector. Rejected as redundant once the line is passed explicitly, and it invites a fixed-point loop that the centroid property makes unnecessary.
- **True bisector with a floor on region area.** Keeps the honest Voronoi partition and a "who is further out" cue, at the cost of halves that resize for camera-framing reasons. Deferred rather than rejected; the offset scalar is the hook.

## Consequences
- Containment is a property of the geometry, not of tuning. No per-map threshold can break it.
- The shader no longer resembles the published Voronoi examples, including the reference doc this system was built from. A reader expecting two sites will not find them.
- With equal halves the partition is no longer a true Voronoi diagram of the players; the name is kept because the compositing model and the rotating angled divider are unchanged.
- The anchor moves as the line rotates and needs its own easing, which is one more thing that can be tuned wrong.
- Region geometry must handle a rect clipped to a triangle, quadrilateral or pentagon. A general convex-polygon centroid is required; per-shape special cases are a defect source.
