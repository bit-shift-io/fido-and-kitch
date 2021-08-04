# Fido and Kitch

Fido and Kitch is a puzzle platformer. It features local couch co-op with bite sized puzzles. Think Lurid Land made with Flutter and Flame.

# Install

To install simply run:

    ./install.sh

This will checkout any required dependencies

# TO debbug in VSCode

get the "Local Lua Debugger" extension (tomblind.local-lua-debugger-vscode) extension.


## Map Editor

https://www.mapeditor.org/

## Contribute

Looking for things to do, look here: https://github.com/bit-shift-io/fido-and-kitch/projects

## Architecture

ECS without ECS. The goal of ECS is to improve performance by improving CPU cache hits by keeping components coherent within memory and operating on all
components in a linear fashion.
This type of architecture doesn't fit with the traditional hierachy of data, updating and rendering provided by most traditional engines (including flame).
For this reason we use a hybrid approach:
Pools of components to maintain coherancy and try to improve CPU caching. Updating is done based on component type, similar to ECS systems.
We leave rendering in the hierachical way flame expects.

Components are building blocks.
Entities are root level items that are made up of components.
Entities should interact with one another and each entity can interact with its own components, but no entity should know about another entities components.

## Assets

Here are a list of assets we use in the game and their source of origin.

* Cat & Dog - https://opengameart.org/content/cat-dog-free-sprites
* Platformer tiles - https://opengameart.org/content/generic-platformer-tiles
* Keys - https://opengameart.org/content/key-icons
* Teleporter - https://opengameart.org/content/4-summoning-circles
* Cage - https://opengameart.org/content/cage
* Switch/lever - https://forums.tigsource.com/index.php?topic=59695.0
* Door - https://opengameart.org/content/heavy-slamdoor-0