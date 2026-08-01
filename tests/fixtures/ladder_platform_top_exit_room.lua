-- Hand-authored fixture map (see flat_ground.lua for the STI-shaped,
-- no-tileset precedent this follows): same platform/ladder/floor geometry
-- as ladder_platform_room.lua (mirrors res/map/ll2.tmx's ladder id 16 --
-- the ladder's own top tile shares its row with adjacent walkable ground),
-- but with the spawn placed at the base of the ladder instead of the top.
-- Climbing all the way up and dismounting exits onto the platform that
-- shares the ladder's top row.
return {
  version = "1.11",
  luaversion = "5.1",
  tiledversion = "1.12.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 10,
  height = 12,
  tilewidth = 32,
  tileheight = 32,
  nextlayerid = 3,
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
          name = "platform",
          type = "",
          shape = "rectangle",
          x = 64,
          y = 192,
          width = 160,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 2,
          name = "floor",
          type = "",
          shape = "rectangle",
          x = 0,
          y = 320,
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
          id = 3,
          name = "spawn",
          type = "spawn",
          shape = "rectangle",
          x = 104,
          y = 280,
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
          x = 128,
          y = 192,
          width = 32,
          height = 128,
          rotation = 0,
          visible = true,
          properties = {}
        }
      }
    }
  }
}
