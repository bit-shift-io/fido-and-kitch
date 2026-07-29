-- Hand-authored fixture map for the boulder's momentum roll: a long flat run
-- with a wall at the left end and a one-tile hole at the right, so a boulder
-- can be shoved either way and meet a different stop condition.
-- See tests/fixtures/flat_ground.lua for why these are edited as Lua directly.
--
-- Layout (20x12 tiles, 640x384px), walking surface at y=224:
--
--        wall          spawn     boulder                    hole
--         v              v          v                        v
--   ......##...................................................    y=192
--   ###########################################  ##############    y=224  <- walking surface
--   ######################################################oo####   y=256  <- one-tile-deep hole at x=448..480
--   ############################################################
--
-- The wall rises a full tile ABOVE the walking surface: a solid rect flush
-- with the surface's top edge resolves as a walkable step under lib/bump, not
-- a wall (see tests/README.md's physics gotchas).
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
          name = "left_ground",
          type = "",
          shape = "rectangle",
          x = 0,
          y = 224,
          width = 448,
          height = 160,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 2,
          name = "hole_floor",
          type = "",
          shape = "rectangle",
          x = 448,
          y = 256,
          width = 32,
          height = 128,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 3,
          name = "right_ground",
          type = "",
          shape = "rectangle",
          x = 480,
          y = 224,
          width = 160,
          height = 160,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 4,
          name = "left_wall",
          type = "",
          shape = "rectangle",
          x = 192,
          y = 128,
          width = 32,
          height = 96,
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
          id = 5,
          name = "spawn",
          type = "spawn",
          shape = "rectangle",
          x = 256,
          y = 192,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 6,
          name = "boulder",
          type = "boulder",
          shape = "rectangle",
          x = 320,
          y = 160,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["allowPushWhenStoodOn"] = false
          }
        }
      }
    }
  }
}
