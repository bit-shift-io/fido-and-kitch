-- Hand-authored fixture map (see flat_ground.lua for the STI-shaped, no-tileset
-- precedent this follows): a flat floor with a spawn point, a switch, and a
-- harmless exit_door target for the switch to reference (Switch:use() only
-- calls target.entity:switch() when the target entity implements it -- an
-- exit_door doesn't, so it's a safe no-op target for exercising the switch
-- itself).
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
          name = "switch1",
          type = "switch",
          shape = "rectangle",
          x = 120,
          y = 128,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["target"] = { id = 4 }
          }
        },
        {
          id = 4,
          name = "exit1",
          type = "exit_door",
          shape = "rectangle",
          x = 240,
          y = 128,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["actor_count"] = 1
          }
        }
      }
    }
  }
}
