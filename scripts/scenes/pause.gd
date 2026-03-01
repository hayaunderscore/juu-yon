extends Control

var index: int = 0
var timer: float = 0

@onready var items: HBoxContainer = %MenuItems

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if get_tree().current_scene == self:
		open()

func open():
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	index = 0
	timer = 0
	for i in range(items.get_child_count()):
		var item: PanelContainer = items.get_child(i)
		item.self_modulate.a = 0.0
	$AnimationPlayer.play("Open")

func close(from_esc: bool):
	var current: int = index
	if from_esc: current = 0
	match current:
		0:
			$AnimationPlayer.play_backwards("Open")
			await $AnimationPlayer.animation_finished
			process_mode = Node.PROCESS_MODE_DISABLED
			get_tree().paused = false
		1:
			process_mode = Node.PROCESS_MODE_DISABLED
			get_tree().paused = false
			SongLoadHandler.reload_song()
			await get_tree().scene_changed
			$AnimationPlayer.play("Open", -1, -9999, true)
		2:
			process_mode = Node.PROCESS_MODE_DISABLED
			get_tree().paused = false
			get_tree().current_scene.process_mode = Node.PROCESS_MODE_DISABLED
			TransitionHandler.change_scene_to_file("uid://b8jopawilsvnu", true)
		3:
			process_mode = Node.PROCESS_MODE_DISABLED
			get_tree().paused = false
			get_tree().current_scene.process_mode = Node.PROCESS_MODE_DISABLED
			TransitionHandler.change_scene_to_file("uid://dyvmwrm570eh6", true)
			

func _process(delta: float) -> void:
	timer += delta
	
	if timer < 0.7: return
	
	if Input.is_action_just_pressed("kat_left_p1"):
		index = wrapi(index - 1, 0, items.get_child_count())
		SoundHandler.play_sound("ka.wav")
	elif Input.is_action_just_pressed("kat_right_p1"):
		index = wrapi(index + 1, 0, items.get_child_count())
		SoundHandler.play_sound("ka.wav")
	
	if Input.is_action_just_pressed("don_left_p1") or Input.is_action_just_pressed("don_right_p1"):
		SoundHandler.play_sound("dong.wav")
		if index > 1:
			SoundHandler.play_sound("cancel.wav")
		close(false)
	
	for i in range(items.get_child_count()):
		var item: PanelContainer = items.get_child(i)
		if i == index:
			item.self_modulate.a = lerpf(item.self_modulate.a, 1.0, delta * 12)
		else:
			item.self_modulate.a = lerpf(item.self_modulate.a, 0.0, delta * 12)
