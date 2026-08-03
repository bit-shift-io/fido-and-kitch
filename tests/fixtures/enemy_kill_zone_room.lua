-- Hand-authored fixture map (mirrors kill_zone_room.lua's shape): the player
-- spawns onto solid ground and stays there (this feature doesn't touch
-- player behaviour, and a player death here would eventually exhaust lives
-- and drop the game into GameOverState, which stops map:update entirely --
-- freezing the Robot's own death/respawn timers along with it). The Robot
-- spawns with no floor beneath it and falls straight into the kill zone.
-- Used to exercise NPC kill-zone death/respawn end-to-end (see
-- tests/unit/npc_death_test.lua for the pure state-transition coverage this
-- doesn't repeat).
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
          width = 96,
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
          name = "water1",
          type = "kill_zone",
          shape = "rectangle",
          x = 96,
          y = 160,
          width = 224,
          height = 64,
          rotation = 0,
          visible = true,
          properties = {
            ["deathType"] = "water"
          }
        },
        {
          id = 4,
          name = "robot1",
          type = "npc_robot",
          shape = "rectangle",
          x = 200,
          y = 128,
          width = 24,
          height = 24,
          rotation = 0,
          visible = true,
          properties = {}
        }
      }
    }
  }
}
