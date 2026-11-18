# TerraBlock — C3 / Raylib port

A C3 + Raylib port of the LÖVE2D sandbox game in the parent directory.
The window icon is `player-32x32.png`.

## Requirements

- C3 compiler 0.8.6+
- Raylib 6.2 (bundled as `lib/raylib.c3l`)

## Build & run

From this directory:

```bash
c3c build              # builds build/TerraBlock (default target)
c3c build debug        # O0 debug target
./build/TerraBlock
```

### CLI shortcuts

```bash
./build/TerraBlock --seed 123             # jump straight into a world
./build/TerraBlock --seed 123 --creative  # creative mode
./build/TerraBlock --host 22120 --seed 777
./build/TerraBlock --join 127.0.0.1 --host 22120 --name Alice
```

`--host` starts the built-in server; `--join` connects to one (the port comes
from `--host`, default `22120`). `--name` sets the multiplayer player name.

## Controls

| Key | Action |
| --- | --- |
| `A` / `D` / arrow keys | Move |
| `Space` / `W` / `Up` | Jump (double-tap in creative toggles fly) |
| `S` / `Down` | Drop through platforms / descend while flying |
| `LMB` | Place block, interact, or attack with a sword |
| `RMB` | Mine / break the targeted block |
| `Mouse wheel` / `1`–`0` | Change hotbar slot |
| `E` / `Tab` | Inventory |
| `C` | Workstation panel (crafting / furnace / chest) |
| `F` | Interact with targeted block (door, logic, stations, …) |
| `Q` | Eat selected food |
| `B` | Toggle foreground/background build layer |
| `F3` | Debug overlay (hold `F4` to toggle ghost mode) |
| `F5` / `F9` | Save / load single-player world |
| `R` | Generate a new random world |
| `/` | Command overlay |
| `T` | Server chat (multiplayer only) |
| `Esc` / `P` | Pause / close the open panel |

### Commands

`/give <item> [count]`, `/gamemode <survival|creative>`,
`/time set <day|night|noon|midnight|0.0-1.0>`, `/tp <x> <y>`, `/heal`,
`/clear`, `/seed`, `/killall`, `/help`.

## Features

- Procedural terrain with biomes, caves, ore seams, trees, cacti and ruins.
- Chunk streaming, per-chunk block maps, foreground/background layers.
- Mining, placement, tools, hunger, fall damage, blood moon, drops and enemies.
- Crafting by category, furnaces with fuel/progress, persistent 20-slot chests.
- Logic wires/gates/levers/buttons/lamps/displays, circuit-board editor and a
  restricted expression-based programmable circuit editor.
- Binary saves under `saves/<seed>/world.sav`; world select/create/delete menu.
- Mod/datapack metadata discovery and texture overrides. Lua scripts themselves
  are not executed.

## Multiplayer

The game includes a built-in, line-based TCP server. Start it with `--host` or
the in-game **Multiplayer → Host** button, then connect with `--join` or
**Multiplayer → Join**. Once connected:

- block edits are broadcast and applied to all clients;
- player positions, names and facing are synchronized and rendered;
- `T` opens chat, with history and join/leave notices.

Mobs and attacks are still client-side/host-only; they are not authoritative
across the network in this build. `F5`/`F9`/`R` are single-player only.

## Layout

- `src/main.c3` — entry point, game loop, input and fixed-rate ticks.
- `src/game.c3` — item/block data, state and shared helpers.
- `src/world.c3`, `src/player.c3`, `src/entities.c3`, `src/logic.c3` — simulation.
- `src/network.c3` — TCP client and host server.
- `src/save.c3` — binary save/load and resource discovery.
- `src/ui.c3` — menus, HUD, inventory, stations, editors and world rendering.
