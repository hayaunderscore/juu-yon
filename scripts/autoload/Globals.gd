extends Node

var song_name: String
var app_title: String = ProjectSettings.get("application/config/name")
var players_entered: Array[bool] = [false, false]
var players_auto: Array[bool] = [false, false]
var player_skins: Array[String] = ["default", "default"]
var default_score_mode: ScoreHandler.ScoreType

var overlay: CanvasLayer = preload("res://scenes/objects/overlay.tscn").instantiate()
var banner_scene: PackedScene = preload("res://scenes/objects/control_banner.tscn")
var control_banner: TaikoControlBanner

signal language_changed(locale: String)

func _ready() -> void:
	# Disable input accumulation, you dunce
	Input.use_accumulated_input = false

	control_banner = banner_scene.instantiate()
	add_child.call_deferred(control_banner)
	add_child.call_deferred(overlay)
	await get_tree().process_frame
	default_score_mode = Configuration.get_section_key_from_string("Game:default_score_mode")

func change_free_play(t: bool):
	overlay.visible = t

func get_song_folder():
	var path: String = Configuration.get_section_key("Game", "song_folder")
	# Replace res:// with executable path
	if path.begins_with("res://") and not OS.has_feature("editor"):
		path = path.replace("res://", OS.get_executable_path().get_base_dir() + "/")
	return path

func change_language(locale: String):
	TranslationServer.set_locale(locale)
	Configuration.set_section_key_from_string("Game:language", locale)
	language_changed.emit(locale)

func sort_notes(a: Dictionary, b: Dictionary):
	if a["time"] == b["time"]:
		# Use index as a tie breaker
		return a.get("index", 0) > b.get("index", 0)
	return a["time"] > b["time"]

func unsort_notes(a: Dictionary, b: Dictionary):
	if a["time"] == b["time"]:
		# Use index as a tie breaker
		return a.get("index", 0) < b.get("index", 0)
	return a["time"] < b["time"]

func _process(_delta: float) -> void:
	var window: Window = get_window()
	var title: String = song_name
	if not title.is_empty():
		title = " - " + title
	title += " - %d FPS" % [Engine.get_frames_per_second()]
	window.title = app_title + title

func log(category: String, msg: String):
	print_rich("[color=green][b]%s[/b][color=white]: %s" % [category, msg])

func merge_sort(cards: Array, fun: Callable) -> Array:
	if cards.size() <= 1:
		return cards
	var mid: int = floori(cards.size() / 2.0)
	var left: Array = merge_sort(cards.slice(0, mid), fun)
	var right: Array = merge_sort(cards.slice(mid, cards.size()), fun)
	return merge(left, right, fun)

func merge(left: Array, right: Array, fun: Callable) -> Array:
	var result: Array = []
	var i: int = 0
	var j: int = 0
	while i < left.size() and j < right.size():
		if fun.call(left[i], right[j]):
			result.append(left[i])
			i += 1
		else:
			result.append(right[j])
			j += 1

	while i < left.size():
		result.append(left[i])
		i += 1

	while j < right.size():
		result.append(right[j])
		j += 1

	return result
