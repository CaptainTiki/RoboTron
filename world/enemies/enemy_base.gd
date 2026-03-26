extends CharacterBody3D
class_name Enemy

@export var hp: float = 50.0
@export var move_speed: float = 3.5
@export var money_value: int = 25
@export var attack_damage: float = 15.0
@export var attack_range: float = 1.6
@export var attack_rate: float = 1.0
@export var attack_windup: float = 0.45   # telegraph pause before attack fires
@export var flies: bool = false            # hover mode for rotor drones
@export var fly_height: float = 3.5       # world Y to hover at

var max_hp: float
var player_node: Player = null
var attack_timer: float = 0.0
var is_dead: bool = false

# ── AI State machine ─────────────────────────────────────────────────────────
enum AIState { SEARCH, ALERT, LOST }
var ai_state: AIState = AIState.SEARCH

var last_known_position: Vector3 = Vector3.ZERO
var _lost_timer: float = 0.0
var _search_dir_timer: float = 0.0
var _search_target: Vector3 = Vector3.ZERO

const DETECTION_RANGE: float = 18.0  # SEARCH → ALERT
const ALERT_RANGE: float    = 28.0   # ALERT → LOST when exceeded
const LOST_TIMEOUT: float   = 6.0    # LOST → SEARCH after this many seconds
const SEARCH_SPEED_MULT: float = 0.35

# ── Stagger state ─────────────────────────────────────────────────────────────
var is_staggered: bool = false

var _robot_body: RobotBody = null
var _flash_timer: float = 0.0
var _flash_state: bool = false
var _stun_timer: float = 0.0
var _twitch_timer: float = 0.0
var _hit_react_cooldown: float = 0.0
const FLASH_INTERVAL := 0.18
const STAGGER_SPEED_MULT := 0.2
const STAGGER_HP_THRESHOLD := 0.25
const TWITCH_DURATION := 0.14
const TWITCH_AMOUNT := 0.30
const HIT_REACT_COOLDOWN := 0.04

# ── Attack windup (telegraph) ─────────────────────────────────────────────────
var _winding_up: bool = false
var _windup_timer: float = 0.0

# ── Persistent degradation from part loss ────────────────────────────────────
var _speed_multiplier: float = 1.0
var _attack_multiplier: float = 1.0

# ── Periodic sputter sparks when heavily damaged ──────────────────────────────
const SPUTTER_INTERVAL_MIN: float = 1.2
const SPUTTER_INTERVAL_MAX: float = 3.0
var _sputter_timer: float = 0.0

# ── Physics ───────────────────────────────────────────────────────────────────
const GRAVITY: float = 9.8
const FLY_HOVER_SPEED: float = 5.0

signal died(money_earned: int)


func _ready() -> void:
	collision_layer = 4
	collision_mask  = 7  # world(1) + player(2) + enemies(4)
	max_hp          = hp
	add_to_group("enemies")
	_robot_body     = get_node_or_null("Body") as RobotBody
	_sputter_timer  = randf_range(SPUTTER_INTERVAL_MIN, SPUTTER_INTERVAL_MAX)
	_search_target  = global_position
	# Scout recon signals — every non-scout enemy responds to these.
	SignalBus.scout_found_player.connect(_on_scout_found_player)
	SignalBus.scout_lost_player.connect(_on_scout_lost_player)


## Override in EnemyScout so that signal handlers skip the scout itself.
func _is_scout() -> bool:
	return false


func _physics_process(delta: float) -> void:
	if is_dead or not player_node:
		return
	if _hit_react_cooldown > 0.0:
		_hit_react_cooldown -= delta

	if _stun_timer > 0.0:
		_stun_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		_tick_ai(delta)

	# Gravity vs hover
	if flies:
		velocity.y = (fly_height - global_position.y) * FLY_HOVER_SPEED
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta

	move_and_slide()

	if is_staggered:
		_tick_stagger_flash(delta)

	if _twitch_timer > 0.0:
		_twitch_timer -= delta
		if _twitch_timer <= 0.0 and _robot_body:
			_robot_body.position = Vector3.ZERO

	_tick_sputter(delta)


# ── AI state machine ──────────────────────────────────────────────────────────

func _tick_ai(delta: float) -> void:
	match ai_state:
		AIState.SEARCH:
			_search_wander(delta)
			if _detect_player():
				ai_state = AIState.ALERT
		AIState.ALERT:
			var dist: float = global_position.distance_to(player_node.global_position)
			if dist > ALERT_RANGE:
				last_known_position = player_node.global_position
				ai_state = AIState.LOST
				_lost_timer = LOST_TIMEOUT
			else:
				last_known_position = player_node.global_position
				_behavior(delta)
		AIState.LOST:
			_lost_wander(delta)


func _detect_player() -> bool:
	return global_position.distance_to(player_node.global_position) <= DETECTION_RANGE


func _search_wander(delta: float) -> void:
	_search_dir_timer -= delta
	if _search_dir_timer <= 0.0 or global_position.distance_to(_search_target) < 1.0:
		_search_dir_timer = randf_range(2.0, 4.0)
		var angle := randf_range(0.0, TAU)
		_search_target = global_position + Vector3(cos(angle) * 5.0, 0.0, sin(angle) * 5.0)

	var to_target := _search_target - global_position
	to_target.y = 0.0
	if to_target.length() > 0.5:
		var dir := to_target.normalized()
		var spd := move_speed * SEARCH_SPEED_MULT * _speed_multiplier
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		var look_pos := global_position + dir
		look_pos.y = global_position.y
		if look_pos.distance_to(global_position) > 0.05:
			look_at(look_pos, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)


func _lost_wander(delta: float) -> void:
	# Re-detect player first
	if _detect_player():
		ai_state = AIState.ALERT
		return

	_lost_timer -= delta
	if _lost_timer <= 0.0:
		ai_state = AIState.SEARCH
		_search_dir_timer = 0.0
		return

	# Walk toward last known position
	var to_target := last_known_position - global_position
	to_target.y = 0.0
	if to_target.length() > 1.5:
		var dir := to_target.normalized()
		var spd := move_speed * 0.55 * _speed_multiplier
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		var look_pos := global_position + dir
		look_pos.y = global_position.y
		if look_pos.distance_to(global_position) > 0.05:
			look_at(look_pos, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)


# ── Override in subclasses ────────────────────────────────────────────────────

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


# ── Attack with telegraph windup ──────────────────────────────────────────────

func _try_attack(delta: float) -> void:
	if _attack_multiplier <= 0.0:
		return

	if _winding_up:
		_windup_timer -= delta
		if _windup_timer <= 0.0:
			_winding_up = false
			if not is_staggered:
				_set_eye_color(Color.TRANSPARENT)
			if _attack_multiplier > 0.0:
				_do_attack()
		return

	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = attack_rate
		if attack_windup > 0.0:
			_winding_up = true
			_windup_timer = attack_windup
			if not is_staggered:
				_set_eye_color(Color(1.0, 0.55, 0.0))  # orange warning
		else:
			_do_attack()


func _do_attack() -> void:
	if player_node and player_node.has_method("take_damage"):
		player_node.take_damage(_effective_attack_damage(), global_position)


func _effective_attack_damage() -> float:
	return attack_damage * _attack_multiplier


# ── Damage handling ───────────────────────────────────────────────────────────

func take_damage(amount: float, hit_position: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return
	# Become alert on taking damage regardless of current AI state
	if ai_state == AIState.SEARCH or ai_state == AIState.LOST:
		ai_state = AIState.ALERT

	if _robot_body:
		_robot_body.take_damage(amount, hit_position)
	else:
		hp -= amount
		if hp <= 0.0:
			_die()
			return
		if not is_staggered and hp / max_hp <= STAGGER_HP_THRESHOLD:
			_enter_stagger()


# ── Part-loss callbacks (called by RobotBody) ─────────────────────────────────

func on_locomotion_part_lost(count: int) -> void:
	match count:
		1: _speed_multiplier = 0.55
		2: _speed_multiplier = 0.28
		_: _speed_multiplier = 0.12


func on_weapon_part_lost(count: int) -> void:
	match count:
		1: _attack_multiplier = 0.55
		2: _attack_multiplier = 0.2
		_: _attack_multiplier = 0.0


# ── Glory kill ────────────────────────────────────────────────────────────────

func glory_kill() -> int:
	if is_dead:
		return 0
	_die(true)
	return money_value * 2


func stun(duration: float) -> void:
	_stun_timer = maxf(_stun_timer, duration)


func react_to_hit(intensity: float = 1.0, stun_duration: float = 0.05) -> void:
	if _hit_react_cooldown > 0.0:
		return
	_hit_react_cooldown = HIT_REACT_COOLDOWN
	_apply_hit_twitch(intensity)
	if stun_duration > 0.0:
		stun(stun_duration)


func _apply_hit_twitch(intensity: float = 1.0) -> void:
	if not _robot_body:
		return
	var amount := TWITCH_AMOUNT * intensity
	_robot_body.position = Vector3(
		randf_range(-amount, amount),
		randf_range(-amount * 0.45, amount * 0.45),
		randf_range(-amount, amount)
	)
	_twitch_timer = TWITCH_DURATION


func _enter_stagger() -> void:
	is_staggered = true
	SignalBus.enemy_staggered.emit(self)


func _die(is_glory: bool = false) -> void:
	is_dead = true
	SignalBus.enemy_died_at.emit(global_position)
	died.emit(money_value)
	_explode_all_parts()
	queue_free()


func _explode_all_parts() -> void:
	if not _robot_body:
		return
	for child in _robot_body.get_children():
		if child is RobotPart and not (child as RobotPart)._detached:
			(child as RobotPart).force_detach()
	_robot_body._detached = false
	_robot_body.force_detach()


# ── Sputter sparks ────────────────────────────────────────────────────────────

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


# ── Eye/accent flash ──────────────────────────────────────────────────────────

func _tick_stagger_flash(delta: float) -> void:
	_flash_timer -= delta
	if _flash_timer > 0.0:
		return
	_flash_timer = FLASH_INTERVAL
	_flash_state = not _flash_state
	_set_eye_flash(_flash_state)


func _set_eye_flash(on: bool) -> void:
	_set_eye_color(Color(1.0, 0.1, 0.1) if on else Color.TRANSPARENT)


# ── Scout recon signal handlers ───────────────────────────────────────────────

## Scout found the player — immediately alert this enemy and redirect to pos.
func _on_scout_found_player(pos: Vector3) -> void:
	if is_dead or _is_scout():
		return
	last_known_position = pos
	ai_state = AIState.ALERT


## Scout was killed while tracking — push ALERT enemies into LOST so they
## walk to the last known position rather than continuing a direct pursuit.
func _on_scout_lost_player(last_pos: Vector3) -> void:
	if is_dead or _is_scout():
		return
	last_known_position = last_pos
	if ai_state == AIState.ALERT:
		ai_state = AIState.LOST
		_lost_timer = LOST_TIMEOUT


func _set_eye_color(c: Color) -> void:
	var body := get_node_or_null("Body")
	if not body:
		return
	var eye := body.find_child("Eye", true, false)
	if not eye or not eye is MeshInstance3D:
		return
	if c.a < 0.01:
		(eye as MeshInstance3D).material_override = null
		return
	var mat            := StandardMaterial3D.new()
	mat.shading_mode   = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color   = c
	mat.emission_enabled = true
	mat.emission       = c
	mat.emission_energy_multiplier = 4.0
	(eye as MeshInstance3D).material_override = mat
