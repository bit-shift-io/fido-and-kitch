-- Hand-authored fixture map for the drawbridge feature (no Tiled GUI was
-- available while building this; author/maintain in Tiled and re-export if
-- you have it, otherwise edit this Lua directly and keep it STI-shaped).
--
-- Layout: solid ground on both sides of a single 1-tile gap at tile x=4
-- (pixels x=128..160), a drawbridge over the gap (facing 'left', matching
-- the correct side the lone spawn point sits on), and a kill zone in the pit
-- below so falling in has a real consequence.
return {
  version = "1.11",
  luaversion = "5.1",
  tiledversion = "1.12.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 9,
  height = 6,
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
          name = "",
          type = "",
          shape = "rectangle",
          x = 0,
          y = 128,
          width = 128,
          height = 64,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 2,
          name = "",
          type = "",
          shape = "rectangle",
          x = 160,
          y = 128,
          width = 128,
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
          name = "pit_kill",
          type = "kill_zone",
          shape = "rectangle",
          x = 128,
          y = 192,
          width = 32,
          height = 128,
          rotation = 0,
          visible = true,
          properties = {
            ["deathType"] = "pit"
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
          name = "drawbridge",
          type = "drawbridge",
          shape = "rectangle",
          x = 128,
          y = 128,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["facing"] = "left",
            ["allowEnemies"] = false
          }
        },
        {
          id = 5,
          name = "spawn",
          type = "spawn",
          shape = "rectangle",
          x = 48,
          y = 64,
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
