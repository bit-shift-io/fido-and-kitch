# Fido and Kitch

Fido and Kitch is a puzzle platformer. It features local couch co-op with bite sized puzzles similar to Lurid Land.

## Install

This project targets LÖVE 12.0.

`run.sh` uses `bin/love.AppImage` when it exists, which is the preferred way to run a pinned local LÖVE 12 build on Linux. If that file is missing, it falls back to `love` from your PATH.

To install dependencies, run:

    ./setup.sh

This installs LÖVE through the host package manager when available and checks out Lua dependencies into `lib/`. Package-manager LÖVE versions may lag behind 12.0, so keep a LÖVE 12 AppImage at `bin/love.AppImage` if your system package is older.

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

File > Preferences > check 'Embed tilesets'  
Save the map as tmx but will need to be exported as .lua to be loaded.  

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