-- Side-entry repro map: player 1 spawns on a left ledge whose top sits one
-- tile above a ladder column's top plane; walking right off the ledge drops
-- them straight into the column band from the SIDE while holding right --
-- the exact shape of the reported bug (walk off a platform into a ladder
-- while steering). Player 2 spawns on the floor beside the column base.
return {
  version = "1.11",
  luaversion = "5.1",
  tiledversion = "1.12.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 12,
  height = 14,
  tilewidth = 32,
  tileheight = 32,
  nextlayerid = 3,
  nextobjectid = 8,
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
          y = 416,
          width = 384,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 2,
          name = "ledge",
          type = "",
          shape = "rectangle",
          x = 0,
          y = 352,
          width = 120,
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
          id = 3,
          name = "ledge_spawn",
          type = "spawn",
          shape = "rectangle",
          x = 40,
          y = 320,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 4,
          name = "floor_spawn",
          type = "spawn",
          shape = "rectangle",
          x = 200,
          y = 384,
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
          x = 128,
          y = 320,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 6,
          name = "ladder1",
          type = "ladder",
          shape = "rectangle",
          x = 128,
          y = 352,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 7,
          name = "ladder1",
          type = "ladder",
          shape = "rectangle",
          x = 128,
          y = 384,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 8,
          name = "ladder1",
          type = "ladder",
          shape = "rectangle",
          x = 128,
          y = 416,
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
