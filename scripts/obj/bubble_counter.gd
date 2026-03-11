@tool
extends TextureRect
class_name TaikoBubbleCounter

enum BubbleType {
	ROLL,
	BALLOON
}

const bubble_tex: Dictionary = {
	BubbleType.ROLL: preload("uid://c4qkeiijpip4q"),
	BubbleType.BALLOON: preload("uid://2dgb43b8ssk7")
}

@export var bubble_type: BubbleType = BubbleType.ROLL:
	set(value):
		if value == bubble_type: return
		bubble_type = value
		_change_bubble_graph()
@export var value: int = 0: set = _set_value

@onready var counter: MinimalMonoLabel = $CenterContainer/Counter
var value_tween: Tween

func _change_bubble_graph():
	texture = bubble_tex[bubble_type]

func _set_value(new_value: int):
	if new_value == value: return
	value = new_value
	counter.text = str(new_value)
	counter.pivot_offset = counter.size * 0.5
	counter.pivot_offset_ratio = Vector2.ONE * 0.5
	if value_tween:
		value_tween.custom_step(9999)
		value_tween.kill()
	value_tween = create_tween()
	value_tween.tween_property(counter, "scale:y", 1.2, 0.05)
	value_tween.tween_property(counter, "scale:y", 1.0, 0.1)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
