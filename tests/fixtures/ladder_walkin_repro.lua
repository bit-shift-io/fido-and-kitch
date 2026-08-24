-- Walk-in side-entry repro map (user-reported bug): column A (x 0..32) has a
-- 3-tile ladder; column B (x 32..64) is a single ground block at the bottom
-- unit with the spawn on top. Walking LEFT off the block drops the player
-- into the ladder's midpoint from the side -- flush edge, no gap.
-- Rung objects are bottom-anchored (y = rung's bottom edge), so rungs at
-- 96/128/160 give volume [0..32]x[64..160] with top slab band [64..72];
-- the block top (y=128) is level with the ladder's middle.
return {
  version = "1.11",
  luaversion = "5.1",
  tiledversion = "1.12.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 6,
  height = 5,
  tilewidth = 32,
  tileheight = 32,
  nextlayerid = 3,
  nextobjectid = 7,
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
          name = "ground_block",
          type = "",
          shape = "rectangle",
          x = 32,
          y = 128,
          width = 32,
          height = 32,
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
          name = "block_spawn",
          type = "spawn",
          shape = "rectangle",
          x = 40,
          y = 96,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 7,
          name = "p2_spawn",
          type = "spawn",
          shape = "rectangle",
          x = 48,
          y = 96,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 3,
          name = "ladder1",
          type = "ladder",
          shape = "rectangle",
          x = 0,
          y = 96,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 4,
          name = "ladder1",
          type = "ladder",
          shape = "rectangle",
          x = 0,
          y = 128,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 5,
          name = "ladder1",
          type = "ladder",
          shape = "rectangle",
          x = 0,
          y = 160,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        }
      }
    }
  }
}
