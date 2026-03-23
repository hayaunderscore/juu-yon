extends TextureRect
class_name TaikoDrum

@onready var light_up: Array[Array] = [
	[$Don_0, $Don_1],
	[$Kat_0, $Kat_1]
]
@export var don_light_up: TextureRect
@export var kat_light_up: TextureRect
@export var good_light_up: TextureRect
@export var difficulity_light_up: Sprite2D
@export var difficulity_light_up_good: Sprite2D
@export var combo_callout_min: int = 10
@onready var note_sounds: Array[String] = [
	"dong.wav", "ka.wav"
]
@onready var combo_numbers: TaikoNumber = $ComboText
@onready var flower: Sprite2D = $Flower
var counter_atlas: Texture2D = preload("res://assets/game/combo/taiko/counter.png")
var counter_100_atlas: Texture2D = preload("res://assets/game/combo/taiko/counter_100.png")
var last_tweens: Array[Array] = [
	[null, null],
	[null, null]
]
var last_ids: Array[Array] = [
	[-1, -1],
	[-1, -1]
]
var flower_tween: Tween
var combo: int = 0:
	set(n_combo):
		combo = n_combo
		if not is_inside_tree(): return
		if not combo_numbers: return
		if combo < 10: combo_numbers.hide(); return
		if !combo_numbers.visible: combo_numbers.show()
		combo_numbers.value = n_combo
		# Change font accordingly
		combo_numbers.font = counter_atlas if combo < 100 else counter_100_atlas
		combo_numbers.font_size = Vector2.ONE * (48 if combo < 100 else 60)
		var s: Vector2 = combo_numbers.font.get_size()
		combo_numbers.scaling_pivot = Vector2(s.x / 2.0, s.y)
		combo_numbers.glyph_offset = -12 if combo < 100 else -20
		# combo_numbers.scale.y = 1.2
		if combo % combo_callout_min == 0 and combo > 0:
			combo_callout.emit(combo)
		# Handle flower stuff
		if combo % 100 == 0 and combo > 0:
			if flower_tween: flower_tween.kill()
			flower_tween = create_tween()
			if combo == 100:
				flower.modulate.a = 1.0
				flower.scale = Vector2.ZERO
				flower_tween.tween_property(flower, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			else:
				flower_tween.tween_property(flower, "modulate:a", 1.0, 0.1)
			flower_tween.tween_property(flower, "modulate:a", 0.0, 0.1).set_delay(4.7)

signal combo_callout(combo: int)

func _process(delta: float) -> void:
	don_light_up.modulate.a = move_toward(don_light_up.modulate.a, 0, delta*5)
	kat_light_up.modulate.a = move_toward(kat_light_up.modulate.a, 0, delta*5)
	good_light_up.modulate.a = move_toward(good_light_up.modulate.a, 0, delta*5)
	difficulity_light_up.modulate.a = move_toward(difficulity_light_up.modulate.a, 0, delta*5)
	difficulity_light_up_good.modulate.a = move_toward(difficulity_light_up_good.modulate.a, 0, delta*5)

func taiko_input(note: int, side: int, volume: int = 100, good: bool = true):
	var tween: Tween = last_tweens[note][side]
	if tween: tween.stop()
	if last_ids[note][side] > -1:
		SoundHandler.stop_sound(last_ids[note][side])
	last_ids[note][side] = SoundHandler.play_sound(note_sounds[note], (volume / 100.0) * 0.75)
	var tex: TextureRect = light_up[note][side]
	tex.modulate.a = 1.0
	(don_light_up if note == 0 else kat_light_up).modulate.a = 1.0
	var l: Sprite2D = difficulity_light_up
	if good: 
		good_light_up.modulate.a = 1.0
		l = difficulity_light_up_good
	l.modulate.a = 1.0
	last_tweens[note][side] = get_tree().create_tween()
	tween = last_tweens[note][side]
	tween.set_parallel(true)
	tween.tween_property(tex, "modulate:a", 0, 0.1).set_delay(0.1)
