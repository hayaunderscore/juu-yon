extends Control

enum State {
	NONE,
	SELECTING,
	SUBMENU_TRANS_IN,
	SUBMENU_SELECTING,
	SUBMENU_TRANS_OUT,
	SUBMENU_SELECTED_OPTION,
}
var state: State = State.NONE:
	set(v):
		if state == v: return
		state = v
		transition_time = 0.0
var transition_time: float = 0.0
var selection_time: float = 0.0
var current_submenu: int = 0
var current_option: int = 0

var prev_x: Array[float]
var prev_y: Array[float]
var highlights: Array[Panel]
var item_text: Array[VerticalText2D]
var item_text_colors: Array[Color]

@onready var items: HBoxContainer = $MarginContainer/HBoxContainer

var item_options: Array[Array] = [
	[], # Back, this doesnt have any options to speak of
	[
		{ "name": "o_opt_freeplay", "config_option": "Game:free_play", "type": "bool" },
		{ "name": "o_opt_score_delay", "config_option": "Game:score_delay", "type": "bool" },
		{ "name": "o_opt_language", "config_option": "Game:language", "type": "lang" },
	],
	[], # Controls are handled differently as well
	[], # Audio should *maybe* be handled differently?
]

var font: Font = preload("uid://cmmdexdosfbag")
@onready var options_container: HBoxContainer = %OptionsContainer
@onready var full_options_cont: MarginContainer = %FullOptionsContainer

func create_vertical_text(fsize: int = 32) -> TextureRect:
	var trect: TextureRect = TextureRect.new()
	var tex: VerticalText2D = VerticalText2D.new()
	tex.font = font
	tex.font_size = fsize
	tex.outline_size = floori(fsize / 1.7)
	tex.outline_color = Color("#683A17")
	trect.texture = tex
	return trect

var lang_dict: Dictionary[String, String] = {
	"en": "ENG",
	"ja": "日本国"
}

func determine_suboptions(option: Dictionary, control: Control, idx: int):
	var type: String = option.get("type", "bool")
	match type:
		"bool":
			# On and off labels
			var on: TextureRect = create_vertical_text(21)
			var tex: VerticalText2D = on.texture
			tex.text = "o_opt_on"
			on.set_anchors_preset(Control.PRESET_TOP_LEFT)
			control.add_child(on)
			var off: TextureRect = create_vertical_text(21)
			tex = off.texture
			tex.text = "o_opt_off"
			off.set_anchors_preset(Control.PRESET_TOP_LEFT)
			control.add_child(off)
			# Move these guys
			await get_tree().process_frame
			on.global_position.x -= tex.get_width() * 2
			off.global_position.y += on.texture.get_height() * 1.5
			off.global_position.x -= tex.get_width() * 2
			update_bool_toggle(idx, Configuration.get_section_key_from_string(option["config_option"]))
		"lang":
			# Only two languages at the moment!
			for lang in lang_dict.values():
				var l: TextureRect = create_vertical_text(21)
				l.name = lang
				var tex: VerticalText2D = l.texture
				tex.text = lang
				l.set_anchors_preset(Control.PRESET_TOP_LEFT)
				control.add_child(l)
			await get_tree().process_frame
			# Adjust heights...
			var prev: TextureRect = null
			for child in control.get_children():
				if child is not TextureRect: continue
				child.global_position.x -= child.texture.get_width() * 2
				if prev:
					child.global_position.y += prev.texture.get_height() * 1.5
				prev = child
			update_lang_toggle(control, TranslationServer.get_locale())

func update_bool_toggle(selected: int, truthy: bool = false):
	var on: TextureRect = options_container.get_child(selected).get_child(0)
	var off: TextureRect = options_container.get_child(selected).get_child(1)
	if truthy:
		on.texture.outline_color = Color.BLACK
		off.texture.outline_color = Color("#683A17")
	else:
		off.texture.outline_color = Color.BLACK
		on.texture.outline_color = Color("#683A17")

func update_lang_toggle(control: Control, locale: String):
	var rname: String = lang_dict.get(locale, "ENG")
	for child in control.get_children():
		if child is not TextureRect: continue
		child.texture.outline_color = Color.BLACK if child.name == rname else Color("#683A17")
	Globals.change_language(locale)

var opt_tween: Tween
func create_options(selected: int):
	var opt: Array = item_options[selected]
	for option in options_container.get_children():
		option.queue_free()
	var cnt: int = 0
	for option in opt:
		var trect: TextureRect = TextureRect.new()
		var tex: VerticalText2D = VerticalText2D.new()
		tex.font = font
		tex.font_size = 32
		tex.outline_size = 18
		tex.text = option["name"]
		tex.minimum_size.x = 36
		tex.outline_color = Color("#683A17")
		trect.size_flags_vertical = Control.SIZE_FILL
		trect.texture = tex
		options_container.add_child(trect)
		determine_suboptions(option, trect, cnt)
		cnt += 1
	opt_tween = create_tween()
	opt_tween.tween_property(full_options_cont, "modulate:a", 1.0, 0.2)

func remove_options():
	opt_tween = create_tween()
	opt_tween.tween_property(full_options_cont, "modulate:a", 0.0, 0.2)

func ease_out_back(x: float):
	const c1 := 1.70158
	const c3 := c1 + 1
	
	return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Globals.control_banner.deactivate()
	Globals.control_banner.don_pressed.connect(_don_pressed)
	Globals.control_banner.kat_pressed.connect(_kat_pressed)
	
	await get_tree().process_frame
	
	for item in items.get_children():
		if item is CenterContainer:
			prev_x.push_back(item.global_position.x)
			prev_y.push_back(item.global_position.y)
			var real_item: MarginContainer = item.get_node("PanelContainer/MarginContainer")
			highlights.push_back(real_item.get_node("Highlight"))
			item_text.push_back((real_item.get_node("TextContainer/Text") as TextureRect).texture)
			item_text_colors.push_back(item_text.back().outline_color)
			item.global_position.y = 720
	
	await get_tree().create_timer(0.75).timeout
	
	state = State.SELECTING
	
	Globals.control_banner.activate()
	Globals.control_banner.activate_side()

func _exit_tree() -> void:
	Globals.control_banner.don_pressed.disconnect(_don_pressed)
	Globals.control_banner.kat_pressed.disconnect(_kat_pressed)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if state != State.NONE:
		selection_time += delta
	transition_time += delta
	
	if prev_y.size() == 0: return
	
	if state == State.SUBMENU_SELECTING:
		for i in range(item_options[current_submenu].size() + 1):
			var trect: TextureRect = %BackContainer.get_child(0)
			if i < item_options[current_submenu].size():
				trect = options_container.get_child(i)
			var tex: VerticalText2D = trect.texture as VerticalText2D
			if i == current_option:
				tex.outline_color = Color.BLACK
			else:
				tex.outline_color = Color("#683A17")
	
	for i in range(items.get_child_count()):
		var item: CenterContainer = items.get_child(i) as CenterContainer
		var target_y: float = prev_y[i]
		if i == current_submenu and state != State.NONE:
			target_y -= 48
			item_text[i].outline_color = Color.BLACK
			highlights[i].modulate.a = 1.0
		else:
			item_text[i].outline_color = item_text_colors[i]
			highlights[i].modulate.a = 0
		if i == current_submenu:
			item.global_position.y = lerpf(prev_y[i], target_y, ease_out_back(minf(1.0, selection_time * 3)))
			if state > State.SELECTING:
				item.global_position.y = target_y
		else:
			item.global_position.y = lerpf(item.global_position.y, target_y, delta * 16)
		if state == State.NONE:
			item.global_position.y = lerpf(720, prev_y[i], ease_out_back(minf(1.0, (transition_time * 2.5) - (i * 0.25))))
		if state == State.SUBMENU_TRANS_IN and i != current_submenu:
			var target: float = -800 if i < current_submenu else 800
			item.global_position.x = lerpf(prev_x[i], prev_x[i] + target, minf(1.0, transition_time * 2))
		if state == State.SUBMENU_TRANS_IN and i == current_submenu and transition_time > 0.5:
			item.global_position.x = lerpf(prev_x[i], 836, minf(1.0, (transition_time - 0.5) * 2))
		if state == State.SUBMENU_TRANS_OUT and i != current_submenu:
			var target: float = -800 if i < current_submenu else 800
			item.global_position.x = lerpf(prev_x[i] + target, prev_x[i], maxf(0.0, minf(1.0, (transition_time - 0.5) * 2)))
		if state == State.SUBMENU_TRANS_OUT and i == current_submenu:
			item.global_position.x = lerpf(836, prev_x[i], minf(1.0, transition_time * 2))
		if state == State.SUBMENU_SELECTING or state == State.SUBMENU_SELECTED_OPTION:
			if i == current_submenu:
				item.global_position.x = 836
			if i != current_submenu:
				var target: float = -800 if i < current_submenu else 800
				item.global_position.x = prev_x[i] + target
	if state == State.SUBMENU_TRANS_IN:
		%OptionBoxControl.global_position.x = lerpf(-960, 0, maxf(0.0, minf(1.0, (transition_time - 0.5) * 2)))
	if state == State.SUBMENU_TRANS_OUT:
		%OptionBoxControl.global_position.x = lerpf(0, -960, maxf(0.0, minf(1.0, transition_time * 2)))

func handle_pressed_main():
	if current_submenu == 0:
		SoundHandler.play_sound("cancel.wav")
		TransitionHandler.change_scene_to_file("uid://dyvmwrm570eh6", true, Color("#6ABCC5"), true)
		return
	state = State.SUBMENU_TRANS_IN
	await get_tree().create_timer(1.0).timeout
	state = State.SUBMENU_SELECTING
	create_options(current_submenu)
	Globals.control_banner.activate()
	Globals.control_banner.activate_side()

func next_from_key(dict: Dictionary, key: Variant) -> Array:
	var keys: Array = dict.keys()
	var index: int = keys.find(key)
	if index != -1:
		var next: Variant = keys[wrapi(index + 1, 0, keys.size())]
		return [next, dict[next]]
	return []

func handle_pressed_submenu():
	# Back option
	if current_option == item_options[current_submenu].size():
		Configuration.save_options()
		Globals.control_banner.deactivate()
		Globals.control_banner.deactivate_side()
		SoundHandler.play_sound("cancel.wav")
		remove_options()
		state = State.SUBMENU_TRANS_OUT
		await get_tree().create_timer(1.0).timeout
		state = State.SELECTING
		Globals.control_banner.activate()
		Globals.control_banner.activate_side()
		return
	var option: Dictionary = item_options[current_submenu][current_option]
	var type: String = option.get("type", "bool")
	match type:
		"bool":
			Configuration.set_section_key_from_string(option["config_option"], not Configuration.get_section_key_from_string(option["config_option"]))
			update_bool_toggle(current_option, Configuration.get_section_key_from_string(option["config_option"]))
		"lang":
			var lang: String = Configuration.get_section_key_from_string(option["config_option"])
			var next: Array = next_from_key(lang_dict, lang)
			update_lang_toggle(options_container.get_child(current_option), next[0])

func _don_pressed(id: Variant) -> void:
	if not Globals.players_entered[id]: return
	if current_submenu == 0:
		Globals.control_banner.deactivate()
		Globals.control_banner.deactivate_side()
		SoundHandler.play_sound("cancel.wav")
		TransitionHandler.change_scene_to_file("uid://dyvmwrm570eh6", true, Color("#6ABCC5"), true)
		return
	if state == State.SELECTING:
		current_option = wrapi(item_options[current_submenu].size() - 1, 0, item_options[current_submenu].size())
		Globals.control_banner.deactivate()
		Globals.control_banner.deactivate_side()
		handle_pressed_main()
	elif state == State.SUBMENU_SELECTING:
		handle_pressed_submenu()

func _kat_pressed(_id: Variant, side: Variant) -> void:
	selection_time = 0.0
	if state == State.SELECTING:
		current_submenu = wrapi(current_submenu + side, 0, items.get_child_count())
	elif state == State.SUBMENU_SELECTING:
		current_option = wrapi(current_option + side, 0, item_options[current_submenu].size() + 1)
