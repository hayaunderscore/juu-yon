extends Control

var entry_scene: PackedScene = preload("uid://vxy0gpt3o0c8")
var started: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Globals.control_banner.deactivate()
	Globals.control_banner.deactivate_side()
	Globals.control_banner.global_position.y += Globals.control_banner.size.y

func start():
	started = true
	var control_banner_tween: Tween = create_tween()
	control_banner_tween.tween_property(Globals.control_banner, "global_position:y", -Globals.control_banner.size.y, 0.5).as_relative().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	SoundHandler.play_sound("dong.wav")
	$AnimationPlayer.play("Enter")
	await $AnimationPlayer.animation_finished
	get_tree().change_scene_to_packed(entry_scene)

func _unhandled_input(event: InputEvent) -> void:
	if started: return
	if event is InputEventKey:
		if event.keycode == KEY_SPACE:
			start()
