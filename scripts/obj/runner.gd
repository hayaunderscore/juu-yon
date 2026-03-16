@tool
extends Sprite2D
class_name TaikoRunner

enum RunnerType {
	TADPOLE,
	BIRDS,
	KENDAMAS,
	LANTERNS,
	BALLOONS,
	MAX,
}

enum VerticalAnimType {
	NONE,
	BOUNCE,
	SINE,
}

const RUNNER_PATH: String = "res://assets/game/runners/"
const RUNNER_DICT: Dictionary[RunnerType, Dictionary] = {
	RunnerType.TADPOLE: {
		"count": 1,
		"frames": 5,
		"speed": 1.0,
		"vtype": VerticalAnimType.SINE,
		"offset": Vector2.ZERO,
	},
	RunnerType.BIRDS: {
		"count": 4,
		"frames": 7,
		"speed": 1.0,
		"vtype": VerticalAnimType.SINE,
		"offset": Vector2.ZERO,
	},
	RunnerType.KENDAMAS: {
		"count": 4,
		"frames": 10,
		"speed": 1.0,
		"vtype": VerticalAnimType.BOUNCE,
		"offset": Vector2(0, 48),
		"jump_height": 72,
	},
	RunnerType.LANTERNS: {
		"count": 4,
		"frames": 5,
		"speed": 1.0,
		"vtype": VerticalAnimType.BOUNCE,
		"offset": Vector2(0, 32),
	},
	RunnerType.BALLOONS: {
		"count": 4,
		"frames": 5,
		"speed": 1.0,
		"vtype": VerticalAnimType.NONE,
		"offset": Vector2(0, 32),
	}
}

@export var runner_type: RunnerType = RunnerType.TADPOLE:
	set(value):
		if value == runner_type: return
		runner_type = value
		_update_runner_texture()
@export var variation: int = 0:
	set(value):
		if value == variation: return
		variation = value % vframes
		frame_coords.y = variation
var beat: float = 0.0
var spawned_beat: float = 0.0

var _current_interval: int = 0
var _last_interval: int = 0
var _speed: float = 0.0
var _bounce_type: VerticalAnimType = VerticalAnimType.NONE
var _offset: Vector2 = Vector2.ZERO
var _jump_height: float = 0.0

func _update_runner_texture():
	var dict: Dictionary = RUNNER_DICT[runner_type]
	texture = load(RUNNER_PATH + (RunnerType.find_key(runner_type) as String).to_lower() + ".png")
	vframes = dict.count
	hframes = dict.frames
	_speed = dict.speed
	_bounce_type = dict.vtype
	_offset = dict.offset
	_jump_height = dict.get("jump_height", 48.0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func jump(bpm: float):
	var tween: Tween = create_tween()
	tween.tween_property(self, "position:y", -56, minf(15 / bpm, 1.0)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position:y", 0, minf(15 / bpm, 1.0)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	_current_interval = floori(abs(beat - spawned_beat) / ((1.0 / (hframes)) * 1 * (1.0 / _speed)))
	if _current_interval != _last_interval:
		_last_interval = _current_interval
		frame_coords.x = wrapi(_current_interval, 0, hframes)
	position.x = lerpf(0, 768, abs(beat - spawned_beat) / 3.0)
	offset = _offset
	match _bounce_type:
		VerticalAnimType.NONE:
			pass
		VerticalAnimType.BOUNCE:
			offset.y += (abs(sin((abs(beat - spawned_beat) * _speed) * PI)) * -_jump_height)
		VerticalAnimType.SINE:
			offset.y += sin(abs(beat - spawned_beat) * _speed * PI) * 24
	if position.x >= 768: queue_free(); return
