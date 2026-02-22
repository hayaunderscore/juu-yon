@tool
extends Control
class_name TaikoText

@export var font: Font:
	set(v): 
		font = v
		queue_redraw()
@export var text: String = "":
	set(v): 
		text = v
		queue_redraw()
@export var alignment: HorizontalAlignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT:
	set(v):
		alignment = v
		queue_redraw()
@export var orientation: TextServer.Orientation = TextServer.Orientation.ORIENTATION_HORIZONTAL:
	set(v):
		orientation = v
		queue_redraw()
@export var translate: bool = true

@export_group("Colors")
@export var color: Color = Color.WHITE:
	set(v): 
		color = v
		queue_redraw()
@export var first_outline_color: Color = Color.BLACK:
	set(v): 
		first_outline_color = v
		queue_redraw()
@export var second_outline_color: Color = Color.BLACK:
	set(v): 
		second_outline_color = v
		queue_redraw()

@export_group("Sizes")
@export var text_size: int = 16:
	set(v): 
		text_size = v
		queue_redraw()
@export var first_outline_size: int = 0:
	set(v): 
		first_outline_size = v
		queue_redraw()
@export var second_outline_size: int = 0:
	set(v): 
		second_outline_size = v
		queue_redraw()

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var t: String = tr(text) if translate else text
	var length: int = len(t)
	var string_size: Vector2 = font.get_string_size(t, alignment, -1, text_size, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, orientation)
	var pos: Vector2 = Vector2(0.0, size.y - text_size / 2.0)
	match alignment:
		HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT:
			pass
		HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER, HorizontalAlignment.HORIZONTAL_ALIGNMENT_FILL:
			pos.x = (size.x / 2.0) - (string_size.x / 2.0)
		HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT:
			pos.x = size.x - string_size.x
	
	draw_string_outline(font, pos, t, alignment, -1, text_size, second_outline_size, second_outline_color, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, orientation)
	draw_string_outline(font, pos, t, alignment, -1, text_size, first_outline_size, first_outline_color, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, orientation)
	draw_string(font, pos, t, alignment, -1, text_size, color, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, orientation)
	draw_string_outline(font, pos, t, alignment, -1, text_size, 2, color, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, orientation)
