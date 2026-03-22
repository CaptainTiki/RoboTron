extends Node3D
class_name Weapon

signal reloaded(current_ammo: int, mag_size: int)

var weapon_id: String = ""
var damage: float = 0.0
var fire_rate: float = 0.5
var mag_size: int = 10
var reload_time: float = 1.5
var spread: float = 0.0
var pellets: int = 1
var is_auto: bool = false
var kick_pitch: float = 0.0
var kick_roll: float = 0.0

var current_ammo: int = 0
var is_reloading: bool = false
var fire_timer: float = 0.0
var reload_timer: float = 0.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var muzzle_point: Node3D = $MuzzlePoint

func setup(id: String, data: Dictionary) -> void:
	weapon_id = id
	damage = data["damage"]
	fire_rate = data["fire_rate"]
	mag_size = data["mag_size"]
	reload_time = data["reload_time"]
	spread = data["spread"]
	pellets = data["pellets"]
	is_auto = data["auto"]
	kick_pitch = data["kick_pitch"]
	kick_roll  = data["kick_roll"]
	current_ammo = mag_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data["color"]
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = mat

func can_fire() -> bool:
	return fire_timer <= 0.0 and current_ammo > 0 and not is_reloading

func fire() -> bool:
	if not can_fire():
		return false
	current_ammo -= 1
	fire_timer = fire_rate
	return true

func start_reload() -> void:
	if is_reloading or current_ammo == mag_size:
		return
	is_reloading = true
	reload_timer = reload_time

func tick(delta: float) -> void:
	if fire_timer > 0.0:
		fire_timer -= delta
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			is_reloading = false
			current_ammo = mag_size
			reloaded.emit(current_ammo, mag_size)
