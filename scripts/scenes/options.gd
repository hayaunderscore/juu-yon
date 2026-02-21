extends Control

enum State {
	NONE,
	SELECTING,
	SUBMENU_TRANS_IN,
	SUBMENU_SELECTING,
	SUBMENU_TRANS_OUT,
}
var state: State = State.NONE:
	set(v):
		if state == v: return
		state = v
		transition_time = 0.0
var transition_time: float = 0.0
var selection_time: float = 0.0
var current_submenu: int = 0

var prev_y: Array[float]
var highlights: Array[Panel]
var item_text: Array[VerticalText2D]
var item_text_colors: Array[Color]

@onready var items: HBoxContainer = $MarginContainer/HBoxContainer

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
	if state == State.SELECTING:
		selection_time += delta
	transition_time += delta
	
	if prev_y.size() == 0: return
	
	for i in range(items.get_child_count()):
		var item: CenterContainer = items.get_child(i) as CenterContainer
		var target_y: float = prev_y[i]
		if i == current_submenu and state != State.NONE:
			target_y -= 48
			item_text[i].outline_color = Color.BLACK
			var t: float = (sin((selection_time * 4 - deg_to_rad(90.0))) + 1.0) / 8.0
			highlights[i].modulate.a = t
		else:
			item_text[i].outline_color = item_text_colors[i]
			highlights[i].modulate.a = 0
		if i == current_submenu:
			item.global_position.y = lerpf(prev_y[i], target_y, ease_out_back(minf(1.0, selection_time * 3)))
		else:
			item.global_position.y = lerpf(item.global_position.y, target_y, delta * 16)
		if state == State.NONE:
			item.global_position.y = lerpf(720, prev_y[i], ease_out_back(minf(1.0, (transition_time * 2.5) - (i * 0.25))))

func _don_pressed(id: Variant) -> void:
	if not Globals.players_entered[id]: return
	Globals.control_banner.deactivate()
	Globals.control_banner.deactivate_side()
	if current_submenu == 0:
		SoundHandler.play_sound("cancel.wav")
		TransitionHandler.change_scene_to_file("uid://dyvmwrm570eh6", true, Color("#6ABCC5"), true)
		return

func _kat_pressed(_id: Variant, side: Variant) -> void:
	selection_time = 0.0
	current_submenu = wrapi(current_submenu + side, 0, items.get_child_count())
