-- Hand-authored fixture map exercising an external (.tsx-referenced)
-- tileset through the real Map/STI stack -- see
-- .scratch/external-tilesets/issues/01-single-image-external-tileset.md.
-- The tileset entry below has no embedded `image`/geometry fields, only
-- `filename`, exactly as Tiled exports when "Embed tilesets" is off; STI's
-- external_tileset resolver must fill the rest in at load time.
--
-- Layout: a 5x3 room with a single ground tile layer across the bottom row
-- (gid 1 = tile id 0, which carries a custom "solid" property), plus one
-- animated tile (gid 2 = tile id 1, which cycles to tile id 2) placed in
-- the middle row -- both defined on external_tileset_room.tsx to exercise
-- per-tile properties/animation resolution (see
-- .scratch/external-tilesets/issues/03-per-tile-properties-animation-collision.md).
-- The usual collision/spawn object layers (see tests/fixtures/flat_ground.lua
-- for the same precedent) let the map load through the full game stack, not
-- just STI in isolation.
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
  nextlayerid = 4,
  nextobjectid = 3,
  properties = {},
  tilesets = {
    {
      name = "external_tileset_room_tiles",
      firstgid = 1,
      filename = "external_tileset_room.tsx"
    }
  },
  layers = {
    {
      type = "tilelayer",
      x = 0,
      y = 0,
      width = 5,
      height = 3,
      id = 1,
      name = "ground",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      data = {
        0, 0, 0, 0, 0,
        0, 2, 0, 0, 0,
        1, 1, 1, 1, 1
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 2,
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
        }
      }
    }
  }
}
