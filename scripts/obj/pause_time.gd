extends Node
class_name PauseTimeHandle

var time: float = 0.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if get_tree().paused: 
		time += delta
