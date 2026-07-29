-- Hand-authored fixture map (see flat_ground.lua/coin_room.lua for the
-- STI-shaped, no-tileset precedent this follows): a flat floor with a spawn
-- point and a single key within walking distance, for exercising Pickup/Sound
-- wiring.
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
  nextlayerid = 3,
  nextobjectid = 4,
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
          name = "key1",
          type = "key",
          shape = "rectangle",
          x = 120,
          y = 160,
          width = 20,
          height = 20,
          rotation = 0,
          visible = true,
          properties = {
            ["color"] = "red"
          }
        }
      }
    }
  }
}
