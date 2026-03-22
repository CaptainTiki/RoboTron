extends CharacterBody3D

const PROJECTILE_SCENE = preload("res://scenes/projectile.tscn")

const SPEED: float = 6.0
const SPRINT_SPEED: float = 10.0
const JUMP_VELOCITY: float = 5.0
const MOUSE_SENS: float = 0.002
const JOY_LOOK_SENS: float = 2.5
const GRAVITY: float = 9.8

var hp: int = 100
var max_hp: int = 100
var is_dead: bool = false

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon_holder: Node3D = $Head/Camera3D/WeaponHolder

var weapons: Array = []
var current_weapon_idx: int = 0

func _ready() -> void:
	hp = GameState.player_max_hp
	max_hp = GameState.player_max_hp

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_weapons()
	SignalBus.player_health_changed.emit(hp, max_hp)

func _setup_weapons() -> void:
	for slot_id in GameState.equipped_weapons:
		if slot_id == "":
			weapons.append(null)
			continue
		var weapon := _create_weapon(slot_id)
		weapons.append(weapon)
		weapon_holder.add_child(weapon)
		weapon.visible = false
	_switch_to_weapon(0)

func _create_weapon(weapon_id: String) -> Node:
	var script_map: Dictionary = {
		"pistol":  "res://scripts/weapons/pistol.gd",
		"smg":     "res://scripts/weapons/smg.gd",
		"shotgun": "res://scripts/weapons/shotgun.gd",
	}
	var weapon_node := Node3D.new()
	weapon_node.set_script(load(script_map.get(weapon_id, "res://scripts/weapons/weapon_base.gd")))
	weapon_node.setup(weapon_id, GameState.WEAPON_DATA[weapon_id])
	return weapon_node

func _switch_to_weapon(idx: int) -> void:
	if idx < 0 or idx >= weapons.size() or weapons[idx] == null:
		return
	for w in weapons:
		if w:
			w.visible = false
	current_weapon_idx = idx
	weapons[idx].visible = true
	var wid: String = weapons[idx].weapon_id
	SignalBus.player_weapon_changed.emit(GameState.WEAPON_DATA[wid]["name"])
	SignalBus.player_ammo_changed.emit(weapons[idx].current_ammo, weapons[idx].mag_size)

func _get_current_weapon():
	if current_weapon_idx < weapons.size():
		return weapons[current_weapon_idx]
	return null

func _input(event: InputEvent) -> void:
	if is_dead:
		return

	# Mouse look — always processed regardless of GUI filter
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotate_x(-event.relative.y * MOUSE_SENS)
		head.rotation.x = clamp(head.rotation.x, -PI / 2.1, PI / 2.1)

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	# Weapon switching
	if event.is_action_pressed("weapon_1"):
		_switch_to_weapon(0)
	elif event.is_action_pressed("weapon_2"):
		_switch_to_weapon(1)
	elif event.is_action_pressed("weapon_3"):
		_switch_to_weapon(2)

	# Non-auto shooting: handle in _input so it fires on the actual press event
	# and is never affected by GUI controls consuming mouse button events.
	if event.is_action_pressed("shoot"):
		var weapon = _get_current_weapon()
		if weapon and not weapon.is_auto:
			_fire_weapon(weapon)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Horizontal movement
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var spd: float = SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
	if direction.length() > 0.0:
		velocity.x = direction.x * spd
		velocity.z = direction.z * spd
	else:
		velocity.x = move_toward(velocity.x, 0.0, spd)
		velocity.z = move_toward(velocity.z, 0.0, spd)

	# Controller look (right stick)
	var joy_x: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var joy_y: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if abs(joy_x) > 0.15:
		rotate_y(-joy_x * JOY_LOOK_SENS * delta)
	if abs(joy_y) > 0.15:
		head.rotate_x(-joy_y * JOY_LOOK_SENS * delta)
		head.rotation.x = clamp(head.rotation.x, -PI / 2.1, PI / 2.1)

	move_and_slide()

	# Weapon tick and auto-fire
	var weapon = _get_current_weapon()
	if weapon:
		weapon.tick(delta)
		if weapon.is_auto and Input.is_action_pressed("shoot"):
			_fire_weapon(weapon)
		if Input.is_action_just_pressed("reload"):
			weapon.start_reload()

func _fire_weapon(weapon) -> void:
	if not weapon.can_fire():
		return
	weapon.fire()
	var col: Color = GameState.WEAPON_DATA[weapon.weapon_id]["color"]
	for _i in range(weapon.pellets):
		_spawn_projectile(weapon.damage, weapon.spread, col)
	SignalBus.player_ammo_changed.emit(weapon.current_ammo, weapon.mag_size)
	if weapon.current_ammo == 0:
		weapon.start_reload()

func _spawn_projectile(damage: float, spread: float, col: Color) -> void:
	var spread_vec := Vector3(
		randf_range(-spread, spread),
		randf_range(-spread, spread),
		-1.0
	)
	var dir: Vector3 = (camera.global_transform.basis * spread_vec).normalized()

	var proj: Projectile = PROJECTILE_SCENE.instantiate()
	proj.damage = damage
	proj.color = col
	proj.collision_mask = 5  # world(1) + enemies(4)
	proj.speed = 70.0
	proj.direction = dir
	get_parent().add_child(proj)
	proj.global_position = camera.global_position

func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= int(amount)
	hp = max(0, hp)
	SignalBus.player_health_changed.emit(hp, max_hp)
	if hp <= 0:
		_die()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	SignalBus.player_died.emit()
