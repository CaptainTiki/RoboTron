# Repository Guidelines

## Project Structure & Module Organization
`project.godot` is the entry point for this Godot 4.6 project. Core orchestration and autoload singletons live in `system/` (`main.gd`, `game_state.gd`, `signal_bus.gd`, `wave_manager.gd`). Gameplay content lives in `world/`, grouped by feature: `player/`, `enemies/`, `weapons/`, `projectiles/`, `ui/`, `arenas/`, and shared `components/` or `vfx/`. Menu scenes and scripts live in `menusystem/`. Design notes and roadmap docs are under `docs/`. Art and imported resources belong in `assets/`.

## Build, Test, and Development Commands
This repository is edited and run through the Godot editor; there is no Makefile, package manager, or automated CLI test suite in the repo.

- Open locally: `godot4.6 project.godot`
- Run the game: open `project.godot` in Godot 4.6 and press `F5`
- Edit the main flow: start from `system/main.tscn` and `system/main.gd`

Use the editor to validate scene references, input mappings, and imported assets after changes.

## Coding Style & Naming Conventions
Follow existing GDScript style: tabs for indentation, typed variables where practical, and one top-level class per script. Use `snake_case` for functions and variables, `UPPER_SNAKE_CASE` for constants, and scene/script filenames in lowercase with underscores such as `enemy_base.gd` or `loadoutmenu.tscn`. Keep systems decoupled through `SignalBus` instead of adding direct cross-scene dependencies. Put reusable gameplay data in `GameState` or dedicated base classes rather than duplicating values across scenes.

## Testing Guidelines
There are currently no automated tests. Every change should include a manual smoke test in Godot:

- Launch with `F5` and confirm the game boots into the loadout flow
- Deploy into a wave and verify player movement, combat, HUD updates, and wave completion
- Re-test any touched menu, weapon, enemy, or signal path end-to-end

If you add a new weapon or enemy, verify spawning, damage, and cleanup in-game.

## Commit & Pull Request Guidelines
Recent commits are short, feature-focused summaries such as `project setup` and `Robo Destruction`. Keep commit messages concise and imperative, describing the shipped change in one line. Pull requests should include a brief description, manual test notes, and linked issues if applicable. Add screenshots or short clips for UI, VFX, menu, or scene-layout changes so reviewers can validate behavior quickly.

## Contributor Notes
Read `HANDOFF.md` before continuing in-progress work, and use `CLAUDE.md` for the current architecture overview and gameplay assumptions.
