-- Hand-authored fixture map for the door entity (see
-- tests/fixtures/flat_ground.lua for the same precedent and why these are
-- edited as Lua directly rather than round-tripped through Tiled). No
-- tileset/tile layer is used -- only object layers -- which sidesteps STI's
-- tileset image-caching path entirely.
--
-- Layout (20x12 tiles, 640x384px), walking surface at y=224:
--
--   spawn    switch            door            push_box
--     v        v                v                  v
--   ....................................................    y=192  <- door occupies this row
--   ####################################################    y=224  <- walking surface
--   ####################################################
--
-- The door object spans x=288..320, y=192..224 -- one tile standing ON the
-- surface, so its barrier (a thin strip centred at x=304) rises above the
-- walking surface rather than lying flush with it, which would resolve as a
-- walkable step rather than a wall (see tests/README.md's physics gotchas).
--
-- The near side (spawn, switch) is deliberately kept clear of props: a box
-- parked between the player and the door would be what stopped them, and a
-- test that cannot tell the two apart proves nothing about the door. The
-- push_box therefore sits on the FAR side at centre x=496, and the
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
          name = "door",
          type = "door",
          shape = "rectangle",
          x = 288,
          y = 192,
          width = 32,
          height = 32,
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
