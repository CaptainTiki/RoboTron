extends Node

var money: int = 0
var current_wave: int = 0
var player_max_hp: int = 100
var owned_weapons: Array = ["pistol"]
var equipped_weapons: Array = ["pistol", "", ""]

signal money_changed(new_amount: int)

const WEAPON_DATA: Dictionary = {
	"pistol": {
		"name": "Pistol",
		"damage": 35.0,
		"fire_rate": 0.5,
		"mag_size": 12,
		"reload_time": 1.2,
		"spread": 0.0,
		"pellets": 1,
		"cost": 0,
		"auto": false,
		"color": Color(0.55, 0.55, 0.65),
	},
	"smg": {
		"name": "SMG",
		"damage": 15.0,
		"fire_rate": 0.09,
		"mag_size": 30,
		"reload_time": 1.5,
		"spread": 0.05,
		"pellets": 1,
		"cost": 500,
		"auto": true,
		"color": Color(0.3, 0.7, 0.3),
	},
	"shotgun": {
		"name": "Shotgun",
		"damage": 18.0,
		"fire_rate": 0.8,
		"mag_size": 8,
		"reload_time": 2.0,
		"spread": 0.15,
		"pellets": 8,
		"cost": 750,
		"auto": false,
		"color": Color(0.7, 0.4, 0.2),
	},
}


func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)

func spend_money(amount: int) -> bool:
	if money >= amount:
		money -= amount
		money_changed.emit(money)
		return true
	return false

func buy_weapon(weapon_id: String) -> bool:
	if weapon_id in owned_weapons:
		return false
	var cost: int = WEAPON_DATA[weapon_id]["cost"]
	if spend_money(cost):
		owned_weapons.append(weapon_id)
		return true
	return false

func equip_weapon(weapon_id: String, slot: int) -> void:
	if slot < 0 or slot > 2:
		return
	if weapon_id == "" or weapon_id in owned_weapons:
		equipped_weapons[slot] = weapon_id

func get_wave_composition() -> Array:
	var wave: int = current_wave
	var scale: float = 1.0 + (wave - 1) * 0.4
	return [
		{"type": "grunt",   "count": int(5 * scale)},
		{"type": "shooter", "count": int(3 * scale)},
		{"type": "rusher",  "count": int(2 * scale)},
		{"type": "heavy",   "count": max(0, wave - 1)},
	]

func reset_for_new_game() -> void:
	money = 0
	current_wave = 0
	player_max_hp = 100
	owned_weapons = ["pistol"]
	equipped_weapons = ["pistol", "", ""]
