-- Hand-authored fixture map for the blocker entity (see
-- tests/fixtures/flat_ground.lua for the same precedent and why these are
-- edited as Lua directly rather than round-tripped through Tiled). No
-- tileset/tile layer is used -- only object layers -- which sidesteps STI's
-- tileset image-caching path entirely.
--
-- Layout (20x12 tiles, 640x384px), walking surface at y=224:
--
--   spawn    switch          blocker          push_box
--     v        v                v                  v
--   ....................................................    y=160  <- blocker object top
--   ....................................................    y=192
--   ####################################################    y=224  <- walking surface
--   ####################################################
--
-- The blocker object is authored the way Tiled tile objects are (see
-- Rect.centreOfMapObject): bottom-anchored, object y = the gate's bottom
-- edge. It spans x=288..320, y=160..224 -- a 64px gate (32x64, matching
-- the blocker.tx template) standing ON the surface at y=224. Its barrier
-- (a thin strip centred at x=304) stretches from the floor up, so it
-- overlaps a walking player's body column and reads as a wall -- flush
-- with the surface it would resolve as a walkable step rather than a wall
-- (see tests/README.md's physics gotchas).
--
-- The near side (spawn, switch) is deliberately kept clear of props: a box
-- parked between the player and the blocker would be what stopped them, and
-- a test that cannot tell the two apart proves nothing about the blocker.
-- The push_box therefore sits on the FAR side at centre x=496, and the
-- box-blocking test repositions a player out there to shove it leftward
-- into the same barrier.
return {
  version = "1.11",
  luaversion = "5.1",
  tiledversion = "1.12.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 20,
  height = 12,
  tilewidth = 32,
  tileheight = 32,
  nextlayerid = 3,
  nextobjectid = 6,
  properties = {},
  tilesets = {},
  layers = {
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 1,
      name = "collision",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {
        ["collision"] = true
      },
      objects = {
        {
          id = 1,
          name = "floor",
          type = "",
          shape = "rectangle",
          x = 0,
          y = 224,
          width = 640,
          height = 64,
          rotation = 0,
          visible = true,
          properties = {}
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 2,
      name = "game",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      objects = {
        {
          id = 2,
          name = "spawn",
          type = "spawn",
          shape = "rectangle",
          x = 64,
          y = 192,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 3,
          name = "push_box",
          type = "push_box",
          shape = "rectangle",
          x = 480,
          y = 160,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["allowPushWhenStoodOn"] = false
          }
        },
        {
          id = 4,
          name = "blocker",
          type = "blocker",
          shape = "rectangle",
          x = 288,
          y = 224,
          width = 32,
          height = 64,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 5,
          name = "switch1",
          type = "switch",
          shape = "rectangle",
          x = 128,
          y = 224,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["target"] = { id = 4 }
          }
        }
      }
    }
  }
}
