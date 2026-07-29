-- Hand-authored fixture map (see flat_ground.lua for the STI-shaped,
-- no-tileset precedent this follows): a flat floor with a spawn point and a
-- ladder spanning the full fall column, so the settled player can press up
-- to mount it, for exercising LadderState/Sound wiring.
return {
  version = "1.11",
  luaversion = "5.1",
  tiledversion = "1.12.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 10,
  height = 8,
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
          y = 224,
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
          name = "ladder1",
          type = "ladder",
          shape = "rectangle",
          x = 64,
          y = 128,
          width = 32,
          height = 96,
          rotation = 0,
          visible = true,
          properties = {}
        }
      }
    }
  }
}
