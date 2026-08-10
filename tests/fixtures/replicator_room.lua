-- Hand-authored fixture map for the replicator entity (see
-- mover_platform_room.lua for the STI-shaped, no-tileset precedent this
-- follows): a flat floor, a replicator mounted high in the air directly above
-- wide-open space so spawned push boxes fall and land on the floor, and a
-- switch wired to the replicator's Switchable for stop/start.
--
-- Replicator geometry: object at (192,64) is bottom-anchored (its sprite
-- centre is (208,48) per Rect.centreOfMapObject). The spawned mock object is
-- top-anchored (no gid), so PushableSupport.spawnCentre places each box's
-- centre at y = (object.y - object.height) + object.height*0.5 = 48, i.e. the
-- same hover point as the machine; it then falls 96px onto the floor top
-- (y=160), landing with centre y=144 (box is 32x32).
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
          width = 512,
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
          x = 48,
          y = 128,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 3,
          name = "replicator",
          type = "replicator",
          shape = "rectangle",
          x = 192,
          y = 64,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["interval"] = 1.0,
            ["spawnType"] = "push_box"
          }
        },
        {
          id = 4,
          name = "replicator_switch",
          type = "switch",
          shape = "rectangle",
          x = 32,
          y = 128,
          width = 32,
          height = 32,
          rotation = 0,
          visible = true,
          properties = {
            ["target"] = { id = 3 }
          }
        }
      }
    }
  }
}