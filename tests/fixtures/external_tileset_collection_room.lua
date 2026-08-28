-- Hand-authored fixture map exercising an external single-tile
-- tileset (the new individual tsj per template) through the real
-- Map/STI stack. Uses the switch.tsj which has one tile.
return {
  version = "1.11",
  luaversion = "5.1",
  tiledversion = "1.12.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 5,
  height = 3,
  tilewidth = 32,
  tileheight = 32,
  nextlayerid = 3,
  nextobjectid = 4,
  properties = {},
  tilesets = {
    {
      name = "switch",
      firstgid = 1,
      filename = "../../res/editor/switch.tsj"
    }
  },
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
          y = 96,
          width = 160,
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
          x = 32,
          y = 64,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 3,
          name = "switch_decoration",
          type = "",
          shape = "rectangle",
          x = 96,
          y = 32,
          width = 128,
          height = 128,
          rotation = 0,
          gid = 1,
          visible = true,
          properties = {}
        }
      }
    }
  }
}
