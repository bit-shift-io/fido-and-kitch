-- Hand-authored fixture mirroring the sandbox seam that motivated the
-- intent-carrying mount fix: an UP-leading column (A, x=[0,32]) whose bottom
-- rung ends flush at y=384 beside a DOWN-leading column (B, x=[32,64]) whose
-- top slab sits exactly at y=384. Standing on B's slab straddles A by a
-- 1px sliver -- pressing down must descend B, never drag onto A.
return {
  version = "1.11",
  luaversion = "5.1",
  tiledversion = "1.12.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 12,
  height = 20,
  tilewidth = 32,
  tileheight = 32,
  nextlayerid = 3,
  nextobjectid = 14,
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
          name = "seam_floor",
          type = "",
          shape = "rectangle",
          x = 0,
          y = 384,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 2,
          name = "safety_floor",
          type = "",
          shape = "rectangle",
          x = 0,
          y = 544,
          width = 384,
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
          name = "floor_spawn",
          type = "spawn",
          shape = "rectangle",
          x = 192,
          y = 512,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 4,
          name = "ladderA_1",
          type = "ladder",
          shape = "rectangle",
          x = 0,
          y = 224,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 5,
          name = "ladderA_2",
          type = "ladder",
          shape = "rectangle",
          x = 0,
          y = 256,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 6,
          name = "ladderA_3",
          type = "ladder",
          shape = "rectangle",
          x = 0,
          y = 288,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 7,
          name = "ladderA_4",
          type = "ladder",
          shape = "rectangle",
          x = 0,
          y = 320,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 8,
          name = "ladderA_5",
          type = "ladder",
          shape = "rectangle",
          x = 0,
          y = 352,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 9,
          name = "ladderA_6",
          type = "ladder",
          shape = "rectangle",
          x = 0,
          y = 384,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 10,
          name = "ladderB_1",
          type = "ladder",
          shape = "rectangle",
          x = 32,
          y = 416,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 11,
          name = "ladderB_2",
          type = "ladder",
          shape = "rectangle",
          x = 32,
          y = 448,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 12,
          name = "ladderB_3",
          type = "ladder",
          shape = "rectangle",
          x = 32,
          y = 480,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 13,
          name = "ladderB_4",
          type = "ladder",
          shape = "rectangle",
          x = 32,
          y = 512,
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
