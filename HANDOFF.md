# HANDOFF.md — Session State for Continuing Claude

> Read this at the start of each new session. Update it before ending a session.
> Last updated: 2026-03-25

---

## What Was Just Built

### AI State Machine (enemy_base.gd)
- Three states: `SEARCH`, `ALERT`, `LOST`
- **SEARCH** — enemy wanders slowly (35% speed), picking random nearby targets every 2–4s. Transitions to ALERT when player enters `DETECTION_RANGE` (18m).
- **ALERT** — full `_behavior(delta)` (subclass movement + attacks). Transitions to LOST if player exceeds `ALERT_RANGE` (28m).
- **LOST** — walks to `last_known_position`, rechecks for player. Returns to SEARCH after `LOST_TIMEOUT` (6s) if player not re-detected.
- Enemies also instantly go ALERT when hit (via `take_damage`).
- Subclasses (`grunt.gd`, `rusher.gd`, `shooter.gd`, `heavy.gd`) required no changes to `_behavior()` — the state machine wraps around them cleanly.

### Attack Telegraph (enemy_base.gd)
- `attack_windup: float` export on each enemy — pause before `_do_attack()` fires.
- During windup: eye turns **orange** (`Color(1.0, 0.55, 0.0)`) as a visual warning.
- After windup fires: eye resets to transparent (or stays with stagger red if staggered).
- Windup durations: Grunt 0.5s, Rusher 0.3s, Heavy 0.25s, Shooter 0.2s.
- Stagger flash takes priority over windup color (stagger = already dying).

### Flying Enemies (enemy_base.gd + shooter.gd + heavy.gd)
- `flies: bool` and `fly_height: float` exports on Enemy base.
- When `flies = true`: gravity replaced by spring hover toward `fly_height` world Y (`FLY_HOVER_SPEED = 5.0`).
- **Shooter** (`flies=true`, `fly_height=3.5`) and **Heavy** (`flies=true`, `fly_height=4.5`) are now drones.
- Grunt and Rusher remain ground units (wheels, not rotors).

### Wall Jump (player.gd)
- Jump input checks `is_on_wall_only()` when not on floor.
- Kicks player away from wall at 85% vertical + 90% horizontal speed.
- Camera kick applied for feel (`kick(-0.35, 0.0, -wall_normal.x * 0.4)`).

### Spawn Zones (arena.gd + wave_manager.gd)
- **Player** spawns at `Vector3(0, 1, 18)` — safe end (positive Z).
- **Enemy spawn points** all cluster at negative Z (danger end), max at Z=−22, flanking sides at Z=−6 to −20.
- No enemies spawn behind or beside the player at wave start.

### Dead Code Removed (enemy_base.gd)
- `on_piece_lost(count)` removed (was leftover from old DestructionHandler system).

---

## Immediately Pending (start here next session)

1. **Place RoboSpawner instances in the arena** — open `arena.tscn` in the Godot editor, drag in `world/components/robo_spawner.tscn`. Place spawners along the negative-Z wall (danger end). Orient them so their local +Z faces into the arena (the SpawnMarker at Z=1 should point toward the player area). No code needed — just placement.
2. **Test spawner sequence** — play the game, confirm: light flashes → light on → door opens → robot slides out → door closes → light off. Tune `FLASH_COUNT`, `SLIDE_DISTANCE`, `SLIDE_DURATION` in `robo_spawner.gd` if timing feels off.
3. **Test flying enemies** — confirm Shooter and Heavy hover at correct height and don't clip through floor. Adjust `fly_height` via Inspector override if needed.
4. **Test AI states** — confirm enemies wander, detect, pursue, and go LOST properly. Tune `DETECTION_RANGE` / `ALERT_RANGE` in `enemy_base.gd` if feel is off.
5. **Test attack telegraph** — orange eye flash should be clearly visible before melee connects. Tune `attack_windup` per enemy if too long/short.
6. **Test wall jump** — needs a vertical wall surface in the arena. Currently arena pillars should work.
7. **VFX QA** (carried over) — wound_spark positioning, all particle previews in editor.

---

## Bigger Things On Deck (from playtester session 2026-03-25)

### Needs Editor Work (Godot editor, not pure GDScript)
- **Spawner placement** — `robo_spawner.tscn` is built and scripted. Just needs instances placed in `arena.tscn` along the danger-end wall. Orient local +Z toward the player area.
- **Arena redesign** — current box+pillars needs: cover objects, elevated platforms, asymmetric layout for the safe-vs-danger zone to feel meaningful.
- **Hazards** — wall turrets (StaticBody3D with a simple raycast attack timer), lava pits (Area3D with `body_entered` → damage), spikes/saws (Area3D, periodic damage or instant kill).
- **Wall run** — needs long vertical walls in the arena for the player to run along. After arena redesign, add to `player.gd`: detect wall contact + horizontal momentum, suppress gravity briefly while holding movement key toward wall.

### Needs Code + Design
- **Parkour powerups** — reward chained wall jumps or aerial movement with a pickup. Design the pickup type first (speed? temp invincibility? ammo?).
- **Audio** — still zero sound. Biggest feel gap remaining.
- **"Press E" HUD prompt** — show on-screen when near a staggered enemy.
- **Low HP warning** — red vignette or screen flash.

---

## Key Architecture Facts (quick reference)

```
collision layers:  1=world  2=player  4=enemies  8=robot_parts  16=debris
projectile mask:   13  (world + enemies + robot_parts)
enemy AI states:   SEARCH (wander) → ALERT (engage) → LOST (search last pos)
fly hover:         velocity.y = (fly_height - global_position.y) * FLY_HOVER_SPEED
player spawn:      Vector3(18, 1, 0)  — safe end (positive X)
enemy spawns:      RoboSpawner instances (group "spawners") → fallback negative X cluster
spawner signals:   enemy_deployed(enemy) — right after add_child, before slide
                   spawn_finished       — after door closed + light off (_busy = false)
spawner sequence:  flash light (5×) → light on → open door → add enemy → enemy_deployed
                   → slide robot out (local -Z = into arena) → release AI → close door
                   → light off → spawn_finished
spawner orient:    SpawnMarker at local +Z (behind wall). Door faces local -Z into arena.
                   Slide direction is -global_transform.basis.z.
wave batch system: All enemies queued upfront + shuffled. _launch_next_batch() dispatches
                   one enemy per available spawner simultaneously. Waits for ALL spawners
                   in the batch to emit spawn_finished before launching next batch (0.8s gap).
                   Guarantees max 1 enemy per spawner slot. No overflow, no falling enemies.
Pool VFX parent:   /root/Pool  (Pool autoload, always alive)
arena cleanup:     arena.queue_free() at wave end frees all debris automatically
```

- `parent_part = NodePath("..")` for direct children of the enemy
- `parent_part = NodePath("../..") ` to skip a plain Node anchor (e.g. WeaponMount)
- `RobotBody` always has `parent_part = null` (chain root)
- Do NOT use `change_scene_to_file()` — Main manually instantiates Arena as a child

---

## Constraints to Remember
- No GitHub branches or pull requests — work directly on files
- Keep `take_damage(amount, position)` as the universal projectile contract
- Prefer direct signals over SignalBus where possible
- CPUParticles3D only (GL Compatibility renderer — no GPU particles)
