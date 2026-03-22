extends Node3D
class_name DestructionHandler

# Manages all DestructiblePiece children of an enemy's Body node.
# - Routes bullet hits to the nearest piece.
# - Spawns RigidBody3D debris when a piece detaches.
# - Detects when debris hits the floor and emits piece_grounded.
# - Notifies the parent enemy when enough pieces are gone to trigger a stagger.

@export var body_path: NodePath = NodePath("../Body")
@export var stagger_piece_threshold: int = 3  # pieces lost before forced stagger

var _pieces: Array[DestructiblePiece] = []
var _detached_count: int = 0


func _ready() -> void:
	var body := get_node_or_null(body_path)
	if not body:
		push_warning("DestructionHandler: could not find Body at '%s'" % body_path)
		return
	_collect_pieces(body)


# Called by enemy_base.take_damage — finds the piece nearest to the hit and damages it.
func on_hit(hit_position: Vector3, damage: float) -> void:
	var nearest: DestructiblePiece = null
	var nearest_dist := INF
	for piece in _pieces:
		if piece._detached:
			continue
		var d := piece.global_position.distance_to(hit_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = piece
	if nearest:
		nearest.take_hit(damage, hit_position)


# ---- Private ----------------------------------------------------------------

func _collect_pieces(node: Node) -> void:
	for child in node.get_children():
		if child is DestructiblePiece:
			_pieces.append(child)
			var p: DestructiblePiece = child
			p.detached.connect(func(impulse: Vector3) -> void: _spawn_debris(p, impulse))
		_collect_pieces(child)


func _spawn_debris(piece: DestructiblePiece, impulse: Vector3) -> void:
	_detached_count += 1

	# Notify parent enemy of piece loss — may trigger stagger.
	var enemy := get_parent()
	if enemy.has_method("on_piece_lost") and _detached_count >= stagger_piece_threshold:
		enemy.on_piece_lost(_detached_count)

	var mesh_inst := piece.get_mesh_instance()
	if not mesh_inst:
		return

	var rb           := RigidBody3D.new()
	rb.collision_layer = 16  # debris — nothing targets this
	rb.collision_mask  = 1   # collides with world only

	var mi := MeshInstance3D.new()
	mi.mesh              = mesh_inst.mesh
	mi.material_override = mesh_inst.material_override
	rb.add_child(mi)

	var col   := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh_inst.mesh.get_aabb().size * 0.75 if mesh_inst.mesh else Vector3(0.15, 0.15, 0.15)
	col.shape  = shape
	rb.add_child(col)

	rb.global_transform = piece.global_transform
	rb.linear_velocity  = impulse
	rb.angular_velocity = Vector3(
		randf_range(-8.0, 8.0),
		randf_range(-8.0, 8.0),
		randf_range(-8.0, 8.0)
	)

	# Debris lives in the arena (enemy's parent) so it survives enemy death.
	var arena := get_parent().get_parent()
	arena.add_child(rb)

	# Emit detach VFX at the piece's world position.
	SignalBus.piece_detached.emit(piece.global_position)

	# One-shot: detect first floor contact and emit ground sparks.
	var grounded := false
	rb.body_entered.connect(func(_body: Node) -> void:
		if grounded:
			return
		grounded = true
		SignalBus.piece_grounded.emit(rb.global_position)
	)

	# Auto-clean debris after it has settled.
	get_tree().create_timer(10.0).timeout.connect(func() -> void:
		if is_instance_valid(rb):
			rb.queue_free()
	)
