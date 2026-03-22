extends Node

var player_ref: CharacterBody3D = null
var total_enemies: int = 0
var killed_count: int = 0
var alive_enemies: Array = []

signal wave_complete()

const SPAWN_POSITIONS: Array = [
	Vector3(-44.0, 0.5, -19.0),
	Vector3( 44.0, 0.5, -19.0),
	Vector3(-44.0, 0.5,  19.0),
	Vector3( 44.0, 0.5,  19.0),
	Vector3(  0.0, 0.5, -22.0),
	Vector3(  0.0, 0.5,  22.0),
	Vector3(-44.0, 0.5,   0.0),
	Vector3( 44.0, 0.5,   0.0),
]

const ENEMY_SCENES : Dictionary[String, PackedScene]= {
	"grunt":   preload("res://scenes/enemies/grunt.tscn"),
	"shooter": preload("res://scenes/enemies/shooter.tscn"),
	"rusher":  preload("res://scenes/enemies/rusher.tscn"),
	"heavy":   preload("res://scenes/enemies/heavy.tscn"),
}

func start_wave(player: CharacterBody3D) -> void:
	player_ref = player
	killed_count = 0
	alive_enemies.clear()

	var composition: Array = GameState.get_wave_composition()
	total_enemies = 0
	for group in composition:
		total_enemies += int(group["count"])

	SignalBus.wave_started.emit(GameState.current_wave, total_enemies)
	SignalBus.wave_enemy_count_changed.emit(total_enemies)

	var delay: float = 0.5
	for group in composition:
		for _i in range(int(group["count"])):
			var timer := get_tree().create_timer(delay)
			var etype: String = group["type"]
			timer.timeout.connect(func(): _spawn_enemy(etype))
			delay += 0.35

func _spawn_enemy(type: String) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return

	var enemy : Enemy = ENEMY_SCENES[type].instantiate()
	enemy.position = SPAWN_POSITIONS[randi() % SPAWN_POSITIONS.size()]
	enemy.player_node = player_ref

	get_parent().add_child(enemy)
	enemy.died.connect(_on_enemy_died)
	alive_enemies.append(enemy)

func _on_enemy_died(money_earned: int) -> void:
	killed_count += 1
	GameState.add_money(money_earned)
	SignalBus.enemy_killed.emit(money_earned)
	SignalBus.wave_enemy_count_changed.emit(total_enemies - killed_count)

	if killed_count >= total_enemies:
		await get_tree().create_timer(1.5).timeout
		wave_complete.emit()
