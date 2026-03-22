extends Node3D
class_name CameraRig

# --- Spring tuning ---
const KICK_STIFFNESS := 200.0   # higher = snappier return
const KICK_DAMPING   := 24.0    # higher = less oscillation

# --- Headbob ---
const BOB_FREQ       := 1.8     # cycles per unit of speed
const BOB_AMOUNT     := 0.035   # metres of vertical travel
const BOB_SIDE_RATIO := 0.4     # x sway relative to y bob
const BOB_RECOVER    := 10.0    # lerp speed back to rest

# --- Strafe lean ---
const MAX_LEAN       := 0.06    # radians (~3.4°)
const LEAN_SPEED     := 8.0

# --- Internal state ---
var _kick_vel := Vector3.ZERO   # (pitch, yaw, roll) radians/s
var _kick_rot := Vector3.ZERO   # current spring displacement, radians

var _bob_time  := 0.0
var _bob_pos   := Vector3.ZERO
var _lean_roll := 0.0


# Called every physics frame by Player with movement context.
func tick(delta: float, horizontal_speed: float, strafe_input: float, on_floor: bool) -> void:
	_tick_kick(delta)
	_tick_bob(delta, horizontal_speed, on_floor)
	_tick_lean(delta, strafe_input)

	position = _bob_pos
	rotation.x = _kick_rot.x
	rotation.y = _kick_rot.y
	rotation.z = _kick_rot.z + _lean_roll


# Add an impulse to the spring. pitch/yaw/roll are in radians/s.
# Positive pitch = camera kicks upward (recoil).
# Positive yaw   = camera kicks right.
# Positive roll  = camera rolls clockwise.
func kick(pitch: float, yaw: float, roll: float) -> void:
	_kick_vel.x += pitch
	_kick_vel.y += yaw
	_kick_vel.z += roll


func _tick_kick(delta: float) -> void:
	var acc := -KICK_STIFFNESS * _kick_rot - KICK_DAMPING * _kick_vel
	_kick_vel += acc * delta
	_kick_rot += _kick_vel * delta


func _tick_bob(delta: float, horizontal_speed: float, on_floor: bool) -> void:
	if on_floor and horizontal_speed > 0.5:
		_bob_time += delta * horizontal_speed * BOB_FREQ
		_bob_pos.y = sin(_bob_time * 2.0) * BOB_AMOUNT
		_bob_pos.x = sin(_bob_time)       * BOB_AMOUNT * BOB_SIDE_RATIO
	else:
		_bob_pos = _bob_pos.lerp(Vector3.ZERO, delta * BOB_RECOVER)


func _tick_lean(delta: float, strafe_input: float) -> void:
	var target := -strafe_input * MAX_LEAN
	_lean_roll  = lerp(_lean_roll, target, delta * LEAN_SPEED)
