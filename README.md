# Estado Totalitario Mod for Luanti/Minetest

> [!IMPORTANT]
> ⚠️ **Development Note:** This mod is now part of the larger **[Enclave Mod](https://github.com/ronrob-lu/enclave)** project and is no longer developed as a standalone mod.
> 
> **Original Author:** [ronrob-lu](https://github.com/ronrob-lu) (2026)

This mod introduces a high-tension survival challenge to Luanti/Minetest, where hostile patrol NPCs spawn in the distance to track, chase, and attack players.

---

## Gameplay Mechanics

### Spawning Rules
- **Distance**: NPCs spawn approximately **80 to 120 blocks away** from connected players.
- **Stealth Spawns**: Spawning checks ensure NPCs only spawn **out of direct line of sight** (e.g., behind hills, walls, or trees) to prevent them from suddenly appearing in front of you.
- **Spawn Limits**:
  - Maximum of **10 active NPCs** in the world at any given time.
  - A global game-wide limit of **1000 total kills** (saved to mod storage). Once this limit is reached, spawns stop permanently until reset by an admin.

### Enemy Behavior & Stats
- **Health**: 20 HP (10 hearts).
- **Damage**: Deals 2 damage (1 heart) on contact, with an attack cooldown of 0.8 seconds.
- **Speed & Agility**: Moves at a quick chase speed of 3.5.
- **Pathfinding & Obstacles**:
  - NPCs will actively leap (jump) over solid obstacles up to ~1.2 blocks high.
  - They cannot walk through solid walls.
  - **Water & Lava avoidance**: NPCs will detect liquids ahead of them and immediately stop moving/turn back to avoid drowning or burning.
- **Vulnerabilities**:
  - **Lava**: Deals 4 damage per tick.
  - **Water / Other Liquids**: Deals 1 damage per tick.

---

## Admin Commands

Server administrators with the `server` privilege can use the following commands in the chat console:

* `/reset_estado`
  Resets the global kill counter back to `0`, allowing NPC spawning to resume.
* `/clear_estado`
  Instantly despawns all active Estado NPCs currently in the world.

---

## Installation

1. Copy this folder into your Luanti/Minetest `mods` directory (rename the folder to `estado_totalitario`).
2. Enable the mod in your world configuration or menu.
3. Start or reload your world.

---

## Requirements

- **Luanti** (formerly Minetest) 5.0.0 or newer.

---

## License & Credits

- **Code**: MIT License (Copyright (c) 2026 ronrob-lu) - see [LICENSE.md](LICENSE.md)
- **Graphics/Models/Textures**: CC0 1.0 Universal (Public Domain) - see [LICENSE.md](LICENSE.md)
- **Design & Assets**: Created by [ronrob-lu](https://github.com/ronrob-lu).