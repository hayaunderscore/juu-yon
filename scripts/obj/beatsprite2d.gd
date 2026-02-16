extends Sprite2D
class_name BeatSprite2D

@export var speed: float = 1.0
var beat: float = 0

var _current_interval: int = 0
var _last_interval: int = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	_current_interval = floori(beat / ((1.0 / (hframes)) * (1.0 / speed)))
	if _current_interval != _last_interval:
		_last_interval = _current_interval
		frame = abs(_current_interval % hframes)
