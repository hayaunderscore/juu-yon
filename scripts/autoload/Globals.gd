extends Node

var song_name: String
var app_title: String = ProjectSettings.get("application/config/name")
var players_entered: Array[bool] = [false, false]

var overlay: CanvasLayer = preload("res://scenes/objects/overlay.tscn").instantiate()

func _ready() -> void:
	add_child.call_deferred(overlay)

func _process(_delta: float) -> void:
	var window: Window = get_window()
	var title: String = song_name
	if not title.is_empty():
		title = " - " + title
	title += " - %d FPS" % [Engine.get_frames_per_second()]
	window.title = app_title + title
