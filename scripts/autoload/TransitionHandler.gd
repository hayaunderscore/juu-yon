extends Node

var fade: CanvasLayer = preload("uid://d4jfdar6k3g24").instantiate()
var anim: AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_child.call_deferred(fade)
	anim = fade.get_node("AnimationPlayer")

func change_scene_to_file(path: String, song_select: bool = false, color: Color = Color.WHITE, force_color: bool = false):
	if not song_select or force_color:
		for spr in fade.get_children():
			if spr is Sprite2D:
				spr.modulate = color
	anim.play("MoveIn")
	await anim.animation_finished
	Globals.control_banner.visible = song_select
	if song_select:
		Globals.song_name = ""
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	if song_select: anim.play("MoveOut")
