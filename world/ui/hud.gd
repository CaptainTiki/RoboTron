extends CanvasLayer

@onready var hp_label: Label      = $Root/InfoBox/HPLabel
@onready var weapon_label: Label  = $Root/InfoBox/WeaponLabel
@onready var ammo_label: Label    = $Root/InfoBox/AmmoLabel
@onready var reload_label: Label  = $Root/InfoBox/ReloadLabel
@onready var crosshair: Label     = $Root/Crosshair
@onready var money_label: Label   = $Root/MoneyLabel
@onready var wave_label: Label    = $Root/WaveLabel
@onready var enemy_label: Label   = $Root/EnemyLabel
@onready var execute_label: Label = $Root/ExecuteLabel

# How long the glory kill flash persists on screen.
const GLORY_FLASH_DURATION := 0.9

var _glory_timer: float = 0.0


func _ready() -> void:
	SignalBus.player_health_changed.connect(_on_health)
	SignalBus.player_ammo_changed.connect(_on_ammo)
	SignalBus.player_weapon_changed.connect(_on_weapon)
	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.wave_enemy_count_changed.connect(_on_enemy_count)
	SignalBus.enemy_staggered.connect(_on_enemy_staggered)
	SignalBus.glory_kill_performed.connect(_on_glory_kill)
	GameState.money_changed.connect(_on_money)
	execute_label.visible = false


func _process(delta: float) -> void:
	if _glory_timer > 0.0:
		_glory_timer -= delta
		if _glory_timer <= 0.0:
			execute_label.visible = false


# ---- Signal handlers --------------------------------------------------------

func _on_health(current: int, maximum: int) -> void:
	hp_label.text     = "HP: %d / %d" % [current, maximum]
	var t: float       = float(current) / float(maximum)
	hp_label.modulate = Color(1.0, t, t)


func _on_ammo(current: int, maximum: int) -> void:
	ammo_label.text        = "Ammo: %d / %d" % [current, maximum]
	reload_label.visible   = (current == 0)


func _on_weapon(weapon_name: String) -> void:
	weapon_label.text = "Weapon: " + weapon_name


func _on_wave_started(wave_num: int, total: int) -> void:
	wave_label.text  = "WAVE %d" % wave_num
	enemy_label.text = "Enemies: %d" % total


func _on_enemy_count(remaining: int) -> void:
	enemy_label.text = "Enemies: %d" % remaining


func _on_money(new_amount: int) -> void:
	money_label.text = "$%d" % new_amount


func _on_enemy_staggered(_enemy: Node3D) -> void:
	execute_label.text     = "[E]  EXECUTE"
	execute_label.modulate = Color(1.0, 0.2, 0.1)
	execute_label.visible  = true
	_glory_timer           = 4.0  # hide if player doesn't act


func _on_glory_kill() -> void:
	execute_label.text     = "GLORY KILL  +$$$  +HP"
	execute_label.modulate = Color(1.0, 0.8, 0.1)
	execute_label.visible  = true
	_glory_timer           = GLORY_FLASH_DURATION
