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
@export var scaling_speed: float = 0.15
@export var return_speed: float = 0.2

var letters_scale: Array[Vector2]
var letters_tween: Array[Tween]
var last_len: int
var last_value: int

@export_tool_button("Force Redraw") var redraw_action = redraw

func redraw():
	queue_redraw()

func create_letter_tween(i: int):
	if letters_tween[i] and is_instance_valid(letters_tween[i]):
		letters_tween[i].custom_step(9999)
		letters_tween[i].kill()
	letters_tween[i] = create_tween()
	letters_tween[i].tween_method(func(val):
		letters_scale[i] = val
	, Vector2.ONE, Vector2.ONE + scaling_add, scaling_speed)
	letters_tween[i].tween_method(func(val):
		letters_scale[i] = val
	, Vector2.ONE + scaling_add, Vector2.ONE, return_speed)

func bump_indiv_scaling():
	var st: String = str(value)
	var length: int = len(st)
	if last_len != length:
		for i in range(length - last_len):
			letters_tween.push_front(null)
			letters_scale.push_front(Vector2.ONE)
		for j in range(length - scaling_ignore):
			create_letter_tween(j)
		last_len = length
	var change_last_zero: bool = false
	var last_st: String = str(last_value)
	for i in range(length):
		if (i < last_len and last_st.length() > i and st.length() > i and last_st.unicode_at(i) != st.unicode_at(i)) \
		or (change_last_zero and i >= length - (scaling_ignore + 1)):
			create_letter_tween(i)
			change_last_zero = true

func _draw() -> void:
	var st: String = str(value)
	var length: int = len(st)
	letters_scale.resize(length)
	letters_tween.resize(length)
	for i in range(letters_scale.size()):
		if is_zero_approx(letters_scale[i].length()):
			letters_scale[i] = Vector2.ONE
	# print("hi")
	if last_value != value:
		# print("reset scales")
		if not scaling_individual:
			for j in range(0, length):
				create_letter_tween(j)
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

func _process(_delta: float) -> void:
	if is_zero_approx(scaling_add.length()): return
	for i in range(len(letters_scale)):
		queue_redraw()
