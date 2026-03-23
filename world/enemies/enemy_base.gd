extends CharacterBody3D
class_name Enemy

@export var hp: float = 50.0
@export var move_speed: float = 3.5
@export var money_value: int = 25
@export var attack_damage: float = 15.0
@export var attack_range: float = 1.6
@export var attack_rate: float = 1.0

var max_hp: float
var player_node: Player = null
var attack_timer: float = 0.0
var is_dead: bool = false

# Stagger state — set by HP threshold or piece-loss threshold.
var is_staggered: bool = false

var _robot_body: RobotBody = null
var _flash_timer: float = 0.0
var _flash_state: bool = false
var _stun_timer: float = 0.0
var _twitch_timer: float = 0.0
const FLASH_INTERVAL := 0.18
const STAGGER_SPEED_MULT := 0.2
const STAGGER_HP_THRESHOLD := 0.25  # 25% HP triggers stagger
const TWITCH_DURATION := 0.07
const TWITCH_AMOUNT := 0.07

# Persistent degradation from part loss — not reset by stagger ending.
var _speed_multiplier: float = 1.0
var _attack_multiplier: float = 1.0

# Periodic sputter sparks when body HP < 50%.
const SPUTTER_INTERVAL_MIN: float = 1.2
const SPUTTER_INTERVAL_MAX: float = 3.0
var _sputter_timer: float = 0.0

signal died(money_earned: int)

const GRAVITY: float = 9.8


func _ready() -> void:
	collision_layer = 4
	collision_mask  = 7  # world(1) + player(2) + enemies(4)
	max_hp          = hp
	add_to_group("enemies")
	_robot_body = get_node_or_null("Body") as RobotBody
	_sputter_timer = randf_range(SPUTTER_INTERVAL_MIN, SPUTTER_INTERVAL_MAX)


func _physics_process(delta: float) -> void:
	if is_dead or not player_node:
		return
	if _stun_timer > 0.0:
		_stun_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		_behavior(delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()

	if is_staggered:
		_tick_stagger_flash(delta)

	if _twitch_timer > 0.0:
		_twitch_timer -= delta
		if _twitch_timer <= 0.0 and _robot_body:
			_robot_body.position = Vector3.ZERO

	_tick_sputter(delta)


# Override in subclasses.
func _behavior(delta: float) -> void:
	_seek_and_melee(delta)


func _seek_and_melee(delta: float) -> void:
	var to_player: Vector3 = player_node.global_position - global_position
	var dist: float        = to_player.length()
	var effective_speed    = move_speed * _speed_multiplier * (STAGGER_SPEED_MULT if is_staggered else 1.0)

	if dist < attack_range:
		velocity.x = 0.0
		velocity.z = 0.0
		_try_attack(delta)
	else:
		var dir: Vector3 = to_player.normalized()
		velocity.x = dir.x * effective_speed
		velocity.z = dir.z * effective_speed
		_face_player()


func _face_player() -> void:
	if not player_node:
		return
	var look_target := Vector3(player_node.global_position.x, global_position.y, player_node.global_position.z)
	if look_target.distance_to(global_position) > 0.05:
		look_at(look_target, Vector3.UP)


func _try_attack(delta: float) -> void:
	if _attack_multiplier <= 0.0:
		return
	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = attack_rate
		_do_attack()


func _do_attack() -> void:
	if player_node and player_node.has_method("take_damage"):
		player_node.take_damage(_effective_attack_damage(), global_position)


func _effective_attack_damage() -> float:
	return attack_damage * _attack_multiplier


func take_damage(amount: float, hit_position: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return
	if _robot_body:
		# Delegate entirely to the RobotBody — it owns HP, stagger, and death.
		_robot_body.take_damage(amount, hit_position)
	else:
		# Fallback for enemies that have no RobotBody scene node.
		hp -= amount
		if hp <= 0.0:
			_die()
			return
		if not is_staggered and hp / max_hp <= STAGGER_HP_THRESHOLD:
			_enter_stagger()


# Called by DestructionHandler when enough pieces are blown off.
func on_piece_lost(count: int) -> void:
	if not is_staggered:
		_enter_stagger()


## Called by RobotBody when a locomotion part detaches.
## Permanently reduces move speed based on how many have been lost.
func on_locomotion_part_lost(count: int) -> void:
	match count:
		1: _speed_multiplier = 0.55
		2: _speed_multiplier = 0.28
		_: _speed_multiplier = 0.12


## Called by RobotBody when a weapon part detaches.
## Reduces or disables attack capability based on losses.
func on_weapon_part_lost(count: int) -> void:
	match count:
		1: _attack_multiplier = 0.55
		2: _attack_multiplier = 0.2
		_: _attack_multiplier = 0.0


# Instant execution triggered by the player's glory kill.
# Returns the bonus money value so the player can reward appropriately.
func glory_kill() -> int:
	if is_dead:
		return 0
	_die(true)
	return money_value * 2


# Brief full-stop after losing a part — enemy "recalculates".
func stun(duration: float) -> void:
	_stun_timer = maxf(_stun_timer, duration)


# Micro-jerk on the Body node to sell the bullet impact.
func _apply_hit_twitch() -> void:
	if not _robot_body:
		return
	_robot_body.position = Vector3(
		randf_range(-TWITCH_AMOUNT, TWITCH_AMOUNT),
		randf_range(-TWITCH_AMOUNT * 0.5, TWITCH_AMOUNT * 0.5),
		randf_range(-TWITCH_AMOUNT, TWITCH_AMOUNT)
	)
	_twitch_timer = TWITCH_DURATION


func _enter_stagger() -> void:
	is_staggered = true
	SignalBus.enemy_staggered.emit(self)


func _die(is_glory: bool = false) -> void:
	is_dead = true
	SignalBus.enemy_died_at.emit(global_position)
	died.emit(money_value)
	queue_free()


# ---- Sputter sparks — periodic burst when heavily damaged ------------------

func _tick_sputter(delta: float) -> void:
	if not _robot_body:
		return
	if _robot_body._hp / _robot_body.part_hp > 0.5:
		return
	_sputter_timer -= delta
	if _sputter_timer <= 0.0:
		_sputter_timer = randf_range(SPUTTER_INTERVAL_MIN, SPUTTER_INTERVAL_MAX)
		SignalBus.piece_detached.emit(global_position + Vector3(
			randf_range(-0.2, 0.2), 0.8, randf_range(-0.2, 0.2)
		))


# ---- Stagger visual — eye/accent mesh flash ---------------------------------

func _tick_stagger_flash(delta: float) -> void:
	_flash_timer -= delta
	if _flash_timer > 0.0:
		return
	_flash_timer = FLASH_INTERVAL
	_flash_state = not _flash_state
	_set_eye_flash(_flash_state)


func _set_eye_flash(on: bool) -> void:
	# Find the "Eye" node anywhere in the Body hierarchy and swap its material.
	var body := get_node_or_null("Body")
	if not body:
		return
	var eye := body.find_child("Eye", true, false)
	if not eye or not eye is MeshInstance3D:
		return
	if on:
		var mat            := StandardMaterial3D.new()
		mat.shading_mode   = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color   = Color(1.0, 0.1, 0.1)
		mat.emission_enabled = true
		mat.emission       = Color(1.0, 0.1, 0.1)
		mat.emission_energy_multiplier = 4.0
		eye.material_override = mat
	else:
		eye.material_override = null  # revert to scene-defined material
