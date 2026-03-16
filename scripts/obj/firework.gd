@tool
extends Sprite2D
class_name TaikoFirework

enum FireworkType {
	RED,
	BLUE,
	GOGO_BLUE,
	GOGO_GREEN,
	GOGO_RED
}

const TEXTURES: Dictionary[FireworkType, Texture2D] = {
	FireworkType.RED: preload("uid://c86n6aob3080k"),
	FireworkType.BLUE: preload("uid://cxmb5dm55jqto"),
	FireworkType.GOGO_BLUE: preload("uid://30w52pfqume6"),
	FireworkType.GOGO_GREEN: preload("uid://bfobq7st74fi6"),
	FireworkType.GOGO_RED: preload("uid://e0prcgq6k06y"),
}

const TEXTURES_HFRAMES: Dictionary[FireworkType, int] = {
	FireworkType.RED: 16,
	FireworkType.BLUE: 16,
	FireworkType.GOGO_BLUE: 12,
	FireworkType.GOGO_GREEN: 12,
	FireworkType.GOGO_RED: 12,
}

@export var type: FireworkType = FireworkType.RED:
	set = _update_type
var _target_interval: int = 2

func _update_type(val: FireworkType):
	if val == type: return
	type = val
	texture = TEXTURES[type]
	hframes = TEXTURES_HFRAMES[type]
	_target_interval = 2 if type <= FireworkType.BLUE else 8

var increased: bool = false
var interval: int = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if interval % _target_interval == 0:
		var new_frame: int = frame + 1
		if new_frame >= hframes: queue_free()
		frame = clampi(new_frame, 0, hframes - 1)
	interval += 1
