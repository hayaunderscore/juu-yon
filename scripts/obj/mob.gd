extends Sprite2D
class_name TaikoMob

var beat: float = 0.0
var move_tween: Tween

func enter():
	if move_tween:
		move_tween.kill()
	move_tween = create_tween()
	move_tween.tween_property(self, "global_position:y", 514, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func exit():
	if move_tween:
		move_tween.kill()
	move_tween = create_tween()
	move_tween.tween_property(self, "global_position:y", 784, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	offset.y = (abs(sin(beat * PI)) * -64)
