extends Node3D
class_name DestructiblePiece

signal detached(impulse: Vector3)

@export var piece_hp: float = 40.0
@export var detach_impulse: float = 4.5

var _hp: float
var _detached: bool = false


func _ready() -> void:
	_hp = piece_hp


# Called by DestructionHandler when a bullet lands near this piece.
func take_hit(amount: float, hit_position: Vector3) -> void:
	if _detached:
		return
	_hp -= amount
	if _hp <= 0.0:
		_do_detach(hit_position)


# Returns the first MeshInstance3D child — used by DestructionHandler to clone the visual.
func get_mesh_instance() -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D:
			return child
	return null


func _do_detach(hit_position: Vector3) -> void:
	_detached = true
	var away := (global_position - hit_position).normalized()
	var impulse := away * detach_impulse + Vector3(
		randf_range(-1.5, 1.5),
		randf_range(1.2, 3.5),
		randf_range(-1.5, 1.5)
	)
	detached.emit(impulse)
	visible = false
