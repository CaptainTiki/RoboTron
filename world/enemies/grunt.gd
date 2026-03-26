extends Enemy
class_name EnemyGrunt

func _ready() -> void:
	super._ready()
	attack_windup = 0.5  # slow melee swing — clearly telegraphed

# Grunt: walks straight at player, melee attack. No special behavior.
func _behavior(delta: float) -> void:
	_seek_and_melee(delta)
