-- Hand-authored fixture map exercising an external image-collection
-- tileset (columns = 0, one <image> per <tile>) through the real
-- Map/STI stack.
-- Reuses the real res/editor/tileset_props.tsx (the repo's props tileset --
-- external tilesets live in res/editor/ as tileset_*.tsx) rather than a
-- synthetic copy, per the "use real fixtures already on disk" note.
--
-- A single "switch" tile object (tileset_props.tsx tile id 3, a 128x128
-- crop of entity_switch.png) is placed as a tile object so
-- Map:setObjectSpriteBatches resolves it through the atlas path.
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
      name = "props",
      firstgid = 1,
      filename = "../../res/editor/tileset_props.tsx"
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
          gid = 4,
          visible = true,
          properties = {}
        }
      }
    }
  }
}
