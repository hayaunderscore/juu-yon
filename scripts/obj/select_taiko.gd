extends TextureRect
class_name SelectTaiko

var player: int = 0:
	set(value):
		if player == value: return
		player = value
		for i in controls.size():
			for j in controls[i].size():
				var type: String = "don" if i == 0 else "kat"
				var side: String = "left" if j == 0 else "right"
				var suffix: String = "_p%d" % [value+1]
				var action: String = "%s_%s%s" % [type, side, suffix]
				controls[i][j] = action
				
var entry_mode: bool = false
var active: bool = true
var full_active: bool = true
var side_active: bool = true:
	set(v):
		if v == side_active: return
		side_active = v
		if Engine.is_editor_hint(): return
		if $Fade/KatLeft and $Fade/KatRight:
			$Fade/KatLeft.visible = v
			$Fade/KatRight.visible = v
		if indicator_tween: indicator_tween.stop()
		indicator_tween = get_tree().create_tween()
		indicator_tween.set_parallel(true)
		did_indicator = false
		for indicator in indicators:
			if not indicator: continue
			indicator.modulate.a = 0.0 if side_active else 1.0
			indicator_tween.tween_property(indicator, "modulate:a", 1.0 if side_active else 0.0, 0.1)
			
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var light_up: Array[Array] = [
	[$DonLeft, $DonRight],
	[$KatLeft, $KatRight]
]
@onready var indicators: Array[TaikoText] = [
	$ControlLabels/Right, $ControlLabels/Left
]
@onready var note_sounds: Array[String] = [
	"dong.wav", "ka.wav"
]
var last_tweens: Array[Array] = [
	[null, null],
	[null, null]
]

signal don_pressed(id)
signal kat_pressed(id, dir)

var controls: Array[PackedStringArray] = [
	["don_left_p1", "don_right_p1"],
	["kat_left_p1", "kat_right_p1"],
]

var orig_pos: Vector2
var did_indicator: bool = false

func _ready() -> void:
	orig_pos = global_position
	anim.play("Default")
	visible = Globals.players_entered[player]
	
var did: bool = false

func taiko_input(note: int, side: int, volume: int = 100):
	var tween: Tween = last_tweens[note][side]
	if tween: tween.stop()
	SoundHandler.play_sound(note_sounds[note], volume / 100.0)
	var tex: TextureRect = light_up[note][side]
	tex.modulate.a = 1.0
	last_tweens[note][side] = get_tree().create_tween()
	tween = last_tweens[note][side]
	tween.set_parallel(true)
	if note == 1:
		if indicator_tween: indicator_tween.stop()
		var other_side: int = 0 if side == 1 else 1
		indicators[side].modulate.a = 1
		indicators[other_side].modulate.a = 0
		indicators[side].position.y = 24.0
		tween.tween_property(indicators[side], "position:y", 48, 0.15)
		did_indicator = true
		kat_pressed.emit(player, -1 if side == 0 else 1)
	elif note == 0 and side == 0:
		don_pressed.emit(player)
	tween.tween_property(tex, "modulate:a", 0, 0.1).set_delay(0.25)
	global_position.y = orig_pos.y + 8
	anim.play("RESET")
	$Timer.start()

func _process(delta: float) -> void:
	global_position.y = move_toward(global_position.y, orig_pos.y, delta*64)
	
	var t: String = tr($ControlLabels/Decide.text)
	if len(t) > 2:
		# print("HI")
		$ControlLabels/Decide.scale = (((len(t) - 1.0) / len(t))) * Vector2.ONE
	else:
		$ControlLabels/Decide.scale = Vector2.ONE
	
	if not Globals.players_entered[player]: 
		visible = false
		if not entry_mode:
			return
	if not active: return
	if not full_active: return
	if not entry_mode: visible = true
	
	if Input.is_action_just_pressed(controls[0][0]) or Input.is_action_just_pressed(controls[0][1]):
		taiko_input(0, 0, 0)
		taiko_input(0, 1)
	if side_active:
		if Input.is_action_just_pressed(controls[1][0]):
			taiko_input(1, 0)
		if Input.is_action_just_pressed(controls[1][1]):
			taiko_input(1, 1)

var indicator_tween: Tween

func _on_timer_timeout() -> void:
	anim.play("Default")
	if not did_indicator: return
	did_indicator = false
	if indicator_tween:
		indicator_tween.stop()
	indicator_tween = get_tree().create_tween()
	indicator_tween.set_parallel(true)
	for indicator in indicators:
		indicator_tween.tween_property(indicator, "modulate:a", 1.0, 0.1)
