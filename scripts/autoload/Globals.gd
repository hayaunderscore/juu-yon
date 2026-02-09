extends Node

var song_name: String
var app_title: String = ProjectSettings.get("application/config/name")
var players_entered: Array[bool] = [false, false]

var overlay: CanvasLayer = preload("res://scenes/objects/overlay.tscn").instantiate()
var banner_scene: PackedScene = preload("res://scenes/objects/control_banner.tscn")
var control_banner: TaikoControlBanner

func _ready() -> void:
	control_banner = banner_scene.instantiate()
	add_child.call_deferred(control_banner)
	add_child.call_deferred(overlay)

func _process(_delta: float) -> void:
	var window: Window = get_window()
	var title: String = song_name
	if not title.is_empty():
		title = " - " + title
	title += " - %d FPS" % [Engine.get_frames_per_second()]
	window.title = app_title + title

func log(category: String, msg: String):
	print_rich("[color=green][b]%s[/b][color=white]: %s" % [category, msg])
