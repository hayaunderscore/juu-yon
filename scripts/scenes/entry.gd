extends Control

@onready var anims: Array[AnimationPlayer] = [
	$Player1Anim
]
@onready var global_anim: AnimationPlayer = $GlobalAnims
@onready var control_labels: Array[Label] = [
	%ControlLabelP1,
	%ControlLabelP2
]
@onready var taikos: Array[SelectTaiko] = [
	%TaikoP1,
	%TaikoP2
]

var done: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for taiko in taikos:
		taiko.side_active = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	for label in control_labels:
		label.modulate.a = minf(1.0, sin(Engine.get_frames_drawn() / 500.0) + 0.5)
	if done: 
		for taiko in taikos:
			taiko.active = false
		return
	for p in range(Globals.players_entered.size()):
		taikos[p].active = Globals.players_entered[p]
	if (Input.is_action_just_pressed("don_left") or Input.is_action_just_pressed("don_right")):
		if not Globals.players_entered[0]:
			Globals.players_entered[0] = true
			control_labels[0].hide()
			anims[0].play("Enter")
			taikos[0].show()
			taikos[0].active = true
			$Voice.play()
		else:
			anims[0].play("Confirm")
			$Timer.start()
			done = true
		# SoundHandler.play_sound("dong.wav")

func _on_timer_timeout() -> void:
	global_anim.play("MoveCurtain")
	await global_anim.animation_finished
	get_tree().change_scene_to_file("uid://b8jopawilsvnu")
