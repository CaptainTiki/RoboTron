extends CharacterBody3D
class_name Enemy

@export var hp: float = 50.0
@export var move_speed: float = 3.5
@export var money_value: int = 25
@export var attack_damage: float = 15.0
@export var attack_range: float = 1.6
@export var attack_rate: float = 1.0

var max_hp: float
var player_node: CharacterBody3D = null
var attack_timer: float = 0.0
var is_dead: bool = false

signal died(money_earned: int)

const GRAVITY: float = 9.8

func _ready() -> void:
	collision_layer = 4
	collision_mask = 7  # world(1) + player(2) + enemies(4)
	max_hp = hp

func _physics_process(delta: float) -> void:
	if is_dead or not player_node:
		return
	_behavior(delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()

# Override in subclasses
func _behavior(delta: float) -> void:
	_seek_and_melee(delta)

func _seek_and_melee(delta: float) -> void:
	var to_player: Vector3 = player_node.global_position - global_position
	var dist: float = to_player.length()

	if dist < attack_range:
		velocity.x = 0.0
		velocity.z = 0.0
		_try_attack(delta)
	else:
		var dir: Vector3 = to_player.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		_face_player()

func _face_player() -> void:
	if not player_node:
		return
	var look_target := Vector3(player_node.global_position.x, global_position.y, player_node.global_position.z)
	if look_target.distance_to(global_position) > 0.05:
		look_at(look_target, Vector3.UP)

func _try_attack(delta: float) -> void:
	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = attack_rate
		_do_attack()

func _do_attack() -> void:
	if player_node and player_node.has_method("take_damage"):
		player_node.take_damage(attack_damage)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	if hp <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	died.emit(money_value)
	queue_free()
