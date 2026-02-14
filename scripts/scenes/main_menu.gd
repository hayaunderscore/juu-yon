extends Control

@onready var items: HBoxContainer = %MenuItems
var prev_y: Array[float]
var highlights: Array[Panel]
var item_text: Array[VerticalText2D]
var item_text_colors: Array[Color]
var selected: int = 0
var transition: bool = true
var selection_time: float = 0.0
var transition_time: float = 0.0
var select_transition: float = 0.0
var do_select_transition: bool = false

var descriptions: PackedStringArray = [
	"Select the song and start a game!",
	"Change game options for optimal play!",
	"Quits Taiko San Juu-Yon.\nSee ya later!"
]
@onready var description_container = $VBoxContainer
@onready var description_panel = %Description
@onready var description_label = %DescriptionLabel
var description_tween: Tween

func _ready() -> void:
	%TaikoCharaP1.bpm = 118
	
	Globals.control_banner.deactivate()
	Globals.control_banner.don_pressed.connect(_on_control_banner_don_pressed)
	Globals.control_banner.kat_pressed.connect(kat_pressed)
	for item in items.get_children():
		if item is PanelContainer:
			prev_y.push_back(item.global_position.y)
			highlights.push_back(item.get_node("Highlight"))
			item_text.push_back((item.get_node("Text") as TextureRect).texture)
			item_text_colors.push_back(item_text.back().outline_color)
			item.global_position.y = 720
	%P1AnimPlayer.play("Enter")
	await get_tree().process_frame
	for item in items.get_children():
		if item is PanelContainer:
			item.visible = true
	await get_tree().create_timer(0.75).timeout
	description_tween = create_tween()
	description_tween.tween_property(description_container, "scale:y", 1.0, 0.1)
	transition = false
	Globals.control_banner.activate()
	Globals.control_banner.activate_side()

func _exit_tree() -> void:
	Globals.control_banner.don_pressed.disconnect(_on_control_banner_don_pressed)
	Globals.control_banner.kat_pressed.disconnect(kat_pressed)

func ease_out_back(x: float):
	const c1 := 1.70158
	const c3 := c1 + 1
	
	return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	var elapsed: float = $Music.get_playback_position() + AudioServer.get_time_since_last_mix()
	%TaikoCharaP1.beat = elapsed * (%TaikoCharaP1.bpm / 60)
	
	description_container.pivot_offset = description_container.size / 2.0
	
	for i in range(items.get_child_count()):
		var item: PanelContainer = items.get_child(i) as PanelContainer
		var target_y: float = prev_y[i]
		if i == selected and not transition:
			target_y -= 48
			item_text[i].outline_color = Color.BLACK
			var t: float = (sin((selection_time * 4 - deg_to_rad(90.0))) + 1.0) / 8.0
			highlights[i].modulate.a = t
		else:
			item_text[i].outline_color = item_text_colors[i]
			highlights[i].modulate.a = 0
		if do_select_transition and i != selected:
			item.global_position.y = lerpf(720, prev_y[i], ease_out_back(minf(1.0, 1.0 - minf(1.0, (select_transition * 2) - (i * 0.25)))))
		else:
			if i == selected:
				item.global_position.y = lerpf(prev_y[i], target_y, ease_out_back(minf(1.0, selection_time * 3)))
			else:
				item.global_position.y = lerpf(item.global_position.y, target_y, delta * 16)
			if transition:
				item.global_position.y = lerpf(720, prev_y[i], ease_out_back(minf(1.0, (transition_time * 2) - (i * 0.25))))

	if transition:
		transition_time += delta
	else:
		selection_time += delta
	
	if do_select_transition:
		select_transition += delta

func _on_control_banner_don_pressed(id: Variant) -> void:
	if not Globals.players_entered[id]: return
	Globals.control_banner.deactivate()
	Globals.control_banner.deactivate_side()
	do_select_transition = true
	var tween: Tween = create_tween()
	var item: PanelContainer = items.get_child(selected) as PanelContainer
	tween.set_parallel(true)
	tween.tween_property(description_container, "scale:y", 0.0, 0.1)
	tween.tween_property(item, "global_position:x", get_viewport_rect().size.x / 2.0 - 51, 0.3)
	tween.set_parallel(false)
	tween.tween_callback(choose_callback).set_delay(1.7)
	%TaikoCharaP1.do_combo_animation(false)

func choose_callback():
	var tween: Tween = create_tween()
	tween.tween_property($Music, "volume_linear", 0.0, 0.5)
	match selected:
		0:
			TransitionHandler.change_scene_to_file("uid://b8jopawilsvnu", true, Color.CRIMSON, true)
		1: pass
		2: get_tree().quit()

func kat_pressed(_id, side):
	selected = wrapi(selected + side, 0, items.get_child_count())
	selection_time = 0
	if description_tween: description_tween.kill()
	description_tween = create_tween()
	description_tween.tween_property(description_container, "scale:y", 0.0, 0.1)
	description_tween.tween_callback(func():
		description_label.text = descriptions[selected]
		var panel: StyleBoxFlat = description_panel.get_theme_stylebox("panel")
		var item: PanelContainer = items.get_child(selected) as PanelContainer
		panel.bg_color = (item.get_theme_stylebox("panel") as StyleBoxTexture).modulate_color
	)
	description_tween.tween_property(description_container, "scale:y", 1.0, 0.1)
