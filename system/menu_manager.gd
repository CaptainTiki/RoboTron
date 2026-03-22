extends Control
class_name MenuManager

static var instance

var menus : Dictionary[Menu.Type, Menu] = {}

func _ready() -> void:
	MenuManager.instance = self
