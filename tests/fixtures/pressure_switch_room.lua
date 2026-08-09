-- Hand-authored fixture map for the pressure switch: flat ground, a push box
-- to shove around, a momentary plate wired to a real switchable target, and a
-- separate latching plate wired to nothing (only its own state matters).
-- See tests/fixtures/flat_ground.lua for why these are edited as Lua directly.
--
-- Layout (20x12 tiles, 640x384px), walking surface at y=224:
--
--   spawn   box   plate    latching plate      ladder (target)
--     v      v      v            v                  v
--   .......................................................    y=192
--   #######################################################    y=224  <- walking surface
--
-- The target is a real `ladder` carrying a `switchOn` event snippet
-- (`entity:grow(2)`), which is the project's own way for a switch to have a
-- visible effect (see res/map/ll2.tmx). Driving the plate therefore grows the
-- ladder for real -- the test observes the effect rather than mocking the call.
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
  nextobjectid = 8,
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
          name = "ground",
          type = "",
          shape = "rectangle",
          x = 0,
          y = 224,
          width = 640,
          height = 160,
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
          y = 192,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 3,
          name = "push_box",
          type = "push_box",
          shape = "rectangle",
          x = 192,
          y = 160,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["allowPushWhenStoodOn"] = false
          }
        },
        {
          id = 4,
          name = "plate",
          type = "pressure_switch",
          shape = "rectangle",
          x = 288,
          y = 192,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["latching"] = false,
            ["target"] = { id = 6 }
          }
        },
        {
          id = 5,
          name = "latching_plate",
          type = "pressure_switch",
          shape = "rectangle",
          x = 384,
          y = 192,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["latching"] = true
          }
        },
        {
          id = 6,
          name = "target_ladder",
          type = "ladder",
          shape = "rectangle",
          x = 544,
          y = 224,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["switchOn"] = "entity:grow(2)"
          }
        },
        {
          id = 7,
          name = "target_ladder",
          type = "ladder",
          shape = "rectangle",
          x = 544,
          y = 192,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["switchOn"] = "entity:grow(2)"
          }
        }
      }
    }
  }
}
