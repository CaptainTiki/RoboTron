# HANDOFF.md — Session State for Continuing Claude

> Read this at the start of each new session. Update it before ending a session.
> Last updated: 2026-03-22

---

## What Was Just Built

### Destruction System (complete)
- `world/components/robot_part.gd` — `RobotPart extends Area3D`. Each part IS its own hitbox (collision layer 8). Exported `parent_part: RobotPart` defines the damage chain. `take_damage()` damages self, propagates `amount * propagation_ratio` (50%) upward, then calls `_detach()` when HP hits zero.
- `world/components/robot_body.gd` — `RobotBody extends RobotPart`. Always the chain root (`parent_part = null`). Overrides `take_damage()` with no propagation. Calls `enemy._enter_stagger()` at HP/part-loss thresholds. Calls `enemy._die()` at zero HP.
- All 4 enemy scenes rewritten: `grunt.tscn`, `rusher.tscn`, `shooter.tscn`, `heavy.tscn` — each has a `Body` (RobotBody) with child `RobotPart` nodes for arms, wheels, rotors, weapons.
- Parts detach as `RigidBody3D` debris with physics impulse. Debris persists the full wave (no timer), FIFO capped at 35 pieces globally via `static var _debris_queue` in `robot_part.gd`.

### Enemy Feel (complete)
- **Hit twitch** — `enemy_base._apply_hit_twitch()` jerks the Body node a small random offset, springs back after 0.07s.
- **Part-loss stun** — `enemy_base.stun(0.5)` called by `robot_body.on_part_detached()`. Enemy freezes for 0.5s.
- **Stagger** — triggers at 25% body HP OR 3 parts lost. Eye mesh flashes red, move speed drops to 20%.
- **Glory kill** — press E within 2.5m of a staggered enemy. Instant kill, 2× money, +30 HP, camera kick.

### VFX System (complete, needs visual QA)
- `Pool` autoload (`system/pool.gd`) manages 4 object pools: `spark_burst`, `ground_sparks`, `death_explosion`, `impact_spark`.
- All VFX parented to Pool itself (not `current_scene`) — avoids Node-type parent issues.
- `_play_at()` casts to `Node3D` and uses `.call("play")` for safe dynamic dispatch.
- All QuadMesh particles now **billboard** to camera via `BaseMaterial3D.BILLBOARD_ENABLED` set in each script's `_ready()`.

### VFX Scenes (world/vfx/)
| Scene | Trigger | Color | Notes |
|-------|---------|-------|-------|
| `spark_burst.tscn` | `piece_detached` signal | bright yellow (1.0, 0.95, 0.3) | one-shot, 32 particles |
| `impact_spark.tscn` | `bullet_impact` signal | electric blue (0.45, 0.85, 1.0) | one-shot, 16 particles, small |
| `death_explosion.tscn` | `enemy_died_at` signal | orange-yellow (1.0, 0.7, 0.08) | one-shot, 80 particles |
| `ground_sparks.tscn` | `piece_grounded` signal | sparks orange + dark transparent smoke | looping, 5.5s duration |
| `wound_spark.tscn` | direct child in `_detach()` | electric blue (0.35, 0.75, 1.0) | looping, parented to surviving part |

---

## Immediately Pending (start here next session)

1. **Test wound_spark** — `robot_part._detach()` spawns it as a child of `parent_part` at the separation point. Needs live confirmation it appears and is positioned correctly.
2. **Visual QA pass** — open each `.tscn` in Godot editor, hit the "play" button in the particle preview to confirm billboard, color, and size look right before running the game.
3. **Remove dead code** — `on_piece_lost(count)` in `enemy_base.gd` around line 122. Leftover from old `DestructionHandler` system. Harmless but should go.

---

## Bigger Things On Deck

- **Audio** — no sound at all in the game yet. This is the single biggest feel gap. Hit sounds, weapon fire, enemy death, reload.
- **Wave feel** — does progression curve feel right? Enemy counts scale at `1.0 + (wave-1) * 0.4`. Worth a tuning pass.
- **Player feedback UI** — low HP warning, on-screen prompt when near a staggered enemy ("Press E").
- **Arena** — only one map. Could use cover objects and obstacles for more interesting combat.

---

## Key Architecture Facts (quick reference)

```
collision layers:  1=world  2=player  4=enemies  8=robot_parts  16=debris
projectile mask:   13  (world + enemies + robot_parts)
Pool VFX parent:   /root/Pool  (Pool autoload, always alive)
current_scene:     Main (plain Node) — NOT used for VFX parenting
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
