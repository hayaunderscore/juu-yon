@tool
extends TextureRect
class_name TaikoGauge

signal filled_soul
signal unfilled_soul
signal rainbow_soul
signal unrainbow_soul

@onready var meter: TextureRect = $Meter
@onready var rainbow_parallax: Parallax2D = %Rainbow
@onready var soul: TextureRect = $Soul
@onready var fire: Sprite2D = $Soul/Fire

var rainbow: bool = false
var total_notes: int = 0
var difficulty: TJAChartInfo.CourseType
@export_range(0.0, 100.0) var value: float = 0.0:
	set(v):
		if value == v: return
		if is_instance_valid(meter):
			var s: float = snappedf(v, 1.78)
			if v >= 100: s = 100
			meter.size.x = lerpf(0, 448, minf(1.0, s / 100.0))
		value = v

const clear_start: float = 78.6

# For now, each star is kept with the same exact rate
const table: Array[Dictionary] = [
	{ "clear_rate": 44.0, "ok_multiplier": 0.75, "bad_multiplier": -0.5 },
	{ "clear_rate": 52.5, "ok_multiplier": 0.75, "bad_multiplier": -1.0 },
	{ "clear_rate": 48.5, "ok_multiplier": 0.75, "bad_multiplier": -1.2 },
	{ "clear_rate": 60, "ok_multiplier": 0.5, "bad_multiplier": -2.0 },
	{ "clear_rate": 60, "ok_multiplier": 0.5, "bad_multiplier": -2.0 },
]

func add_good():
	var prev: float = value
	value += (1.0 / total_notes) * (100 * (clear_start / table[difficulty]["clear_rate"]))
	_update_signals(prev)

func add_ok():
	var prev: float = value
	value += (table[difficulty]["ok_multiplier"] / total_notes) * (100 * (clear_start / table[difficulty]["clear_rate"]))
	_update_signals(prev)

func add_bad():
	var prev: float = value
	value += (table[difficulty]["bad_multiplier"] / total_notes) * (100 * (clear_start / table[difficulty]["clear_rate"]))
	_update_signals(prev)

var fire_tween: Tween
func _update_signals(prev: float):
	if prev < clear_start and value >= clear_start:
		filled_soul.emit()
	if prev >= clear_start and value < clear_start:
		unfilled_soul.emit()
	if prev < 100.0 and value >= 100.0:
		rainbow_soul.emit()
		if fire_tween: fire_tween.kill()
		fire_tween = create_tween()
		fire_tween.tween_property(fire, "scale", Vector2.ONE * 1.4, 0.05)
		fire_tween.tween_property(fire, "scale", Vector2.ONE * 1.0, 0.3).set_ease(Tween.EASE_OUT)
		rainbow_parallax.show()
	if prev >= 100.0 and value < 100.0:
		unrainbow_soul.emit()
		if fire_tween: fire_tween.kill()
		fire_tween = create_tween()
		fire_tween.tween_property(fire, "scale", Vector2.ZERO, 0.1)
		rainbow_parallax.hide()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	fire.frame = (fire.frame + 1) % fire.hframes
	if value >= 100.0: 
		soul.visible = true
		soul.self_modulate.a = 0.0 if soul.self_modulate.a == 1.0 else 1.0
