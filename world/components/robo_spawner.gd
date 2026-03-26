extends Node3D
class_name RoboSpawner

# Emitted right after add_child — wave_manager connects enemy.died here
# so kills are counted even if the player shoots a sliding robot.
signal enemy_deployed(enemy: Enemy)

# Emitted when the full sequence is done (door closed, light off, _busy = false).
# wave_manager listens for this to know the spawner slot is free again.
signal spawn_finished

@onready var _anim:         AnimationPlayer = $AnimationPlayer
@onready var _spawn_marker: Marker3D        = $SpawnMarker
@onready var _light:        OmniLight3D     = $Light/OmniLight3D
@onready var _light_mesh:   MeshInstance3D  = $Light/MeshInstance3D

# ── Tuning ────────────────────────────────────────────────────────────────────
const FLASH_COUNT:        int   = 5      # how many blinks before the door opens
const FLASH_ON_TIME:      float = 0.12
const FLASH_OFF_TIME:     float = 0.14
const LIGHT_ENERGY_OFF:   float = 0.0
const LIGHT_ENERGY_ON:    float = 4.0   # bright active glow
const SLIDE_DISTANCE:     float = 2.5   # units the robot travels out of the door
const SLIDE_DURATION:     float = 0.55  # seconds for the slide tween
const CYCLE_DELAY_MIN:    float = 1.0   # random stagger / reset window (seconds)
const CYCLE_DELAY_MAX:    float = 3.0

var _busy: bool = false
var _light_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("spawners")

	# Build a shared emissive material for the light-bulb mesh so it glows.
	_light_mat = StandardMaterial3D.new()
	_light_mat.shading_mode    = BaseMaterial3D.SHADING_MODE_UNSHADED
	_light_mat.emission_enabled = true
	_light_mat.albedo_color    = Color(1.0, 0.35, 0.1)  # orange-red
	_light_mat.emission        = Color(1.0, 0.35, 0.1)
	_light_mat.emission_energy_multiplier = 0.0          # start dark
	_light_mesh.material_override = _light_mat

	_set_light(false)


# ── Public API ────────────────────────────────────────────────────────────────

func is_busy() -> bool:
	return _busy


## Called by wave_manager. Runs the full sequence asynchronously.
func spawn(enemy_scene: PackedScene, player_ref: CharacterBody3D) -> void:
	if _busy:
		return
	_busy = true
	_run_sequence(enemy_scene, player_ref)


# ── Spawn sequence ────────────────────────────────────────────────────────────

func _run_sequence(enemy_scene: PackedScene, player_ref: CharacterBody3D) -> void:
	# Pick one random duration for this cycle — used as both the startup delay
	# (staggers spawners so they don't fire in unison) and the reset cooldown
	# after the sequence ends (gives this spawner its own rhythm each wave).
	var cycle_delay: float = randf_range(CYCLE_DELAY_MIN, CYCLE_DELAY_MAX)

	# ── 0. Startup delay — each spawner activates at its own pace ─────────────
	await get_tree().create_timer(cycle_delay).timeout

	# ── 1. Telegraph: flash the warning light ─────────────────────────────────
	for i in range(FLASH_COUNT):
		_set_light(true)
		await get_tree().create_timer(FLASH_ON_TIME).timeout
		_set_light(false)
		await get_tree().create_timer(FLASH_OFF_TIME).timeout

	# ── 2. Light on solid — spawning is happening ─────────────────────────────
	_set_light(true)

	# ── 3. Open the door ──────────────────────────────────────────────────────
	_anim.play("open")
	await _anim.animation_finished

	# ── 4. Instantiate enemy frozen at the spawn marker ───────────────────────
	#    player_node = null keeps enemy_base from running physics or AI,
	#    so the robot is completely inert during the slide.
	var enemy: Enemy = enemy_scene.instantiate() as Enemy
	enemy.player_node = null
	get_parent().add_child(enemy)
	enemy.global_position = _spawn_marker.global_position

	# Tell wave_manager NOW so it can connect enemy.died immediately.
	# This way kills are counted even if the player shoots the sliding robot.
	enemy_deployed.emit(enemy)

	# ── 5. Slide robot out of the door ────────────────────────────────────────
	#    SpawnMarker is at local +Z (behind the door wall).
	#    Door opening faces local -Z into the arena, so slide in -Z.
	var slide_end: Vector3 = _spawn_marker.global_position \
		- global_transform.basis.z * SLIDE_DISTANCE

	var tween := get_tree().create_tween()
	tween.tween_property(enemy, "global_position", slide_end, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished

	# ── 6. Release — enable AI by giving the enemy a player reference ─────────
	if is_instance_valid(enemy) and not enemy.is_dead:
		enemy.player_node = player_ref
		# Enemy starts in SEARCH state by default (see enemy_base.gd).
		# It will detect the player once they come within DETECTION_RANGE.

	# ── 7. Close the door ─────────────────────────────────────────────────────
	_anim.play("close")
	await _anim.animation_finished

	# ── 8. Light off ──────────────────────────────────────────────────────────
	_set_light(false)

	# ── 9. Reset cooldown — same duration as the startup delay ────────────────
	#    Keeps this spawner unavailable for its own cycle time before the next
	#    wave_manager batch can claim it.
	await get_tree().create_timer(cycle_delay).timeout

	_busy = false
	spawn_finished.emit()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _set_light(on: bool) -> void:
	var energy: float = LIGHT_ENERGY_ON if on else LIGHT_ENERGY_OFF
	_light.light_energy = energy
	_light_mat.emission_energy_multiplier = 3.0 if on else 0.0
