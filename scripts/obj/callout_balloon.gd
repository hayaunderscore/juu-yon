extends TextureRect
class_name CalloutBalloon

@onready var number: TaikoNumber = %TaikoNumber
@onready var number_pivot: Control = $Control
@onready var anim: AnimationPlayer = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	modulate.a = 0

func show_combo(combo: int):
	number.value = combo
	if str(combo).length() > 2:
		number_pivot.scale.x = 3.0 / str(combo).length()
	anim.stop()
	anim.play("default")
	var audio: String = "res://assets/snd/combo/combo_voice_%d_p1.wav" % [combo]
	if ResourceLoader.exists(audio):
		SoundHandler.play_sound(audio.lstrip("res://assets/snd/"))
	
