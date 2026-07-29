-- Hand-authored fixture map for the pushable props (see
-- tests/fixtures/flat_ground.lua for the same precedent and why these are
-- edited as Lua directly rather than round-tripped through Tiled). No
-- tileset/tile layer is used -- only object layers -- which sidesteps STI's
-- tileset image-caching path entirely.
--
-- Layout (20x12 tiles, 640x384px), walking surface at y=224:
--
--   spawn   push_box       ride_box  blocker_box     wall
--     v         v             v          v            v
--   ......................................................    y=192
--   #################  ###################################    y=224  <- walking surface
--   #################oo###################################    y=256  <- one-tile-deep hole at x=288..320
--   ######################################################
--
-- Three props, kept far enough apart that a test pushing one never disturbs
-- another: push_box (centre x=176) is the general-purpose one and the only
-- prop that can reach the hole; ride_box (centre x=368) carries
-- allowPushWhenStoodOn; blocker_box (centre x=432) is something to shove
-- ride_box into, and sits within pushing distance of the right wall.
--
-- The hole is exactly one tile wide and one tile deep, so a 32x32 prop that
-- falls into it sits with its top flush with the surrounding surface -- the
-- hole-filling case ADR 0001's snap model exists to make reliable. The right
-- wall deliberately rises a full tile ABOVE the walking surface: a solid rect
-- flush with the surface's top edge resolves as a walkable step under
-- lib/bump, not a wall (see tests/README.md's physics gotchas).
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
          width = 288,
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
          x = 288,
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
          x = 320,
          y = 224,
          width = 320,
          height = 160,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 4,
          name = "right_wall",
          type = "",
          shape = "rectangle",
          x = 576,
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
          x = 64,
          y = 192,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 6,
          name = "push_box",
          type = "push_box",
          shape = "rectangle",
          x = 160,
          y = 160,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["allowPushWhenStoodOn"] = false
          }
        },
        -- the co-op opt-in variant: pushable even with a player aboard
        {
          id = 7,
          name = "ride_box",
          type = "push_box",
          shape = "rectangle",
          x = 352,
          y = 160,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["allowPushWhenStoodOn"] = true
          }
        },
        -- sits on the right ground as something for another prop to be
        -- shoved into, and near enough the right wall to be pushed against it
        {
          id = 8,
          name = "blocker_box",
          type = "push_box",
          shape = "rectangle",
          x = 416,
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
