extends Area3D
class_name Projectile

@export var speed: float = 45.0
@export var damage: float = 10.0
@export var lifetime: float = 3.0

# Set before add_child so _ready() can read it
var direction: Vector3 = Vector3.BACK
var color: Color = Color(1.0, 0.3, 0.1, 1)

var _age: float = 0.0
var _hit: bool = false  # prevents double-processing if body and area fire same frame
var _previous_position: Vector3

@onready var _mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = mat
	_previous_position = global_position
	_update_visual_orientation()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	var start := global_position
	var end := start + direction * speed * delta
	_previous_position = start
	if _sweep_hit(start, end):
		return

	global_position = end
	_update_visual_orientation()

# Hits world geometry or the enemy CharacterBody3D (catch-all capsule).
func _on_body_entered(body: Node3D) -> void:
	if _hit:
		return
	_hit = true
	SignalBus.bullet_impact.emit(global_position)
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	queue_free()

# Hits a RobotPart or RobotBody Area3D — more precise than the capsule.
# Takes priority because area_entered fires before body_entered in Godot's
# physics step when both overlap in the same frame.
func _on_area_entered(area: Node3D) -> void:
	if _hit:
		return
	if not area.has_method("take_damage"):
		return
	_hit = true
	SignalBus.bullet_impact.emit(global_position)
	area.take_damage(damage, global_position)
	queue_free()


func _sweep_hit(start: Vector3, end: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(start, end, collision_mask, [self])
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false

	var collider = hit.get("collider")
	global_position = hit.get("position", end)
	if _hit:
		return true
	_hit = true
	SignalBus.bullet_impact.emit(global_position)
	if collider and collider.has_method("take_damage"):
		collider.take_damage(damage, global_position)
	queue_free()
	return true


func _update_visual_orientation() -> void:
	if direction.length_squared() <= 0.0001:
		return
	look_at(global_position + direction, Vector3.UP)
