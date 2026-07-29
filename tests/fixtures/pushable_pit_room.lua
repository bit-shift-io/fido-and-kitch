-- Hand-authored fixture map for a prop dropped into a bottomless gap -- the
-- "falls into water" case (DECISIONS Q8): water in this project is cosmetic
-- tiles plus a kill_zone SENSOR, and a prop crosses a sensor without being
-- stopped, so it keeps falling until the map's own bottom boundary catches it.
-- Nothing about buoyancy is modelled; this fixture proves the prop is not
-- destroyed, does not stick to the sensor, and comes to rest at the bottom.
--
-- See tests/fixtures/flat_ground.lua for why these are edited as Lua directly.
--
-- Layout (12x10 tiles, 384x320px), walking surface at y=224:
--
--   spawn  box
--     v     v
--   ...............................    y=192
--   #####  ########################    y=224  <- walking surface
--   #####~~########################    y=256  <- kill_zone sensor ("water")
--   #####~~########################
--         ^^
--     bottomless gap at x=160..192, open all the way to the map's bottom edge
--
-- The gap column has no floor at all, so the only thing below it is the
-- boundary collider Map:createStaticPhysicsBodyBoundary builds from the map's
-- DECLARED height -- which is why the map is sized generously around the gap
-- (see tests/README.md on undersized fixture maps).
return {
  version = "1.11",
  luaversion = "5.1",
  tiledversion = "1.12.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 12,
  height = 10,
  tilewidth = 32,
  tileheight = 32,
  nextlayerid = 4,
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
          name = "left_ground",
          type = "",
          shape = "rectangle",
          x = 0,
          y = 224,
          width = 160,
          height = 96,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 2,
          name = "right_ground",
          type = "",
          shape = "rectangle",
          x = 192,
          y = 224,
          width = 192,
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
      name = "kill",
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
          name = "water",
          type = "kill_zone",
          shape = "rectangle",
          x = 160,
          y = 256,
          width = 32,
          height = 64,
          rotation = 0,
          visible = true,
          properties = {
            ["deathType"] = "water"
          }
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 3,
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
          name = "spawn",
          type = "spawn",
          shape = "rectangle",
          x = 32,
          y = 192,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 5,
          name = "push_box",
          type = "push_box",
          shape = "rectangle",
          x = 96,
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
