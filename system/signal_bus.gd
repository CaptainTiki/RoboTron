extends Node

signal player_health_changed(current: int, maximum: int)
signal player_ammo_changed(current: int, maximum: int)
signal player_weapon_changed(weapon_name: String)
signal player_died()
signal enemy_killed(money: int)
signal wave_started(wave_num: int, total_enemies: int)
signal wave_enemy_count_changed(remaining: int)
signal wave_complete()
signal bullet_impact(world_position: Vector3)
signal piece_detached(world_position: Vector3)
signal piece_grounded(world_position: Vector3)
signal enemy_died_at(world_position: Vector3)
signal enemy_staggered(enemy: Node3D)
signal glory_kill_performed()

# Scout drone recon signals.
# scout_found_player  → all enemies snap to ALERT at the broadcast position.
# scout_lost_player   → all ALERT enemies drop to LOST (scout was killed).
signal scout_found_player(position: Vector3)
signal scout_lost_player(last_position: Vector3)
