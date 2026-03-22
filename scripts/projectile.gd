extends Area3D
class_name Projectile

@export var speed: float = 30.0
@export var damage: float = 10.0
@export var lifetime: float = 3.0

# Set before add_child so _ready() can read it
var direction: Vector3 = Vector3.BACK
var color: Color = Color(1.0, 0.3, 0.1, 1)

var _age: float = 0.0

@onready var _mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = mat
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	global_position += direction * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
