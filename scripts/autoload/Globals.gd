extends Node

var song_name: String:
	set(value):
		if value == song_name: return
		song_name = value
		_update_song_window_title()
var song_difficulty: String:
	set(value):
		if value == song_difficulty: return
		song_difficulty = value
		_update_song_window_title()
var song_stars: int:
	set(value):
		if value == song_stars: return
		song_stars = value
		_update_song_window_title()
var max_stars: int:
	set(value):
		if value == max_stars: return
		max_stars = value
		_update_song_window_title()
var app_title: String = ProjectSettings.get("application/config/name")
var players_entered: Array[bool] = [false, false]
var players_auto: Array[bool] = [false, false]
var player_skins: Array[String] = ["default", "default"]
var player_puchi: Array[String] = ["", ""]
var default_score_mode: ScoreHandler.ScoreType

var overlay: CanvasLayer = preload("res://scenes/objects/overlay.tscn").instantiate()
var banner_scene: PackedScene = preload("res://scenes/objects/control_banner.tscn")
var control_banner: TaikoControlBanner

signal language_changed(locale: String)

var _song_window_title: String = ""
var _updating: bool = false
func _update_song_window_title():
	if not _updating:
		_update_song_window_title_deferred.call_deferred()
		_updating = true

func _update_song_window_title_deferred():
	var title: String = song_name
	if not song_difficulty.is_empty():
		title += " (%s " % [song_difficulty]
		var star_count: int = maxi(song_stars, max_stars)
		for i in range(star_count):
			if i >= song_stars:
				title += "☆"
			else:
				title += "★"
		title += ")"
	if not title.is_empty():
		title = " - " + title
	_song_window_title = title
	_updating = false

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

const MISC_KEYS: PackedStringArray = ["pause"]

func apply_controls():
	# Miscellaneous keys first
	for action in []:
		InputMap.action_erase_events(action)
		# Key event
		var key_event: InputEventKey = InputEventKey.new()
		key_event.keycode = OS.find_keycode_from_string(Configuration.get_section_key("ControlsKeyboard", action))
		InputMap.action_add_event(action, key_event)
	# Don and Kat
	for player in range(2):
		var idx: String = "p%d" % [player + 1]
		for type in ["don", "kat"]:
			var sides: PackedStringArray = ["left", "right"]
			for i in range(sides.size()):
				var side: String = sides[i]
				var action: String = "%s_%s_%s" % [type, side, idx]
				var key: String = "%s_%s" % [idx, type]
				var key_array: Array = Configuration.get_section_key("ControlsKeyboard", key)
				# Make sure the key array has exactly 2 elements
				if key_array.size() != 2:
					Globals.log("CONTROLS", "Error! Too many or too little keys provided in array! (%d)" % key_array.size())
					return
				InputMap.action_erase_events(action)
				# Key event
				var key_event: InputEventKey = InputEventKey.new()
				key_event.keycode = OS.find_keycode_from_string(Configuration.get_section_key("ControlsKeyboard", key)[i])
				InputMap.action_add_event(action, key_event)

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
	var title: String = " - %d FPS" % [Engine.get_frames_per_second()]
	window.title = app_title + _song_window_title + title

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
