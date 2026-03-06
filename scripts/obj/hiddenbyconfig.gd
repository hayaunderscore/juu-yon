extends Node
class_name HiddenByConfig

@export var target_value: Variant

@export_group("Config", "config_")
@export var config_name: String = ""
@export var config_section: String = ""

var parent: Node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	parent = get_parent()
	if not parent: return
	parent.visible = Configuration.get_section_key(config_section, config_name) == target_value
