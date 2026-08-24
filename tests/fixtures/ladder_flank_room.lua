-- Hand-authored fixture reproducing "pressing left/right near the top of a
-- flanked ladder teleports the player onto the platform": a single column
-- whose volume is [128,160]x[192,352], flanked by solid walls
-- ([96,128] and [160,192]) whose tops sit at y=240 -- well below the volume
-- top (192). Climbing beside the walls must never side-slide through them;
-- sliding only carries the player across once their feet are above y=240.
return {
  version = "1.11",
  luaversion = "5.1",
  tiledversion = "1.12.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 12,
  height = 13,
  tilewidth = 32,
  tileheight = 32,
  nextlayerid = 3,
  nextobjectid = 10,
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
          y = 352,
          width = 384,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 2,
          name = "left_wall",
          type = "",
          shape = "rectangle",
          x = 96,
          y = 240,
          width = 32,
          height = 112,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 3,
          name = "right_wall",
          type = "",
          shape = "rectangle",
          x = 160,
          y = 240,
          width = 32,
          height = 112,
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
          id = 4,
          name = "air_spawn",
          type = "spawn",
          shape = "rectangle",
          x = 136,
          y = 160,
          width = 16,
          height = 16,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 5,
          name = "ladder_1",
          type = "ladder",
          shape = "rectangle",
          x = 128,
          y = 224,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 6,
          name = "ladder_2",
          type = "ladder",
          shape = "rectangle",
          x = 128,
          y = 256,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 7,
          name = "ladder_3",
          type = "ladder",
          shape = "rectangle",
          x = 128,
          y = 288,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 8,
          name = "ladder_4",
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
          id = 9,
          name = "ladder_5",
          type = "ladder",
          shape = "rectangle",
          x = 128,
          y = 352,
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
