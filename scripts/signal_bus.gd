extends Node

signal player_health_changed(current: int, maximum: int)
signal player_ammo_changed(current: int, maximum: int)
signal player_weapon_changed(weapon_name: String)
signal player_died()
signal enemy_killed(money: int)
signal wave_started(wave_num: int, total_enemies: int)
signal wave_enemy_count_changed(remaining: int)
signal wave_complete()
