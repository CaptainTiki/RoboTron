extends Node3D

var weapon_id: String = ""
var damage: float = 0.0
var fire_rate: float = 0.5
var mag_size: int = 10
var reload_time: float = 1.5
var spread: float = 0.0
var pellets: int = 1
var is_auto: bool = false

var current_ammo: int = 0
var is_reloading: bool = false
var fire_timer: float = 0.0
var reload_timer: float = 0.0

func setup(id: String, data: Dictionary) -> void:
	weapon_id = id
	damage = data["damage"]
	fire_rate = data["fire_rate"]
	mag_size = data["mag_size"]
	reload_time = data["reload_time"]
	spread = data["spread"]
	pellets = data["pellets"]
	is_auto = data["auto"]
	current_ammo = mag_size
	_build_mesh(data["color"])

func _build_mesh(color: Color) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.06, 0.28)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	add_child(mi)

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
			SignalBus.player_ammo_changed.emit(current_ammo, mag_size)
