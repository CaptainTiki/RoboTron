extends RobotPart
class_name RobotBody

## HP of the robot's core body. Override take_damage() so damage stops here
## with no further propagation — this is always the root of the chain.
## Child RobotParts point their parent_part export here.

@export var stagger_hp_ratio: float = 0.25       # stagger when HP falls below this fraction
@export var stagger_part_threshold: int = 3       # OR when this many parts have been lost

var _lost_parts: int = 0


func _ready() -> void:
	super._ready()
	parent_part = null  # body is always the chain root


## Override: absorbs damage with no upward propagation.
## Triggers stagger check and kills the enemy when HP hits zero.
func take_damage(amount: float, hit_position: Vector3 = Vector3.ZERO) -> void:
	if _detached:
		return
	_hp -= amount
	var enemy := get_parent() as Enemy
	if enemy:
		enemy._apply_hit_twitch()
	_check_stagger()
	if _hp <= 0.0:
		_kill_enemy()


## Called by any child RobotPart when it detaches.
func on_part_detached() -> void:
	_lost_parts += 1
	_check_stagger()
	var enemy := get_parent() as Enemy
	if enemy:
		enemy.stun(0.5)


# ---- Private ----------------------------------------------------------------

func _check_stagger() -> void:
	var enemy := get_parent() as Enemy
	if not enemy or enemy.is_staggered:
		return
	var hp_ratio := _hp / part_hp
	if hp_ratio <= stagger_hp_ratio or _lost_parts >= stagger_part_threshold:
		enemy._enter_stagger()


func _kill_enemy() -> void:
	_detached = true  # stop absorbing further damage
	var enemy := get_parent()
	if enemy and enemy.has_method("_die"):
		enemy._die()
