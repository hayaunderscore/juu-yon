@icon("res://assets/editor/TJA.svg")
extends Resource
class_name TJAMeta

static var _style_box_cache: Array[StyleBox] = [
	preload("uid://bjxd16dycnh1a"),
	preload("uid://bedug0hi2tv7y")
]

## The title of this chart.
@export var title: String
## The localized title of this chart, e.g. TITLEJA:title refers to JA: title
@export var title_localized: Dictionary[String, String]
## The subtitle of this chart.
@export var subtitle: String
## The creator of this chart.
@export var maker: String
## The music starting point when previewing this chart from the song select.
@export var demo_start: float = 0.0
## Base scroll multiplier.
@export var head_scroll: float = 1.0

## Box!
@export var box: bool = false
@export var box_genre: String
@export var box_back_color: Color = Color.WHITE
@export var box_fore_color: Color = Color.BLACK
@export var box_description: PackedStringArray

## This is from a box.
@export var from_box: TJAMeta

## The start bpm.
@export var start_bpm: float = 120.0
## The offset before the first note can be registered, in seconds.
@export var offset: float = 0.0
## The music of this chart.
@export var wave: AudioStream
## Music path.
@export var wave_path: String
## The path where this TJA is located.
@export var path: String
## The filename of this TJA file.
@export var file_name: String

@export var style_box: StyleBox
@export var index_box: StyleBox
@export var back: bool = false
@export var title_texture: VerticalText2D
@export var subtitle_texture: VerticalText2D
@export var box_description_texture: Array[VerticalText2D]

@export var chart_metadata: Array[Dictionary]
@export var chart_map: Dictionary[int, int]

static var font: Font = preload("uid://cmmdexdosfbag")

var header_regex: RegEx = RegEx.new()
var comment_regex: RegEx = RegEx.new()

func get_header(line: String) -> PackedStringArray:
	var matches: RegExMatch = header_regex.search(line)
	if not matches: return ["", ""]
	return [matches.get_string("header"), matches.get_string("value")]

func read_metadata_box(line: String, tja: TJAMeta):
	var header: PackedStringArray = get_header(line)
	var header_name: String = header[0].to_lower().lstrip("#")
	var header_value: String = header[1]
	match header_name:
		"title":
			tja.title = header_value
		"genre":
			# GENRE isn't used for now...
			tja.box_genre = header_value
		"backcolor":
			var clr: Color = Color.from_string(header_value, Color.WHITE)
			# Color correction- since the box is quite dark!
			# clr.r *= 1.3; clr.g *= 1.3; clr.b *= 1.3;
			tja.box_back_color = clr
		"forecolor":
			tja.box_fore_color = Color.from_string(header_value, Color.WHITE)
		_:
			if header_name.contains("title"):
				var locale: String = header_name.replace("title", "")
				tja.title_localized.set(locale, header_value)
				return
			if header_name.contains("boxexplanation"):
				var idx: int = header_name.lstrip("boxexplanation").to_int()
				if idx == 0: return
				tja.box_description.resize(idx+1)
				tja.box_description[idx] = header_value

func read_metadata(line: String, tja: TJAMeta, chart_index: int):
	var header: PackedStringArray = get_header(line)
	var header_name: String = header[0].to_lower()
	var header_value: String = header[1]
	match header_name:
		"title":
			tja.title = header_value
		"subtitle":
			tja.subtitle = header_value
		"maker":
			tja.maker = header_value
		"demostart":
			tja.demo_start = float(header_value)
		"bpm":
			tja.start_bpm = float(header_value)
		"offset":
			tja.offset = float(header_value)
		"wave":
			if header_value.is_empty():
				printerr("No music specified!")
				return
			tja.wave_path = header_value
			
		# Handle chart values
		"course", "level", "balloon", "scoremode", "scoreinit", "scorediff":
			tja.chart_metadata[chart_index][header_name.to_lower()] = header_value
			if header_name == "course":
				tja.chart_metadata[chart_index]["course_enum"] = get_level(header_value)
		_:
			if header_name.contains("title"):
				var locale: String = header_name.replace("title", "")
				tja.title_localized.set(locale, header_value)
				return
			# print("Unknown header! (%s: %s)" % [header_name, header_value])

func get_level(level: String) -> int:
	if level.is_valid_int(): return level.to_int()
	return TJAChartInfo.CourseType.get(level.to_upper(), TJAChartInfo.CourseType.ONI)

func _init() -> void:
	header_regex.compile("(?m)^[ \t]*(?<header>[^ \t:]*)[ \t]*:(?<value>.*)$")
	comment_regex.compile("(\\/\\/)(.+?)(?=[\\n\\r]|\\*\\))")

func set_style_box():
	if box:
		var sbox: StyleBoxTexture = _style_box_cache[0].duplicate() as StyleBoxTexture
		style_box = sbox
		sbox.modulate_color = box_back_color
		var fbox = _style_box_cache[1].duplicate() as StyleBoxFlat
		index_box = fbox
		var clr: Color = box_back_color
		fbox.bg_color = clr
	elif from_box:
		style_box = from_box.style_box
		index_box = from_box.index_box

static var text_texture_cache: Dictionary[String, VerticalText2D]

var _updated_text_scale: bool = false
func update_text_scale():
	_updated_text_scale = false
	if title_texture:
		title_texture.scale.y = minf(1.0, 416.0 / title_texture.get_height())
	if subtitle_texture:
		subtitle_texture.scale.y = minf(1.0, 376.0 / subtitle_texture.get_height())

func set_text():
	var t: String = title_localized.get("ja", title)
	if not text_texture_cache.has("tjametatitle_" + t):
		if not title_texture:
			title_texture = VerticalText2D.new()
		title_texture.text = t
		title_texture.font = font
		title_texture.font_size = 32
		title_texture.outline_size = 20
		title_texture.scale.y = 1.0
		title_texture._update_size()
		text_texture_cache.set("tjametatitle_" + t, title_texture)
	else:
		title_texture = text_texture_cache["tjametatitle_" + t]
		title_texture.scale.y = 1.0
		title_texture._update_size()
	t = subtitle
	if not subtitle.is_empty() and not text_texture_cache.has("tjametatitle_" + t):
		if not subtitle_texture:
			subtitle_texture = VerticalText2D.new()
		subtitle_texture.text = t.lstrip("--").lstrip("++")
		subtitle_texture.font_size = 28
		subtitle_texture.outline_size = 18
		subtitle_texture.font = font
		subtitle_texture.scale.y = 1.0
		subtitle_texture._update_size()
		text_texture_cache.set("tjametatitle_" + t, subtitle_texture)
	elif text_texture_cache.has("tjametatitle_" + t):
		subtitle_texture = text_texture_cache["tjametatitle_" + t]
		subtitle_texture.scale.y = 1.0
		subtitle_texture._update_size()
	if box:
		for i in len(box_description):
			if box_description_texture.size() <= i:
				box_description_texture.resize(i+1)
			var tex: VerticalText2D = box_description_texture[i]
			var txt: String = box_description[i]
			if txt.is_empty(): continue
			if text_texture_cache.has("tjametatitle_" + txt):
				box_description_texture[i] = text_texture_cache["tjametatitle_" + txt]
				continue
			if not tex:
				box_description_texture[i] = VerticalText2D.new()
				tex = box_description_texture[i]
			tex.text = txt
			tex.font_size = 28
			tex.font = font
			tex.font_color = Color.BLACK
			box_description_texture[i] = tex
			text_texture_cache.set("tjametatitle_" + t, tex)
	if not _updated_text_scale:
		_updated_text_scale = true
		update_text_scale.call_deferred()

static func load_from_file(npath: String) -> TJAMeta:
	var tja: TJAMeta = TJAMeta.new()
	var file: FileAccess = FileAccess.open(npath, FileAccess.READ)
	var should_read_metadata: bool = true
	var current_chart_index: int = 0
	
	tja.chart_metadata.push_back({})
	
	tja.path = npath.get_base_dir() + "/"
	tja.file_name = npath.get_file()
	
	tja.box = npath.get_extension() == "def"
	
	tja.style_box = _style_box_cache[0]
	tja.index_box = _style_box_cache[1]
	
	while file.get_position() < file.get_length():
		# Current line
		var line: String = file.get_line().strip_edges()
		# Empty?
		if line.is_empty() or line.begins_with("//"): continue
		line = tja.comment_regex.sub(line+"\n", "").strip_escapes()
		
		if line.begins_with("#START") and not tja.box:
			should_read_metadata = false
			current_chart_index += 1
			tja.chart_metadata.push_back({})
		
		if not should_read_metadata and line.begins_with("#END") and not tja.box:
			should_read_metadata = true
		
		if should_read_metadata and line:
			if tja.box:
				tja.read_metadata_box(line, tja)
			else:
				tja.read_metadata(line, tja, current_chart_index)
	
	if not tja.box:
		for i in tja.chart_metadata.size():
			if tja.chart_metadata[i].is_empty(): continue
			tja.chart_metadata[i]["cached_index"] = i
		tja.chart_metadata = tja.chart_metadata.filter(func(a: Dictionary): return not a.is_empty())
		tja.chart_metadata.sort_custom(func(a, b): return a and b and tja.get_level(a.get("course", "invalid")) < tja.get_level(b.get("course", "invalid")))
	
	file.close()
	return tja

func create_tja_from_meta() -> TJA:
	if box:
		printerr("Cannot convert a box definition into a TJA resource!")
		return
	return ResourceLoader.load(path + file_name)
