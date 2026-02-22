@tool
extends Control
class_name TaikoNumber

@export var font: Texture2D
@export var font_size: Vector2i
@export var alignment: HorizontalAlignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
@export var value: int:
	set(n_value):
		value = n_value
		queue_redraw()
@export var glyph_offset: float = 0.0
@export var speed_override: float = 0.0

@export_group("Scaling", "scaling_")
@export var scaling_individual: bool = false
@export var scaling_pivot: Vector2
@export var scaling_ignore: int = 0
@export var scaling_add: Vector2 = Vector2.ZERO

@export var letters_scale: Array[Vector2]
var last_len: int
var last_value: int

@export_tool_button("Force Redraw") var redraw_action = redraw

func redraw():
	queue_redraw()

func bump_indiv_scaling():
	var st: String = str(value)
	var length: int = len(st)
	if last_len != length:
		for i in range(length - last_len):
			letters_scale.push_front(Vector2.ONE)
		for j in range(length - scaling_ignore):
			letters_scale[j] = Vector2.ONE + scaling_add
		last_len = length
	var change_last_zero: bool = false
	var last_st: String = str(last_value)
	for i in range(length):
		if (i < last_len and last_st.length() > i and st.length() > i and last_st.unicode_at(i) != st.unicode_at(i)) \
		or (change_last_zero and i >= length - (scaling_ignore + 1)):
			letters_scale[i] = Vector2.ONE + scaling_add
			change_last_zero = true

func _draw() -> void:
	var st: String = str(value)
	var length: int = len(st)
	letters_scale.resize(length)
	# print("hi")
	if last_value != value:
		# print("reset scales")
		if not scaling_individual:
			for j in range(0, length):
				letters_scale[j] = Vector2.ONE + scaling_add
		else:
			bump_indiv_scaling()
		last_value = value
			# print("haha reset not indiv")
	var width: float = length * font_size.x
	width += glyph_offset * (length - 1)
	var pos: Vector2 = Vector2(0.0, size.y - font_size.y)
	match alignment:
		HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT:
			pass
		HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER, HorizontalAlignment.HORIZONTAL_ALIGNMENT_FILL:
			pos.x = (size.x / 2.0) - (width / 2.0)
		HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT:
			pos.x = size.x - width
	for i in range(0, length):
		var chr: String = st[i]
		var scal: Vector2 = letters_scale[i] if i < letters_scale.size() else Vector2.ONE
		# scal = scal.max(Vector2.ONE)
		if not chr.is_valid_int(): continue
		draw_set_transform(pos + scaling_pivot, 0, scal)
		draw_texture_rect_region(font, Rect2(-scaling_pivot, font_size), Rect2(Vector2(chr.to_int() * font_size.x, 0.0), font_size))
		pos.x += font_size.x + glyph_offset

func _process(delta: float) -> void:
	var speed: float = 2.0 if is_zero_approx(speed_override) else speed_override
	for i in range(len(letters_scale)):
		var scal: Vector2 = letters_scale[i]
		if scal.length() > 0.0:
			letters_scale[i].x = move_toward(scal.x, 1.0, delta*speed)
			letters_scale[i].y = move_toward(scal.y, 1.0, delta*speed)
			# print(scal)
			queue_redraw()
