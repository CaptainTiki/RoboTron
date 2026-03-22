extends Enemy
class_name EnemyHeavy

@export var min_range: float = 5.0
@export var burst_count: int = 3

var burst_remaining: int = 0
var burst_timer: float = 0.0
const BURST_INTERVAL: float = 0.18

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
		velocity.x = 0.0
		velocity.z = 0.0

	_face_player()

	if burst_remaining > 0:
		burst_timer -= delta
		if burst_timer <= 0.0:
			burst_timer = BURST_INTERVAL
			burst_remaining -= 1
			_fire_shot()
	else:
		_try_attack(delta)

func _do_attack() -> void:
	burst_remaining = burst_count - 1
	burst_timer = BURST_INTERVAL
	_fire_shot()

func _fire_shot() -> void:
	if not player_node:
		return
	var from := global_position + Vector3(0, 1.4, 0)
	var target := player_node.global_position + Vector3(0, 1.0, 0)

	var proj: Projectile = PROJECTILE_SCENE.instantiate()
	proj.damage = attack_damage
	proj.color = Color(1.0, 0.5, 0.1)
	proj.collision_mask = 3  # world(1) + player(2)
	proj.speed = 18.0
	proj.direction = (target - from).normalized()
	get_parent().add_child(proj)
	proj.global_position = from
