extends CanvasLayer

signal deploy_pressed()

var money_label: Label
var slot_buttons: Array = []  # 3 VBoxContainers holding slot info
var slot_weapon_labels: Array = []
var message_label: Label
var health_btn: Button

func _ready() -> void:
	_build_ui()
	_refresh()
	GameState.money_changed.connect(func(_v): _refresh())

func _build_ui() -> void:
	# Dark overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.05, 0.05, 0.1, 0.92)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Centered panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(640, 600)
	panel.offset_left   = -320.0
	panel.offset_top    = -300.0
	panel.offset_right  =  320.0
	panel.offset_bottom =  300.0
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# Title
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 26)
	if GameState.current_wave == 0:
		message_label.text = "ROBO-TRON"
	else:
		message_label.text = "WAVE %d COMPLETE" % GameState.current_wave
	vbox.add_child(message_label)

	# Money
	money_label = Label.new()
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", 20)
	money_label.modulate = Color(1.0, 0.9, 0.2)
	vbox.add_child(money_label)

	vbox.add_child(HSeparator.new())

	# Shop label
	var shop_lbl := Label.new()
	shop_lbl.text = "— SHOP —"
	shop_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(shop_lbl)

	var shop_hbox := HBoxContainer.new()
	shop_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	shop_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(shop_hbox)

	for wid in ["smg", "shotgun"]:
		var data: Dictionary = GameState.WEAPON_DATA[wid]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 44)
		btn.text = "Buy %s\n$%d" % [data["name"], data["cost"]]
		btn.pressed.connect(func(): _buy_weapon(wid, btn))
		shop_hbox.add_child(btn)

	health_btn = Button.new()
	health_btn.custom_minimum_size = Vector2(180, 44)
	health_btn.text = "Buy +25 HP  ($200)"
	health_btn.pressed.connect(_buy_health)
	shop_hbox.add_child(health_btn)

	vbox.add_child(HSeparator.new())

	# Loadout slots
	var loadout_lbl := Label.new()
	loadout_lbl.text = "— LOADOUT (click slot to cycle weapon) —"
	loadout_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loadout_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(loadout_lbl)

	var slots_hbox := HBoxContainer.new()
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(slots_hbox)

	for i in range(3):
		var sv := VBoxContainer.new()
		sv.custom_minimum_size = Vector2(120, 80)
		slots_hbox.add_child(sv)

		var slot_lbl := Label.new()
		slot_lbl.text = "Slot %d" % (i + 1)
		slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sv.add_child(slot_lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(120, 44)
		var idx: int = i
		btn.pressed.connect(func(): _cycle_slot(idx))
		sv.add_child(btn)
		slot_buttons.append(btn)
		slot_weapon_labels.append(btn)  # btn.text acts as the label

	vbox.add_child(HSeparator.new())

	# Deploy button
	var deploy_btn := Button.new()
	deploy_btn.text = "▶  DEPLOY  ▶"
	deploy_btn.custom_minimum_size = Vector2(240, 54)
	deploy_btn.add_theme_font_size_override("font_size", 20)
	deploy_btn.pressed.connect(func(): deploy_pressed.emit())
	var deploy_center := HBoxContainer.new()
	deploy_center.alignment = BoxContainer.ALIGNMENT_CENTER
	deploy_center.add_child(deploy_btn)
	vbox.add_child(deploy_center)

func _refresh() -> void:
	money_label.text = "Credits:  $%d" % GameState.money

	# Update shop button states
	var panel: PanelContainer = get_child(0).get_child(0)
	var vbox: VBoxContainer = panel.get_child(0)
	var shop_hbox: HBoxContainer = vbox.get_child(4)  # index may shift; scan instead
	for child in shop_hbox.get_children():
		if child is Button:
			var lbl: String = child.text
			for wid in ["smg", "shotgun"]:
				if GameState.WEAPON_DATA[wid]["name"] in lbl:
					child.disabled = (wid in GameState.owned_weapons) \
						or GameState.money < GameState.WEAPON_DATA[wid]["cost"]

	# Update slot buttons
	for i in range(3):
		var wid: String = GameState.equipped_weapons[i]
		if wid == "":
			slot_buttons[i].text = "(empty)"
		else:
			slot_buttons[i].text = GameState.WEAPON_DATA[wid]["name"]

	# Health btn
	health_btn.disabled = (GameState.player_max_hp >= 200 or GameState.money < 200)

func _buy_weapon(weapon_id: String, btn: Button) -> void:
	if GameState.buy_weapon(weapon_id):
		btn.disabled = true
		_refresh()

func _buy_health() -> void:
	if GameState.spend_money(200):
		GameState.player_max_hp = min(GameState.player_max_hp + 25, 200)
		_refresh()

func _cycle_slot(slot: int) -> void:
	var options: Array = [""] + GameState.owned_weapons
	var current: String = GameState.equipped_weapons[slot]
	var idx: int = options.find(current)
	idx = (idx + 1) % options.size()
	GameState.equip_weapon(options[idx], slot)
	_refresh()
