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

P2
WASD + left shift

## IPC Server (AI Agent Control)

The game includes a TCP-based IPC server for programmatic control via OpenCode tools.

Start the game with IPC enabled:
```bash
love . ipc map=sandbox      # default port 8081
love . ipc ipc_port=9000 map=ll1  # custom port/map
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
| `RESTART_LEVEL` | Reload current map |
| `MENU` | Return to main menu |

OpenCode tools (auto-loaded from `.opencode/tools/fido-kitch-ipc.ts`):
- `launch_game` — Start game with IPC (blocks until ready)
- `get_game_state` — Full state as string
- `get_player_pos` — Single player position
- `resize_window` — Resize window
- `press_key` / `release_key` — Simulate key press/release
- `hold_key` — Hold key for duration
- `move_player` — Direct position change
- `restart_level` — Reload current map
- `go_to_menu` — Return to main menu
- `toggle_camera` — Toggle camera overview mode

Set `FIDO_KITCH_IPC_PORT` env var for custom port.

## Contribute

Looking for things to do, look here: https://github.com/bit-shift-io/fido-and-kitch/projects

## Assets

Here are a list of assets we use in the game and their source of origin.

* Cat & Dog - https://opengameart.org/content/cat-dog-free-sprites
* Platformer tiles - https://opengameart.org/content/generic-platformer-tiles
* Keys - https://opengameart.org/content/key-icons
* Teleporter - https://opengameart.org/content/4-summoning-circles
* Cage - https://opengameart.org/content/cage
* Switch/lever - https://forums.tigsource.com/index.php?topic=59695.0
* Door - https://opengameart.org/content/heavy-slamdoor-0
* Bird - https://opengameart.org/content/cartooney-bird-01
* Pushable Wood Crate - https://opengameart.org/content/pixel-wooden-crate
* Pushable Stone Block - https://opengameart.org/content/block-with-a-face
