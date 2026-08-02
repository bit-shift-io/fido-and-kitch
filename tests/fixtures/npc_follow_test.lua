-- Hand-authored fixture map for NPC follow system integration test:
-- flat floor, spawn point, two cages (one bird, one rabbit), and an exit door
return {
  version = "1.11",
  luaversion = "5.1",
  tiledversion = "1.12.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 20,
  height = 8,
  tilewidth = 32,
  tileheight = 32,
  nextlayerid = 4,
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
          name = "floor",
          type = "",
          shape = "rectangle",
          x = 0,
          y = 224,
          width = 640,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 6,
          name = "mid_wall",
          type = "",
          shape = "rectangle",
          x = 320,
          y = 160,
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
          name = "cage_bird",
          type = "cage",
          shape = "rectangle",
          x = 160,
          y = 224,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["color"] = "red",
            ["spawn_type"] = "bird"
          }
        },
        {
          id = 4,
          name = "cage_rabbit",
          type = "cage",
          shape = "rectangle",
          x = 260,
          y = 224,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["color"] = "blue",
            ["spawn_type"] = "rabbit"
          }
        },
        {
          id = 5,
          name = "exit1",
          type = "exit_door",
          shape = "rectangle",
          x = 560,
          y = 192,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["actor_count"] = 0
          }
        }
      }
    }
  }
}