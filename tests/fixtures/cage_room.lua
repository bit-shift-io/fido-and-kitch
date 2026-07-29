-- Hand-authored fixture map (see flat_ground.lua for the STI-shaped,
-- no-tileset precedent this follows): a flat floor, a spawn point, and a cage
-- with a bird + waypoint path, for exercising Cage:use()/Sound wiring.
return {
  version = "1.11",
  luaversion = "5.1",
  tiledversion = "1.12.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 10,
  height = 6,
  tilewidth = 32,
  tileheight = 32,
  nextlayerid = 4,
  nextobjectid = 5,
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
          y = 160,
          width = 320,
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
          name = "spawn",
          type = "spawn",
          shape = "rectangle",
          x = 64,
          y = 128,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 3,
          name = "cage1",
          type = "cage",
          shape = "rectangle",
          x = 120,
          y = 128,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["color"] = "red",
            ["path"] = { id = 4 }
          }
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 3,
      name = "waypoints",
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
          name = "red_bird_path",
          type = "",
          shape = "polyline",
          x = 120,
          y = 128,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polyline = {
            { x = 0, y = 0 },
            { x = 32, y = -32 },
            { x = 64, y = -32 }
          },
          properties = {}
        }
      }
    }
  }
}
