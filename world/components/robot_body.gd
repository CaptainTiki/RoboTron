extends RobotPart
class_name RobotBody

## HP of the robot's core body. Override take_damage() so damage stops here
## with no further propagation — this is always the root of the chain.
## Child RobotParts point their parent_part export here.

@export var stagger_hp_ratio: float = 0.25       # stagger when HP falls below this fraction
@export var stagger_part_threshold: int = 3       # OR when this many parts have been lost

## Chance per body hit that an internal component blows out and a part ejects.
const EJECT_CHANCE: float = 0.18

var _lost_parts: int = 0
var _lost_locomotion: int = 0
var _lost_weapons: int = 0
var _smoke_50_spawned: bool = false
var _smoke_25_spawned: bool = false


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
		enemy.react_to_hit(0.8, 0.03)
	_try_internal_eject(hit_position)
	_check_smoke_thresholds()
	_check_stagger()
	if _hp <= 0.0:
		_kill_enemy()


## Called by any child RobotPart when it detaches. Role tells us what was lost.
func on_part_detached(role: RobotPart.PartRole) -> void:
	_lost_parts += 1
	match role:
		RobotPart.PartRole.LOCOMOTION:
			_lost_locomotion += 1
		RobotPart.PartRole.WEAPON:
			_lost_weapons += 1

	_check_stagger()
	var enemy := get_parent() as Enemy
	if not enemy:
		return
	enemy.stun(0.5)
	match role:
		RobotPart.PartRole.LOCOMOTION:
			enemy.on_locomotion_part_lost(_lost_locomotion)
		RobotPart.PartRole.WEAPON:
			enemy.on_weapon_part_lost(_lost_weapons)


# ---- Private ----------------------------------------------------------------

func _try_internal_eject(hit_position: Vector3) -> void:
	## On a random body hit, forcibly blow a surviving non-armour part loose —
	## selling the idea that the shot damaged something important inside.
	if randf() > EJECT_CHANCE:
		return
	# Collect direct child RobotParts that are still alive and aren't pure armour.
	var candidates: Array = []
	for child in get_children():
		if child is RobotPart \
				and not (child as RobotPart)._detached \
				and (child as RobotPart).part_role != RobotPart.PartRole.ARMOR:
			candidates.append(child)
	if candidates.is_empty():
		return
	var victim := candidates[randi() % candidates.size()] as RobotPart
	# Deliver lethal damage to the chosen part, triggering its full detach path.
	victim.take_damage(victim._hp + 1.0, hit_position)
	# Brief stun — enemy "recoils" from the internal detonation.
	var enemy := get_parent() as Enemy
	if enemy:
		enemy.stun(0.8)


func _check_smoke_thresholds() -> void:
	var ratio := _hp / part_hp
	if not _smoke_50_spawned and ratio <= 0.5:
		_smoke_50_spawned = true
		_spawn_smoke(8)
	if not _smoke_25_spawned and ratio <= 0.25:
		_smoke_25_spawned = true
		_spawn_smoke(18)


func _spawn_smoke(particle_amount: int) -> void:
	var smoke: CPUParticles3D = DAMAGE_SMOKE_SCENE.instantiate()
	# Parent to the enemy root (CharacterBody3D, scale=1) so particle
	# velocities aren't doubled by Body's 2× scale.
	var enemy := get_parent() as Enemy
	var smoke_parent: Node = enemy if enemy else self
	smoke_parent.add_child(smoke)
	smoke.amount = particle_amount
	smoke.global_position = global_position  # place at the body core centre


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
