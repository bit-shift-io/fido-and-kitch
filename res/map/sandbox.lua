return {
  version = "1.11",
  luaversion = "5.1",
  tiledversion = "1.12.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 20,
  height = 20,
  tilewidth = 32,
  tileheight = 32,
  nextlayerid = 20,
  nextobjectid = 87,
  properties = {
    ["background"] = "night_forest"
  },
  tilesets = {
    {
      name = "generic_platformer_tiles",
      firstgid = 1,
      class = "",
      tilewidth = 32,
      tileheight = 32,
      spacing = 0,
      margin = 0,
      columns = 8,
      image = "../img/generic_platformer_tiles.png",
      imagewidth = 256,
      imageheight = 576,
      transparentcolor = "#000000",
      objectalignment = "unspecified",
      tilerendersize = "tile",
      fillmode = "stretch",
      tileoffset = {
        x = 0,
        y = 0
      },
      grid = {
        orientation = "orthogonal",
        width = 32,
        height = 32
      },
      properties = {},
      wangsets = {},
      tilecount = 144,
      tiles = {}
    },
    {
      name = "props",
      firstgid = 145,
      class = "",
      tilewidth = 1000,
      tileheight = 1000,
      spacing = 0,
      margin = 0,
      columns = 0,
      objectalignment = "unspecified",
      tilerendersize = "tile",
      fillmode = "stretch",
      tileoffset = {
        x = 0,
        y = 0
      },
      grid = {
        orientation = "orthogonal",
        width = 1,
        height = 1
      },
      properties = {},
      wangsets = {},
      tilecount = 10,
      tiles = {
        {
          id = 0,
          image = "../img/default.png",
          width = 32,
          height = 32
        },
        {
          id = 1,
          image = "../img/pushable_crate_wood.png",
          width = 256,
          height = 256
        },
        {
          id = 2,
          image = "../img/ladder.png",
          x = 96,
          y = 0,
          width = 32,
          height = 32
        },
        {
          id = 3,
          image = "../img/switch.png",
          x = 0,
          y = 0,
          width = 162,
          height = 162
        },
        {
          id = 4,
          image = "../img/key_blue.png",
          width = 32,
          height = 32
        },
        {
          id = 5,
          image = "../img/door.png",
          x = 0,
          y = 0,
          width = 64,
          height = 64
        },
        {
          id = 6,
          image = "../img/coins.png",
          x = 0,
          y = 0,
          width = 20,
          height = 20
        },
        {
          id = 8,
          image = "../img/teleporter_1.png",
          width = 1000,
          height = 1000
        },
        {
          id = 9,
          image = "../img/cage/cage.png",
          x = 0,
          y = 0,
          width = 380,
          height = 370
        },
        {
          id = 10,
          image = "../img/spring/Spring - 1.png",
          width = 31,
          height = 26
        }
},
        {
          id = 82,
          name = "push_box",
          type = "push_box",
          shape = "rectangle",
          x = 140,
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
          id = 83,
          name = "push_box_spawn",
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
        }
      }
    },
layers = {
    {
      type = "tilelayer",
      x = 0,
      y = 0,
      width = 20,
      height = 20,
      id = 1,
      name = "ground",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {
        ["collision"] = false
      },
      encoding = "base64",
      data = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAgAAACoAAAAqAAAAKgAAACoAAAAqAAAAKgAAACoAAAAAAAAAKgAAACoAAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAACoAAAAqAAAAKgAAACoAAAAqAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAACoAAAAqAAAAKgAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAKgAAACoAAAAqAAAAKgAAACoAAAAqAAAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGAAAABgAAAAYAAAAGAAAABgAAAAYAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA4AAAAOAAAADgAAAA4AAAAOAAAADgAAACcAAAAAAAAAAAAAAAAAAAAFAAAABgAAAAYAAAAGAAAABgAAAAYAAAAGAAAABgAAAAYAAAAGAAAADgAAAA4AAAAOAAAADgAAAA4AAAAOAAAAJwAAAAAAAAAAAAAAAAAAABwAAAAOAAAADgAAAA4AAAAOAAAADgAAAA4AAAAOAAAADgAAAA4AAAAOAAAADgAAAA4AAAAOAAAADgAAAA4AAAAnAAAAAAAAAAAAAAAAAAAAHAAAAA4AAAAOAAAADgAAAA4AAAAOAAAADgAAAA4AAAAOAAAADgAAAA=="
    },
    {
      type = "tilelayer",
      x = 0,
      y = 0,
      width = 20,
      height = 20,
      id = 14,
      name = "water",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      encoding = "base64",
      data = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGkAAABpAAAAaQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAeQAAAHkAAABxAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=="
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 16,
      name = "ladder",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {
        ["ladder"] = false
      },
      objects = {
        {
          id = 60,
          name = "ladder",
          type = "ladder",
          shape = "rectangle",
          x = 128,
          y = 192,
          width = 32,
          height = 192,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {}
        },
        {
          id = 61,
          name = "ladder",
          type = "ladder",
          shape = "rectangle",
          x = 160,
          y = 384,
          width = 32,
          height = 128,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {}
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 19,
      name = "kill",
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
          id = 78,
          name = "water_kill",
          type = "kill_zone",
          shape = "rectangle",
          x = 224,
          y = 592,
          width = 96,
          height = 112,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["deathType"] = "water"
          }
        },
        {
          id = 85,
          name = "drawbridge_pit",
          type = "kill_zone",
          shape = "rectangle",
          x = 352,
          y = 224,
          width = 32,
          height = 96,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["deathType"] = "pit"
          }
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 13,
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
          id = 86,
          name = "drawbridge",
          type = "drawbridge",
          shape = "rectangle",
          x = 352,
          y = 192,
          width = 32,
          height = 32,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {
            ["crossingDirection"] = "leftToRight"
          }
        },
        {
          id = 26,
          name = "teleport",
          type = "teleport",
          shape = "rectangle",
          x = 193.683,
          y = 511.321,
          width = 32,
          height = 32,
          rotation = 0,
          opacity = 1,
          gid = 153,
          visible = true,
          properties = {
            ["image"] = "../img/teleporter_1.png",
            ["target"] = { id = 63 }
          }
        },
        {
          id = 36,
          name = "coin",
          type = "coin",
          shape = "rectangle",
          x = 480,
          y = 352,
          width = 32,
          height = 32,
          rotation = 0,
          opacity = 1,
          gid = 151,
          visible = true,
          properties = {
            ["image"] = "../img/coins.png"
          }
        },
        {
          id = 38,
          name = "spawn",
          type = "spawn",
          shape = "rectangle",
          x = 96,
          y = 192,
          width = 32,
          height = 32,
          rotation = 0,
          opacity = 1,
          gid = 145,
          visible = true,
          properties = {}
        },
        {
          id = 41,
          name = "red_cage",
          type = "cage",
          shape = "rectangle",
          x = 32,
          y = 384,
          width = 32,
          height = 32,
          rotation = 0,
          opacity = 1,
          gid = 154,
          visible = true,
          properties = {
            ["color"] = "red",
            ["image"] = "../img/cage/cage.png",
            ["path"] = { id = 67 }
          }
        },
        {
          id = 43,
          name = "exit",
          type = "exit_door",
          shape = "rectangle",
          x = 416,
          y = 192,
          width = 32,
          height = 32,
          rotation = 0,
          opacity = 1,
          gid = 150,
          visible = true,
          properties = {
            ["actor_count"] = 2
          }
        },
        {
          id = 44,
          name = "switch",
          type = "switch",
          shape = "rectangle",
          x = 288,
          y = 192,
          width = 32,
          height = 32,
          rotation = 0,
          opacity = 1,
          gid = 148,
          visible = true,
          properties = {
            ["image"] = "../img/switch.png",
            ["target"] = { id = 43 }
          }
        },
        {
          id = 62,
          name = "red_key",
          type = "key",
          shape = "rectangle",
          x = 96,
          y = 384,
          width = 32,
          height = 32,
          rotation = 0,
          opacity = 1,
          gid = 149,
          visible = true,
          properties = {
            ["color"] = "red",
            ["image"] = "../img/key_yellow.png"
          }
        },
        {
          id = 63,
          name = "teleport",
          type = "teleport",
          shape = "rectangle",
          x = 384,
          y = 544,
          width = 32,
          height = 32,
          rotation = 0,
          opacity = 1,
          gid = 153,
          visible = true,
          properties = {
            ["image"] = "../img/teleporter_1.png",
            ["target"] = { id = 26 }
          }
        },
        {
          id = 68,
          name = "jump_pad",
          type = "jump_pad",
          shape = "rectangle",
          x = 192,
          y = 384,
          width = 32,
          height = 32,
          rotation = 0,
          opacity = 1,
          gid = 155,
          visible = true,
          properties = {
            ["image"] = "../img/spring/Spring - 1.png",
            ["path"] = { id = 73 }
          }
        },
        {
          id = 75,
          name = "blue_cage",
          type = "cage",
          shape = "rectangle",
          x = 512,
          y = 256,
          width = 32,
          height = 32,
          rotation = 0,
          opacity = 1,
          gid = 123,
          visible = true,
          properties = {
            ["color"] = "blue",
            ["path"] = { id = 77 }
          }
        },
        {
          id = 76,
          name = "blue_key",
          type = "key",
          shape = "rectangle",
          x = 608,
          y = 256,
          width = 32,
          height = 32,
          rotation = 0,
          opacity = 1,
          gid = 123,
          visible = true,
          properties = {
            ["color"] = "blue"
          }
        },
        {
          id = 81,
          name = "push_box",
          type = "push_box",
          shape = "rectangle",
          x = 160,
          y = 192,
          width = 32,
          height = 32,
          rotation = 0,
          opacity = 1,
          gid = 146,
          visible = true,
          properties = {
            ["allowPushWhenStoodOn"] = false,
            ["image"] = "../img/pushable_crate_wood.png"
          }
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 18,
      name = "waypoints",
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
          id = 67,
          name = "red_bird_path",
          type = "",
          shape = "polyline",
          x = 48,
          y = 368,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polyline = {
            { x = 0, y = 0 },
            { x = 32, y = -64 },
            { x = 256, y = -96 },
            { x = 392, y = -128 },
            { x = 448, y = -128 },
            { x = 448, y = -192 },
            { x = 384, y = -192 }
          },
          properties = {
            ["finish"] = "target:exitThroughDoor(entity)",
            ["target"] = { id = 43 }
          }
        },
        {
          id = 73,
          name = "jump_path",
          type = "",
          shape = "polyline",
          x = 208,
          y = 384,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polyline = {
            { x = 0, y = 0 },
            { x = 16, y = -48 },
            { x = 48, y = -80 },
            { x = 96, y = -96 },
            { x = 128, y = -88 },
            { x = 152, y = -64 },
            { x = 160, y = -32 }
          },
          properties = {}
        },
        {
          id = 77,
          name = "blue_bird_path",
          type = "",
          shape = "polyline",
          x = 528,
          y = 240,
          width = 0,
          height = 0,
          rotation = 0,
          opacity = 1,
          visible = true,
          polyline = {
            { x = 0, y = 0 },
            { x = -96, y = 8 },
            { x = -144, y = 64 },
            { x = -208, y = 96 },
            { x = -232, y = 184 },
            { x = -264, y = 224 },
            { x = -392, y = 224 },
            { x = -496, y = 224 },
            { x = -576, y = 224 }
          },
          properties = {
            ["finish"] = "target:exitInstant(entity)",
            ["target"] = { id = 43 }
          }
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 15,
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
          id = 53,
          name = "",
          type = "",
          shape = "rectangle",
          x = 96,
          y = 192,
          width = 256,
          height = 32,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {}
        },
        {
          id = 84,
          name = "",
          type = "",
          shape = "rectangle",
          x = 384,
          y = 192,
          width = 96,
          height = 32,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {}
        },
        {
          id = 54,
          name = "",
          type = "",
          shape = "rectangle",
          x = 32,
          y = 192,
          width = 32,
          height = 32,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {}
        },
        {
          id = 55,
          name = "",
          type = "",
          shape = "rectangle",
          x = 448,
          y = 256,
          width = 192,
          height = 32,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {}
        },
        {
          id = 56,
          name = "",
          type = "",
          shape = "rectangle",
          x = 352,
          y = 352,
          width = 160,
          height = 32,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {}
        },
        {
          id = 57,
          name = "",
          type = "",
          shape = "rectangle",
          x = 0,
          y = 384,
          width = 224,
          height = 32,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {}
        },
        {
          id = 58,
          name = "",
          type = "",
          shape = "rectangle",
          x = 0,
          y = 512,
          width = 224,
          height = 128,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {}
        },
        {
          id = 59,
          name = "",
          type = "",
          shape = "rectangle",
          x = 320,
          y = 544,
          width = 320,
          height = 96,
          rotation = 0,
          opacity = 1,
          visible = true,
          properties = {}
        }
      }
    }
  }
}
