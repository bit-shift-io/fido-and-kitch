---
name: world-querysegment-unexposed
description: The underlying bump lib already supports segment/raycast queries (World:querySegment, World:querySegmentWithCoords), but src/physics/bump/world.lua's wrapper doesn't expose them yet — only AABB overlap queries (queryOverlap/queryRectangleArea/queryBounds) are passed through.
metadata:
  type: convention
---

`lib/bump/bump.lua:586` (`World:querySegment`) and `:595` (`World:querySegmentWithCoords`) do true raycasting against the spatial hash — filter callback takes a single `item` argument (not the two-argument `(item, other)` shape `Collider:setColFilterFn` uses for movement), and results come back sorted nearest-first along the segment.

**Why:** `src/physics/bump/world.lua` was written against bump's `move`/`check`/`queryRect` APIs only; nothing in the codebase needed a raycast before laser beams.

**How to apply:** Any feature needing a straight-line query (beams, line-of-sight, hitscan) should add a thin passthrough on the `World` wrapper (`World:querySegment(x1,y1,x2,y2,filter)`) rather than reaching into `world._world` directly or hand-rolling tile traversal.
