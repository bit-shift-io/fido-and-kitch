# Fido and Kitch

Fido and Kitch is a puzzle platformer. It features local couch co-op with bite sized puzzles similar to Lurid Land.

## Install

This project targets LÖVE 12.0.

`run.sh` uses `bin/love.AppImage` when it exists, which is the preferred way to run a pinned local LÖVE 12 build on Linux. If that file is missing, it falls back to `love` from your PATH.

To install dependencies, run:

    ./setup.sh

This installs LÖVE through the host package manager when available and checks out Lua dependencies into `lib/`. Package-manager LÖVE versions may lag behind 12.0, so keep a LÖVE 12 AppImage at `bin/love.AppImage` if your system package is older.

## Tests

Run the fast headless Lua tests from the repository root:

    ./test.sh

These tests use a tiny dependency-free runner and do not launch a LÖVE window.

## To debug in VSCode

Launch VSCode Quick Open (Ctrl+P), paste the following commands, and press enter.
```
    ext install tomblind.local-lua-debugger-vscode
```
```
ext install sumneko.lua
```

## Map Editor

https://www.mapeditor.org/

```bash paru -S tiled```

Edit > Preferences > check 'Embed tilesets' & 'Detatch Templates'
Save the map as tmx but will need to be exported as .lua to be loaded.  

## Controls
F1 - debug
F12 - screenshot

P1
Arrow keys + right shift
Gamepad: D-pad / Left Stick (move), A/B (use), Start (menu), Back (back)

P2
WASD + left shift
Gamepad: D-pad / Left Stick (move), A/B (use), Start (menu), Back (back)

## IPC Server (AI Agent Control)

The game includes a TCP-based IPC server for programmatic control via OpenCode tools.

Start the game with IPC enabled:
```bash
./run.sh ipc map=sandbox      # default port 8081
./run.sh ipc ipc_port=9000 map=ll1  # custom port/map
```

Available commands (sent via TCP to 127.0.0.1:8081):
| Command | Description |
|---------|-------------|
| `RESIZE <w> <h>` | Resize window |
| `MOVE_PLAYER <1\|2> <dx> <dy>` | Move player by delta |
| `INPUT <1\|2> <action> <down\|up>` | Simulate key press/release (actions: left, right, up, down, use) |
| `HOLD_KEY <1\|2> <action> <duration>` | Hold key for N seconds |
| `TOGGLE_CAMERA` | Toggle camera overview mode |
| `GET_STATE` | Full state snapshot |
| `GET_PLAYER_POS <1\|2>` | Single player position |
| `GET_ENTITIES` | All entities as JSON (players, items, colliders, etc.) |
| `RESTART_LEVEL` | Reload current map |
| `MENU` | Return to main menu |
| `LOAD_MAP <map_name>` | Load specific map dynamically |
| `TAKE_SCREENSHOT [filename]` | Capture current game screen |
| `GET_TILE_GRID` | Get map tile grid as 2D matrix (0=empty, 1=solid, 2=ladder, 3=killzone) |
| `SPAWN_ENTITY <type> <x> <y> [props_json]` | Spawn entity into live game world |
| `STEP_FRAMES <count>` | Advance simulation by N fixed timesteps |

OpenCode tools (auto-loaded from `.opencode/tools/fido-kitch-ipc.ts`):
- `launch_game` — Start game with IPC (blocks until ready)
- `get_game_state` — Full state as string
- `get_player_pos` — Single player position
- `get_entities` — All entities as JSON
- `resize_window` — Resize window
- `press_key` / `release_key` — Simulate key press/release
- `hold_key` — Hold key for duration
- `move_player` — Direct position change
- `restart_level` — Reload current map
- `go_to_menu` — Return to main menu
- `toggle_camera` — Toggle camera overview mode
- `load_map` — Load specific map dynamically
- `take_screenshot` — Capture current game screen
- `get_tile_grid` — Get map tile grid as 2D matrix
- `spawn_entity` — Spawn entity into live game world
- `step_frames` — Advance simulation by N frames

Set `FIDO_KITCH_IPC_PORT` env var for custom port.
