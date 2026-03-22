extends Node

# Static VFX pool autoload.
# Usage: Pool.spark_burst, Pool.ground_sparks, Pool.death_explosion, Pool.impact_spark
# Each is an ObjectPool — acquire() and play() are handled internally via signals.

var spark_burst:      ObjectPool
var ground_sparks:    ObjectPool
var death_explosion:  ObjectPool
var impact_spark:     ObjectPool

const _SPARK_BURST_SCENE     = preload("res://world/vfx/spark_burst.tscn")
const _GROUND_SPARKS_SCENE   = preload("res://world/vfx/ground_sparks.tscn")
const _DEATH_EXPLOSION_SCENE = preload("res://world/vfx/death_explosion.tscn")
const _IMPACT_SPARK_SCENE    = preload("res://world/vfx/impact_spark.tscn")


func _ready() -> void:
	spark_burst     = ObjectPool.new(_SPARK_BURST_SCENE)
	ground_sparks   = ObjectPool.new(_GROUND_SPARKS_SCENE)
	death_explosion = ObjectPool.new(_DEATH_EXPLOSION_SCENE)
	impact_spark    = ObjectPool.new(_IMPACT_SPARK_SCENE)

	SignalBus.bullet_impact.connect(_on_bullet_impact)
	SignalBus.piece_detached.connect(_on_piece_detached)
	SignalBus.piece_grounded.connect(_on_piece_grounded)
	SignalBus.enemy_died_at.connect(_on_enemy_died)


# ---- Signal handlers --------------------------------------------------------

func _on_bullet_impact(pos: Vector3) -> void:
	_play_at(impact_spark, pos)

func _on_piece_detached(pos: Vector3) -> void:
	_play_at(spark_burst, pos)

func _on_piece_grounded(pos: Vector3) -> void:
	_play_at(ground_sparks, pos)

func _on_enemy_died(pos: Vector3) -> void:
	_play_at(death_explosion, pos)


# ---- Helpers ----------------------------------------------------------------

func _play_at(pool: ObjectPool, pos: Vector3) -> void:
	# Parent VFX to Pool itself (always alive, always in the tree).
	# Avoids current_scene look-up and keeps pooled nodes persistent.
	var vfx := pool.acquire(self) as Node3D
	if not vfx:
		return
	vfx.global_position = pos
	vfx.call("play")
