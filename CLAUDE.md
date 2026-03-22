# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Continuing a session?** Read `HANDOFF.md` in the project root first — it has current state, what was just built, and what to do next.

## Project Overview

**RoboTron** is a wave-based first-person arcade shooter built in **Godot 4.6**. Players battle progressively harder enemy waves, earn money from kills, and purchase/equip weapons between waves.

## Running the Game

Open `project.godot` in Godot 4.6 and press **F5** (or the Play button). There are no CLI build tools, Makefiles, or test runners — all development happens inside the Godot editor.

- **Engine:** Godot 4.6
- **Physics:** Jolt Physics (3D)
- **Rendering:** GL Compatibility (D3D12 on Windows)
- **Resolution:** 1920×1080

## Architecture

### Core Systems (`system/`)

| File | Role |
|------|------|
| `main.gd` | Top-level orchestrator — transitions between the loadout UI and the arena |
| `game_state.gd` | Global singleton holding all persistent state: money, current wave, owned/equipped weapons, `WEAPON_DATA` dictionary, and `get_wave_composition()` |
| `signal_bus.gd` | Central event hub; all cross-system communication goes through here (no direct node references between systems) |
| `wave_manager.gd` | Spawns enemies at staggered intervals, tracks kill count, emits `wave_complete` |
| `menu_manager.gd` | Handles menu scene stacking |
| `prefabs.gd` | Holds UIDs/paths for instancing menu scenes |

### Game World (`world/`)

- **`arenas/arena.gd`** — Instantiates the player and WaveManager; relays arena-level signals up to Main.
- **`player/player.gd`** — `CharacterBody3D` FPS controller. Manages weapon slots (1–3), projectile firing, and receives damage.
- **`enemies/enemy_base.gd`** — Base AI: seeks player, melee attacks, dies and awards money. Subclasses override `_behavior(delta)`: `Grunt` (basic), `Rusher` (fast), `Shooter` (ranged), `Heavy` (tanky, wave 2+).
- **`weapons/weapon_base.gd`** — Data-driven: reads stats from `GameState.WEAPON_DATA`. Manages ammo, fire rate timer, and reload. Concrete classes: `Pistol`, `SMG`, `Shotgun`.
- **`projectiles/projectile.gd`** — Physics-based bullet; applies damage on collision.
- **`ui/hud.gd`** — In-game HUD, reacts to `SignalBus` signals for health and ammo updates.

### Menus (`menusystem/`)

- **`loadoutmenu.gd`** — The between-wave shop and weapon-slot UI. Built entirely in GDScript (no complex scene layouts). Player cycles weapon slots and buys weapons/HP upgrades.
- **`menu.gd`** — Base class for all menus.

### Game Flow

```
Main
 └─ LoadoutMenu (equip weapons, spend money, click DEPLOY)
     └─ Arena
         ├─ Player  ←──── SignalBus ────→  HUD
         └─ WaveManager (spawns enemies)
             └─ wave_complete → back to LoadoutMenu
                 enemy_killed → award money via GameState
```

### Key Design Patterns

- **Signal-driven decoupling:** Systems never hold direct references to each other; everything communicates via `SignalBus`.
- **Inheritance for enemy AI:** Override `_behavior(delta)` in enemy subclasses to customise movement and attack.
- **Data-driven weapons:** All weapon stats live in `GameState.WEAPON_DATA`; `weapon_base.gd` reads them at runtime — adding a new weapon means adding an entry there plus a small subclass.
- **Programmatic UI:** The loadout menu and HUD are constructed fully in code rather than `.tscn` files.

### Wave Scaling

Enemy counts scale via `GameState.get_wave_composition()` using the multiplier `1.0 + (wave - 1) * 0.4`.

### Weapon Stats Reference

| Weapon | Damage | Fire Rate | Mag | Reload | Cost |
|--------|--------|-----------|-----|--------|------|
| Pistol | 35 | 0.5 s | 12 | 1.2 s | $0 |
| SMG | 15 | 0.09 s (auto) | 30 | 1.5 s | $500 |
| Shotgun | 18 ×8 pellets | 0.8 s | 8 | 2.0 s | $750 |
