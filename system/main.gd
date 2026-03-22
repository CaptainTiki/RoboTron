extends Node

const HUD_SCENE   = preload("res://world/ui/hud.tscn")
const ARENA_SCENE = preload("res://world/arenas/arena.tscn")

var arena: Node = null
var hud: CanvasLayer = null
var loadout_ui: CanvasLayer = null
var _in_wave: bool = false

func _ready() -> void:
	hud = HUD_SCENE.instantiate()
	hud.visible = false
	add_child(hud)
	_show_loadout()

func _show_loadout() -> void:
	_in_wave = false

	if arena:
		arena.queue_free()
		arena = null

	hud.visible = false

	# Always clean up any existing loadout UI before creating a new one
	if is_instance_valid(loadout_ui):
		loadout_ui.free()
	loadout_ui = null

	var ui = load("res://menusystem/loadoutmenu.gd").new()
	ui.name = "LoadoutUI"
	add_child(ui)
	ui.deploy_pressed.connect(_on_deploy_pressed)
	loadout_ui = ui

func _on_deploy_pressed() -> void:
	if _in_wave:
		return
	_in_wave = true

	# Immediately free the UI so its ColorRect doesn't eat the first shot
	if is_instance_valid(loadout_ui):
		loadout_ui.call_deferred("free")
	loadout_ui = null

	GameState.current_wave += 1
	_start_wave()

func _start_wave() -> void:
	var a := ARENA_SCENE.instantiate()
	add_child(a)
	a.wave_complete.connect(_on_wave_complete)
	a.player_died.connect(_on_player_died)
	arena = a
	hud.visible = true

func _on_wave_complete() -> void:
	if not _in_wave:
		return
	_show_loadout()

func _on_player_died() -> void:
	if not _in_wave:
		return
	_in_wave = false
	hud.visible = false
	await get_tree().create_timer(1.5).timeout
	_show_loadout()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
