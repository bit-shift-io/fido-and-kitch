-- Hand-authored fixture map for the mover_platform feature (see
-- drawbridge_room.lua for the STI-shaped, no-tileset precedent this follows):
-- a flat floor split by a 256px gap, a mover platform that bridges the gap
-- end-to-end at floor level (top flush with the floor surface), a kill zone
-- in the pit below (so a fall is consequential), and a lever switch wired to
-- the platform's Switchable for stop/start.
--
-- The platform object's x/y is cosmetic only: with a `path` property set,
-- MoverPlatform:init resets its collider onto the path. The polyline is the
-- DECK line -- the top riding surface (y=160, flush with the floor) -- and
-- the 32-tall platform hangs half its height below it, so the collider
-- centre rests at (192,176); the authored rectangle matches that centre for
-- Tiled-shaped saneness.
return {
  version = "1.11",
  luaversion = "5.1",
  tiledversion = "1.12.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 16,
  height = 10,
  tilewidth = 32,
  tileheight = 32,
  nextlayerid = 5,
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
          name = "floor_left",
          type = "",
          shape = "rectangle",
          x = 0,
          y = 160,
          width = 128,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 2,
          name = "floor_right",
          type = "",
          shape = "rectangle",
          x = 384,
          y = 160,
          width = 128,
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
          id = 3,
          name = "gap_kill",
          type = "kill_zone",
          shape = "rectangle",
          x = 128,
          y = 192,
          width = 256,
          height = 128,
          rotation = 0,
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
          id = 4,
          name = "spawn",
          type = "spawn",
          shape = "rectangle",
          x = 48,
          y = 128,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 5,
          name = "mover_platform",
          type = "mover_platform",
          shape = "rectangle",
          x = 128,
          y = 176,
          width = 128,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["path"] = { id = 6 },
            ["speed"] = 100,
            ["endBehavior"] = "pingpong",
            ["pause"] = 0
          }
        },
        {
          id = 7,
          name = "mover_switch",
          type = "switch",
          shape = "rectangle",
          x = 32,
          y = 128,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["target"] = { id = 5 }
          }
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 4,
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
          id = 6,
          name = "mover_path",
          type = "",
          shape = "polyline",
          x = 192,
          y = 160,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polyline = {
            { x = 0, y = 0 },
            { x = 128, y = 0 }
          },
          properties = {}
        }
      }
    }
  }
}