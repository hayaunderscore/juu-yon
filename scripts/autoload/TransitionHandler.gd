extends Node

var fade: CanvasLayer = preload("uid://bsq8103sgqhv1").instantiate()
var anim: AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_child.call_deferred(fade)
	anim = fade.get_node("AnimationPlayer")

func change_scene_to_file(path: String, song_select: bool = false):
	anim.play("FadeIn")
	await anim.animation_finished
	Globals.control_banner.visible = song_select
	if song_select:
		Globals.song_name = ""
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	anim.play("FadeOut")
