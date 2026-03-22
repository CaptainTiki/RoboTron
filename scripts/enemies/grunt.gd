extends Enemy
class_name EnemyGrunt

# Grunt: walks straight at player, melee attack. No special behavior.
func _behavior(delta: float) -> void:
	_seek_and_melee(delta)
