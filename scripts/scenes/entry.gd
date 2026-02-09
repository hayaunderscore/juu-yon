extends Control

@onready var anims: Array[AnimationPlayer] = [
	$Player1Anim
]
@onready var global_anim: AnimationPlayer = $GlobalAnims
@onready var bumpers: Array[BumpinPanel] = [
	$BumperP1/Panel,
	$BumperP2/Panel
]

var done: bool = false

func _ready() -> void:
	Globals.control_banner.player_entry.connect(_on_control_banner_player_entry)
	Globals.control_banner.don_pressed.connect(_on_control_banner_don_pressed)
	Globals.control_banner.entry_mode = true

func _exit_tree() -> void:
	Globals.control_banner.player_entry.disconnect(_on_control_banner_player_entry)
	Globals.control_banner.don_pressed.disconnect(_on_control_banner_don_pressed)
	Globals.control_banner.entry_mode = false

func _on_timer_timeout() -> void:
	global_anim.play("MoveCurtain")
	await global_anim.animation_finished
	get_tree().change_scene_to_file("uid://b8jopawilsvnu")

func _on_control_banner_player_entry(id: Variant) -> void:
	Globals.control_banner.deactivate_side.call_deferred()
	bumpers[id].disable()
	anims[id].play("Enter")
	$Voice.play()

func _on_control_banner_don_pressed(id: Variant) -> void:
	if not Globals.players_entered[id]: return
	if done: return
	Globals.control_banner.deactivate_side.call_deferred()
	anims[id].play("Confirm")
	for bumper in bumpers:
		bumper.disable()
	$Timer.start()
	$Voice.stop()
	done = true
