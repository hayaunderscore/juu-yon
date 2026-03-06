@tool
extends Control
class_name MinimalMonoLabel

@export var text: String = "":
	set(value):
		if text == value: return
		text = value
		update_minimum_size()
		queue_redraw()
@export var label_settings: LabelSettings = LabelSettings.new():
	set(value):
		if label_settings == value: return
		label_settings = value
		update_minimum_size()
		queue_redraw()
@export var horizontal_alignment: HorizontalAlignment:
	set(value):
		if horizontal_alignment == value: return
		horizontal_alignment = value
		update_minimum_size()
		queue_redraw()
@export var vertical_alignment: VerticalAlignment:
	set(value):
		if vertical_alignment == value: return
		vertical_alignment = value
		update_minimum_size()
		queue_redraw()
@export var spacing: int = 16:
	set(value):
		if spacing == value: return
		spacing = value
		update_minimum_size()
		queue_redraw()
@export var visual_offset: Vector2:
	set(value):
		if visual_offset == value: return
		visual_offset = value
		update_minimum_size()
		queue_redraw()

func _get_minimum_size() -> Vector2:
	var txt: String = tr(text)
	return Vector2(spacing * len(txt), label_settings.font_size)

func _draw() -> void:
	var txt: String = tr(text)
	var origin: Vector2 = Vector2.ZERO
	var leng: int = spacing * len(txt)
	match horizontal_alignment:
		HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER:
			origin.x = (size.x / 2.0) - (leng / 2.0)
		HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT:
			origin.x = size.x - leng
	match vertical_alignment:
		VerticalAlignment.VERTICAL_ALIGNMENT_CENTER:
			origin.y = (size.y / 2.0) - (label_settings.font_size / 2.0)
		VerticalAlignment.VERTICAL_ALIGNMENT_BOTTOM:
			origin.y = size.y - label_settings.font_size
	var offset: Vector2 = Vector2(0, 0)
	for chr in text:
		draw_set_transform(origin + offset + visual_offset + Vector2(spacing / 2.0, 0))
		var char_size: float = label_settings.font.get_char_size(ord(chr), label_settings.font_size).x
		if label_settings.outline_size > 0:
			draw_char_outline(label_settings.font, Vector2(-char_size / 2.0, 0.0), chr, label_settings.font_size, label_settings.outline_size, label_settings.outline_color)
		draw_string(label_settings.font, Vector2(-char_size / 2.0, 0.0), chr, 0, -1, label_settings.font_size, label_settings.font_color)
		# draw_char(label_settings.font, offset, chr, label_settings.font_size, label_settings.font_color)
		offset.x += spacing

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
