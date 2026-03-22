extends Area3D
class_name RobotPart

const WOUND_SPARK_SCENE = preload("res://world/vfx/wound_spark.tscn")

## Exported reference to the logical parent in the damage propagation chain.
## Set this in the editor. Can point to any RobotPart — including a RobotBody,
## which terminates the chain. Leave null for orphaned parts.
@export var parent_part: RobotPart = null

## HP this part can absorb before detaching.
@export var part_hp: float = 10.0

## Fraction of incoming damage forwarded up to parent_part (0.5 = 50%).
@export var propagation_ratio: float = 0.5

## Linear speed of the debris impulse when this part blows off.
@export var detach_impulse: float = 5.0

var _hp: float
var _detached: bool = false

## Shared FIFO queue of all live debris RigidBody3Ds across every enemy.
## When the cap is exceeded the oldest piece is freed automatically.
static var _debris_queue: Array = []
const MAX_DEBRIS: int = 35


func _ready() -> void:
	_hp = part_hp
	collision_layer = 8  # layer 8 = robot parts, detected by player projectiles
	collision_mask  = 0  # parts don't detect anything themselves


## Universal damage entry point — called by projectile via area_entered.
## Damages this part, propagates a fraction up to parent_part, then detaches
## if HP is depleted.
func take_damage(amount: float, hit_position: Vector3 = Vector3.ZERO) -> void:
	if _detached:
		return
	_hp -= amount
	if parent_part != null and not parent_part._detached:
		parent_part.take_damage(amount * propagation_ratio, hit_position)
	if _hp <= 0.0:
		_detach(hit_position)


# ---- Private ----------------------------------------------------------------

func _detach(hit_position: Vector3) -> void:
	_detached = true

	# Capture world position now — reparent() will change our tree later.
	var sep_pos := global_position

	# Capture the arena reference NOW — after reparent we leave the enemy tree.
	var arena := _find_arena()

	# Notify the root body so it can track stagger thresholds.
	_notify_body_root()

	# Signal VFX system — one-shot burst at the separation point.
	SignalBus.piece_detached.emit(sep_pos)

	if not arena:
		visible = false
		return

	# Sample the mesh AABB before reparenting so we can size the debris collider.
	var mi := _get_first_mesh()
	var shape_size := Vector3(0.3, 0.3, 0.3)
	if mi and mi.mesh:
		# Multiply by 2 because Body is scaled 2x — AABB is in mesh-local space.
		shape_size = mi.mesh.get_aabb().size * 2.0 * 0.8

	# Build the physics carrier.
	var rb          := RigidBody3D.new()
	rb.collision_layer      = 16  # debris layer — nothing targets it
	rb.collision_mask       = 1   # bounces off world geometry only
	rb.contact_monitor      = true
	rb.max_contacts_reported = 1

	var col   := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = shape_size
	col.shape  = shape
	rb.add_child(col)

	arena.add_child(rb)
	rb.global_position = sep_pos  # position only — avoids baking Body scale into rb

	# reparent() with keep_global_transform=true moves this node (plus ALL its
	# children, including any child RobotParts) under rb while preserving
	# world positions. The 2x scale from Body stays baked into our local transform.
	reparent(rb, true)

	# Persistent wound spark — lives on the surviving parent part at the
	# separation point. Freed automatically when parent_part detaches or dies.
	if parent_part != null and not parent_part._detached:
		var spark := WOUND_SPARK_SCENE.instantiate() as CPUParticles3D
		parent_part.add_child(spark)
		spark.global_position = sep_pos

	# Apply outward impulse + random tumble.
	var away: Vector3
	if hit_position != Vector3.ZERO:
		away = (global_position - hit_position).normalized()
	else:
		away = Vector3(randf_range(-1.0, 1.0), 1.0, randf_range(-1.0, 1.0)).normalized()

	rb.linear_velocity = away * detach_impulse + Vector3(
		randf_range(-1.5, 1.5),
		randf_range(1.2, 3.5),
		randf_range(-1.5, 1.5)
	)
	rb.angular_velocity = Vector3(
		randf_range(-8.0, 8.0),
		randf_range(-8.0, 8.0),
		randf_range(-8.0, 8.0)
	)

	# Disable collision on self and any child RobotParts so they can't be hit
	# while they're mid-air.
	_disable_collision_recursive(self)

	# Emit ground-spark signal on first floor contact.
	var _grounded := false
	rb.body_entered.connect(func(_body: Node) -> void:
		if _grounded:
			return
		_grounded = true
		SignalBus.piece_grounded.emit(rb.global_position)
	)

	# FIFO debris cap — push new piece, evict oldest when over MAX_DEBRIS.
	# Stale entries from the previous wave are skipped via is_instance_valid.
	_debris_queue.append(rb)
	while _debris_queue.size() > MAX_DEBRIS:
		var oldest = _debris_queue.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


func _notify_body_root() -> void:
	# Walk parent_part chain to find the RobotBody and tell it a part was lost.
	var p: RobotPart = parent_part
	while p != null:
		if p is RobotBody:
			(p as RobotBody).on_part_detached()
			return
		p = p.parent_part


func _find_arena() -> Node3D:
	var p := get_parent()
	while p != null:
		if p is CharacterBody3D:
			return p.get_parent() as Node3D
		p = p.get_parent()
	return null


func _get_first_mesh() -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D:
			return child
	return null


func _disable_collision_recursive(node: Node) -> void:
	if node is Area3D:
		(node as Area3D).collision_layer = 0
		(node as Area3D).collision_mask  = 0
	for child in node.get_children():
		_disable_collision_recursive(child)
