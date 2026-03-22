extends Control
class_name Menu

enum Type {TITLE, MAIN, SETTINGS, EXITCONFIRM, PAUSE, LOADOUT}

func show_menu() -> void:
	show()
	set_process(true)

func hide_menu() -> void:
	hide()
	set_process(false)
