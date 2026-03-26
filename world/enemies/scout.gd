extends Enemy
class_name EnemyScout

# ── Tuning ────────────────────────────────────────────────────────────────────
const SPOTLIGHT_DETECT_RANGE: float = 14.0  # max distance spotlight can detect player
const SPOTLIGHT_DETECT_ANGLE: float = 22.0  # half-angle of detection cone (degrees)
const SWEEP_SPEED:             float = 1.3   # radians / sec the spotlight pivots sweep
const SWEEP_MAX:               float = 1.05  # ± radians from centre the sweep travels
const ORBIT_MIN:               float = 7.0   # stay at least this far from player
const ORBIT_MAX:               float = 11.0  # don't drift further than this
const ROTOR_SPIN_SPEED:        float = 9.0   # visual spin, radians / sec
const TRANSMIT_INTERVAL:       float = 0.4   # seconds between position broadcasts

var _tracking:           bool  = false  # true while actively broadcasting player pos
var _sweep_angle:        float = 0.0
var _sweep_dir:          float = 1.0
var _transmit_timer:     float = 0.0

# Cached node refs — filled in _ready()
var _rotor_node:        RobotPart  = null
var _camera_arm:        RobotPart  = null
var _spotlight_pivot:   Node3D     = null
var _spotlight:         SpotLight3D = null


func _ready() -> void:
	super._ready()
	flies             = true
	fly_height        = 5.5
	move_speed        = 5.5   # quick — hard to run from
	hp                = 30.0
	max_hp            = 30.0
	money_value       = 15
	attack_windup     = 0.0   # no melee
	_attack_multiplier = 0.0  # permanently disable attack path

	_rotor_node       = get_node_or_null("Body/Rotor")        as RobotPart
	_camera_arm       = get_node_or_null("Body/CameraArm")    as RobotPart
	_spotlight_pivot  = get_node_or_null("SpotlightPivot")    as Node3D
	_spotlight        = get_node_or_null("SpotlightPivot/Spotlight") as SpotLight3D


## Marks self as a scout so enemy_base signal handlers skip it.
func _is_scout() -> bool:
	return true


# ── Per-frame visuals ─────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if is_dead:
		return

	# Spin rotor disc visually (only while attached).
	if _rotor_node and is_instance_valid(_rotor_node) and not _rotor_node._detached:
		_rotor_node.rotate_y(ROTOR_SPIN_SPEED * delta)

	# Spotlight pivot: sweep in SEARCH, aim directly at player when tracking.
	if _spotlight_pivot:
		if _tracking and player_node and is_instance_valid(player_node):
			# Lock onto player — look_at sets the SpotLight's world orientation.
			if _spotlight:
				_spotlight.look_at(player_node.global_position, Vector3.UP)
		else:
			# Pendulum sweep left / right in the pivot's local Y.
			_sweep_angle += _sweep_dir * SWEEP_SPEED * delta
			if absf(_sweep_angle) >= SWEEP_MAX:
				_sweep_dir *= -1.0
				_sweep_angle = clampf(_sweep_angle, -SWEEP_MAX, SWEEP_MAX)
			_spotlight_pivot.rotation.y = _sweep_angle


# ── AI overrides ──────────────────────────────────────────────────────────────

## Track whether we just left ALERT so we can reset _tracking cleanly.
func _tick_ai(delta: float) -> void:
	var was_alert: bool = (ai_state == AIState.ALERT)
	super._tick_ai(delta)
	if was_alert and ai_state != AIState.ALERT:
		_tracking = false


## Detection uses the spotlight cone geometry, not plain distance.
func _detect_player() -> bool:
	if not player_node or not _spotlight:
		return false
	if not _can_scan():
		return false

	var to_player: Vector3 = player_node.global_position - _spotlight.global_position
	if to_player.length() > SPOTLIGHT_DETECT_RANGE:
		return false

	# SpotLight3D shines in its local -Z direction.
	var beam_fwd: Vector3 = -_spotlight.global_transform.basis.z
	var dot: float = beam_fwd.dot(to_player.normalized())
	return dot >= cos(deg_to_rad(SPOTLIGHT_DETECT_ANGLE))


## ALERT behaviour: orbit the player, keep the spotlight on them, broadcast.
func _behavior(delta: float) -> void:
	if not player_node:
		return

	_orbit_player(delta)

	# First frame of contact: broadcast immediately.
	if not _tracking:
		_tracking = true
		_transmit_timer = 0.0

	# Periodic position broadcast — keeps all alerted enemies updated.
	_transmit_timer -= delta
	if _transmit_timer <= 0.0:
		_transmit_timer = TRANSMIT_INTERVAL
		if _can_scan():
			SignalBus.scout_found_player.emit(player_node.global_position)


## Death broadcast: all ALERT enemies drop to LOST with the player's last pos.
func _die(is_glory: bool = false) -> void:
	if _tracking and player_node and is_instance_valid(player_node):
		SignalBus.scout_lost_player.emit(player_node.global_position)
	super._die(is_glory)


# ── Helpers ───────────────────────────────────────────────────────────────────

## Keep a comfortable orbit distance; strafe to avoid hovering in place.
func _orbit_player(delta: float) -> void:
	var to_player: Vector3 = player_node.global_position - global_position
	var dist: float        = to_player.length()
	var spd: float         = move_speed * _speed_multiplier

	if dist < ORBIT_MIN:
		var away: Vector3 = -to_player.normalized()
		velocity.x = away.x * spd
		velocity.z = away.z * spd
	elif dist > ORBIT_MAX:
		var dir: Vector3 = to_player.normalized()
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
	else:
		# Strafe tangentially so the scout circles instead of hovering static.
		var right: Vector3 = to_player.cross(Vector3.UP).normalized()
		velocity.x = right.x * spd * 0.55
		velocity.z = right.z * spd * 0.55

	_face_player()


## Returns false when the camera arm has been shot off — scout goes blind.
func _can_scan() -> bool:
	if not _camera_arm:
		return true  # no arm node defined — assume intact
	return is_instance_valid(_camera_arm) and not _camera_arm._detached
