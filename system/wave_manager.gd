extends Node

var player_ref: CharacterBody3D = null
var total_enemies: int = 0
var killed_count: int = 0
var alive_enemies: Array = []

signal wave_complete()

# ── Spawn queue & batch state ─────────────────────────────────────────────────
# All enemies for this wave are queued upfront as type strings.
# _launch_next_batch() drains the queue N at a time, where N = spawner count.
# A new batch only starts after every spawner in the previous batch has fully
# finished its sequence (door closed, light off).  This guarantees max one
# enemy per spawner slot at any moment.

var _spawn_queue: Array = []      # remaining enemy type strings for this wave
var _batch_remaining: int = 0     # spawners still running in the current batch


const ENEMY_SCENES: Dictionary[String, PackedScene] = {
	"grunt":   preload("res://world/enemies/grunt.tscn"),
	"shooter": preload("res://world/enemies/shooter.tscn"),
	"rusher":  preload("res://world/enemies/rusher.tscn"),
	"heavy":   preload("res://world/enemies/heavy.tscn"),
	"scout":   preload("res://world/enemies/scout.tscn"),
}


func start_wave(player: CharacterBody3D) -> void:
	player_ref    = player
	killed_count  = 0
	alive_enemies.clear()
	_spawn_queue.clear()
	_batch_remaining = 0

	# Build the full enemy list for this wave and shuffle it for variety.
	var composition: Array = GameState.get_wave_composition()
	for group in composition:
		for _i in range(int(group["count"])):
			_spawn_queue.append(group["type"])
	_spawn_queue.shuffle()

	total_enemies = _spawn_queue.size()
	SignalBus.wave_started.emit(GameState.current_wave, total_enemies)
	SignalBus.wave_enemy_count_changed.emit(total_enemies)

	_launch_next_batch()


# ── Batch spawning ────────────────────────────────────────────────────────────

func _launch_next_batch() -> void:
	if _spawn_queue.is_empty():
		return

	var spawners: Array = _get_available_spawners()

	if spawners.is_empty():
		# No RoboSpawners placed in the scene — dev fallback: drop enemies
		# directly at safe-ish positions so the wave can still be completed.
		_direct_spawn_remaining()
		return

	# Take as many enemies as we have spawner slots (never more than 1 per slot).
	var count: int = mini(_spawn_queue.size(), spawners.size())
	_batch_remaining = count

	for i in range(count):
		var type: String = _spawn_queue.pop_front()
		var spawner: RoboSpawner = spawners[i]

		# enemy_deployed fires right after add_child → register for kill tracking.
		spawner.enemy_deployed.connect(_on_enemy_deployed, CONNECT_ONE_SHOT)

		# spawn_finished fires after door-close + light-off → batch counter tick.
		spawner.spawn_finished.connect(_on_spawner_finished, CONNECT_ONE_SHOT)

		spawner.spawn(ENEMY_SCENES[type], player_ref)


func _on_spawner_finished() -> void:
	_batch_remaining -= 1
	if _batch_remaining <= 0 and not _spawn_queue.is_empty():
		# All spawners in this batch are fully cycled. Brief inter-batch pause,
		# then release the next group.
		get_tree().create_timer(0.8).timeout.connect(_launch_next_batch, CONNECT_ONE_SHOT)


# ── Enemy tracking ────────────────────────────────────────────────────────────

# Called by spawner right after add_child (enemy is in the scene, AI still frozen).
func _on_enemy_deployed(enemy: Enemy) -> void:
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


# ── Helpers ───────────────────────────────────────────────────────────────────

func _get_available_spawners() -> Array:
	return get_tree().get_nodes_in_group("spawners").filter(
		func(s: Node) -> bool: return s is RoboSpawner and not s.is_busy()
	)


# Dev/fallback: called only when no RoboSpawners exist in the scene at all.
# Spawns everything left in the queue directly with a stagger delay.
func _direct_spawn_remaining() -> void:
	const POSITIONS: Array = [
		Vector3(-20.0, 0.5,   0.0), Vector3(-18.0, 0.5, -15.0),
		Vector3(-18.0, 0.5,  15.0), Vector3(-12.0, 0.5, -28.0),
		Vector3(-12.0, 0.5,  28.0), Vector3( -4.0, 0.5, -32.0),
		Vector3( -4.0, 0.5,  32.0), Vector3(  4.0, 0.5, -28.0),
		Vector3(  4.0, 0.5,  28.0),
	]
	var delay: float = 0.3
	while not _spawn_queue.is_empty():
		var type: String = _spawn_queue.pop_front()
		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(func():
			if not player_ref or not is_instance_valid(player_ref):
				return
			var enemy: Enemy = ENEMY_SCENES[type].instantiate()
			enemy.position    = POSITIONS[randi() % POSITIONS.size()]
			enemy.player_node = player_ref
			get_parent().add_child(enemy)
			enemy.died.connect(_on_enemy_died)
			alive_enemies.append(enemy)
		)
		delay += 0.35
