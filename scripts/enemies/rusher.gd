extends Enemy
class_name EnemyRusher

# Rusher: sprints at player once in charge range, melee on contact.
const CHARGE_RANGE: float = 20.0
var charging: bool = false

func _behavior(delta: float) -> void:
	var dist: float = global_position.distance_to(player_node.global_position)
	if dist < CHARGE_RANGE:
		charging = true
	if charging:
		# Use boosted speed (already set high in data, but kick it further when close)
		var to_player := (player_node.global_position - global_position).normalized()
		velocity.x = to_player.x * move_speed
		velocity.z = to_player.z * move_speed
		_face_player()
		if dist < attack_range:
			velocity.x = 0.0
			velocity.z = 0.0
			_try_attack(delta)
	else:
		_seek_and_melee(delta)
