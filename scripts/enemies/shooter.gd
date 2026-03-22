extends Enemy
class_name EnemyShooter

@export var min_range: float = 7.0

const PROJECTILE_SCENE = preload("res://scenes/projectile.tscn")

func _behavior(delta: float) -> void:
	if not player_node:
		return
	var to_player := player_node.global_position - global_position
	var dist: float = to_player.length()

	if dist < min_range:
		var away := -to_player.normalized()
		velocity.x = away.x * move_speed
		velocity.z = away.z * move_speed
	elif dist > attack_range:
		var dir := to_player.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
	else:
		# Strafe sideways at ideal range
		var right := to_player.cross(Vector3.UP).normalized()
		velocity.x = right.x * move_speed
		velocity.z = right.z * move_speed

	_face_player()
	_try_attack(delta)

func _do_attack() -> void:
	if not player_node:
		return
	var from := global_position + Vector3(0, 1.4, 0)
	var target := player_node.global_position + Vector3(0, 1.0, 0)

	var proj: Projectile = PROJECTILE_SCENE.instantiate()
	proj.damage = attack_damage
	proj.color = Color(0.2, 0.5, 1.0)
	proj.collision_mask = 3  # world(1) + player(2)
	proj.speed = 22.0
	proj.direction = (target - from).normalized()
	get_parent().add_child(proj)
	proj.global_position = from
