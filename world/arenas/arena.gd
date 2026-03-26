extends Node3D

signal wave_complete()
signal player_died()

var player_node: CharacterBody3D
var wave_manager_node: Node

func _ready() -> void:
	_create_player()
	_create_wave_manager()

# ── Player ────────────────────────────────────────────────────────────────────

const PLAYER_SCENE = preload("res://world/player/player.tscn")

func _create_player() -> void:
	var player := PLAYER_SCENE.instantiate()
	# Spawn at the "safe" end (positive X). Danger end is negative X.
	player.position = Vector3(18.0, 1.0, 0.0)
	add_child(player)
	player_node = player
	SignalBus.player_died.connect(_on_player_died)

# ── Wave manager ──────────────────────────────────────────────────────────────

func _create_wave_manager() -> void:
	var wm := Node.new()
	wm.name = "WaveManager"
	wm.set_script(load("res://system/wave_manager.gd"))
	add_child(wm)
	wave_manager_node = wm
	wm.wave_complete.connect(func(): wave_complete.emit())
	wm.start_wave(player_node)

func _on_player_died() -> void:
	player_died.emit()
