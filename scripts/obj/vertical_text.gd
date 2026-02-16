@tool
extends Texture2D
class_name VerticalText2D

@export var text: String:
	set(value):
		if value == text: return
		text = value
		_update_texture()

@export_storage var tr_text: String:
	get: return text
	set(value): text = value

@export_group("Font")
@export var font: Font:
	set(value):
		if value == font: return
		font = value
		_update_texture()
@export var font_size: int = 16:
	set(value):
		if value == font_size: return
		font_size = value
		_update_texture()
@export var font_color: Color = Color.WHITE:
	set(value):
		if value == font_color: return
		font_color = value
		_update_texture()
@export var outline_size: int = 0:
	set(value):
		if value == outline_size: return
		outline_size = value
		_update_texture()
@export var outline_color: Color = Color.BLACK:
	set(value):
		if value == outline_color: return
		outline_color = value
		_update_texture()

@export_group("Layout")
@export var padding: Vector2i = Vector2i.ZERO:
	set(value):
		if value == padding: return
		padding = value
		_update_texture()
@export var scale: Vector2 = Vector2.ONE:
	set(value):
		if value == scale: return
		scale = value
		_update_texture()

# Character sets
var rotate_chars: PackedStringArray = [
	"-", "‐", "|", "/", "\\", "ー", "～", "~",
	"（", "）", "(", ")", "「", "」",
	"[", "]", "［", "］", "【", "】",
	"…", "→", ":", "："
]

var side_punctuation: PackedStringArray = [
	".", ",", "。", "、", "'", "\"", "´", "`"
]

# Characters that should be drawn horizontally when repeated
var horizontal_punct: PackedStringArray = [
	"?", "!", "？", "！", "†"
]

var lowercase_kana: PackedStringArray = [
	"ぁ", "ア", "ぃ", "イ", "ぅ", "ウ", "ぇ", "エ", "ぉ", "オ",
	"ゃ", "ャ", "ゅ", "ュ", "ょ", "ョ", "っ", "ッ", "ゎ", "ヮ",
	"ヶ", "ヵ", "ㇰ", "ㇱ", "ㇲ", "ㇳ", "ㇴ", "ㇵ", "ㇶ", "ㇷ", "ㇸ",
	"ㇹ", "ㇺ", "ㇻ", "ㇼ", "ㇽ", "ㇾ", "ㇿ", "ィ"
]

static var group_sequence_cache: Dictionary[String, Array]
var _group_sequence: Array[PackedStringArray]
var _text_size: Vector2 = Vector2.ZERO

# Group consecutive horizontal punctuation marks
func group_horizontal_sequences(txt: String) -> Array[PackedStringArray]:
	if group_sequence_cache.has(txt):
		return group_sequence_cache[txt]
	
	var groups: Array[PackedStringArray] = []
	var i: int = 0
	
	while i < txt.length():
		var ch: String = txt[i]
		if ch in horizontal_punct:
			# Start of a horizontal sequence
			var sequence: String = ch
			var j: int = i + 1
			# Collect consecutive horizontal punctuation
			while j < txt.length() and txt[j] in horizontal_punct:
				sequence += txt[j]
				j += 1
			# Only treat as horizontal if 2 or more characters
			if sequence.length() >= 2:
				groups.append(["horizontal", sequence])
			else:
				groups.append(["single", sequence])
			i = j
		else:
			groups.append(["single", ch])
			i += 1
	
	group_sequence_cache.set(txt, groups)
	return groups

# Helper function to calculate adjusted character height
func get_char_height(chr: String) -> float:
	if chr in side_punctuation:
		return font_size / 4.0
	elif (chr.to_lower() == chr and chr.to_upper() != chr) or chr in lowercase_kana:
		return font_size * 0.88
	elif chr == " " or chr == "\n" or chr == "\t":
		return font_size * 0.6
	else:
		return font_size

func _init() -> void:
	if font == null:
		font = ThemeDB.fallback_font

var _size_update_called: bool = false

func _update_size():
	_size_update_called = false
	_text_size = Vector2.ZERO
	
	var t: String = tr(text)
	_group_sequence = group_horizontal_sequences(t)
	
	for group in _group_sequence:
		var group_type: String = group[0]
		var content: String = group[1]
		
		if group_type == 'horizontal':
			var seq_size: Vector2 = font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size) * scale
			_text_size.x = maxf(_text_size.x, seq_size.x)
			_text_size.y += font_size * scale.y # Horizontal sequences use full font_size
		else:
			var char_size: Vector2 = font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size) * scale
			var effective_width: float = char_size.x
			if content in rotate_chars:
				effective_width = char_size.y
			_text_size.x = maxf(_text_size.x, effective_width)
			_text_size.y += get_char_height(content) * scale.y

func _update_texture():
	if not _size_update_called:
		_size_update_called = true
		_update_size.call_deferred()
		emit_changed.call_deferred()

func _get_width() -> int:
	return int(int(_text_size.x + (padding.x * 2)) / scale.x)

func _get_height() -> int:
	return int(int(_text_size.y + (padding.y * 2)) / scale.y)

func _draw_string(to_canvas_item: RID, rect: Rect2, _tile: bool, modulate: Color, _transpose: bool = false, outline: bool = false) -> void:
	if _group_sequence.is_empty() or _text_size.y <= 0: return
	if modulate.a <= 0: return
	
	var width: int = get_width()
	var color: Color = outline_color if outline else font_color
	color *= modulate
	var cur_char_y: float = 0
	
	# rect.position += Vector2(padding / 2.0)
	rect.position.y += padding.y
	
	for group in _group_sequence:
		var group_type: String = group[0]
		var content: String = group[1]
		
		if group_type == 'horizontal':
			var char_y: float = font_size * scale.y
			cur_char_y += char_y
			var seq_size: Vector2 = font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO) * scale
			var char_x: float = (width / 2.0)
			
			var transform: Transform2D = Transform2D(0.0, scale, 0.0, rect.position + Vector2(char_x, cur_char_y - floori(char_y / 2.0)))
			RenderingServer.canvas_item_add_set_transform(to_canvas_item, transform)
			
			if outline:
				font.draw_string_outline(to_canvas_item, Vector2(-seq_size.x / 2.0, floori(char_y / 2.0)), content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, color, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_HORIZONTAL, 2.0)
			else:
				font.draw_string(to_canvas_item, Vector2(-seq_size.x / 2.0, floori(char_y / 2.0)), content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_HORIZONTAL, 2.0)
		else:
			var char_y: float = get_char_height(content) * scale.y
			cur_char_y += char_y
			var char_size: Vector2 = font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO) * scale
			var effective_width: float = char_size.x
			var char_x: float = width / 2.0
			var char_y_ofs: float = 0.0
			var sc: Vector2 = scale
			if content in rotate_chars:
				sc = sc.rotated(deg_to_rad(-90))
				# effective_width = char_size.y
				#char_x -= 0.1 * char_size.y * sc.x
				#char_y_ofs += 0.1 * char_size.y * sc.x
				# print(char_size.y)
			if content in side_punctuation:
				char_x += font_size / 3.0
			
			# Here, we manually set the transform lmao
			# Unfortunately this is the ONLY way to set the rotation of something. Too bad!
			var rot: float = deg_to_rad(90.0) if content in rotate_chars else 0.0
			var transform: Transform2D = Transform2D(rot, sc, 0.0, rect.position + Vector2(char_x, cur_char_y + char_y_ofs - floori(char_y / 2.0)))
			RenderingServer.canvas_item_add_set_transform(to_canvas_item, transform)
			
			char_x = -floori(effective_width / 2.0)
			
			if outline:
				font.draw_string_outline(to_canvas_item, Vector2(char_x, floori(char_y / 2.0)), content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, color, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_HORIZONTAL, 2.0)
			else:
				font.draw_string(to_canvas_item, Vector2(char_x, floori(char_y / 2.0)), content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_HORIZONTAL, 2.0)
			
			# Reset transform afterwards
			RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D())

func _draw_rect(to_canvas_item: RID, rect: Rect2, tile: bool, modulate: Color, transpose: bool) -> void:
	if outline_size > 0:
		_draw_string(to_canvas_item, rect, tile, modulate, transpose, true)
	_draw_string(to_canvas_item, rect, tile, modulate, transpose, false)

func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	var rect: Rect2 = Rect2(pos, Vector2(get_width(), get_height()))
	_draw_rect(to_canvas_item, rect, false, modulate, transpose)

func _draw_rect_region(to_canvas_item: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
	_draw_rect(to_canvas_item, rect, false, modulate, transpose)
