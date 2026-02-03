@icon("res://assets/editor/TJA.svg")
extends Resource
class_name TJAMeta

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

@export var chart_metadata: Array[Dictionary]
@export var chart_map: Dictionary[int, int]

var header_regex: RegEx = RegEx.new()
var comment_regex: RegEx = RegEx.new()

func get_header(line: String) -> PackedStringArray:
	var matches: RegExMatch = header_regex.search(line)
	if not matches: return ["", ""]
	return [matches.get_string("header"), matches.get_string("value")]

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

static func load_from_file(npath: String) -> TJAMeta:
	var tja: TJAMeta = TJAMeta.new()
	var file: FileAccess = FileAccess.open(npath, FileAccess.READ)
	var should_read_metadata: bool = true
	var current_chart_index: int = 0
	
	tja.chart_metadata.push_back({})
	
	tja.path = npath.get_base_dir() + "/"
	tja.file_name = npath.get_file()
	
	while file.get_position() < file.get_length():
		# Current line
		var line: String = file.get_line().strip_edges()
		# Empty?
		if line.is_empty() or line.begins_with("//"): continue
		line = tja.comment_regex.sub(line+"\n", "").strip_escapes()
		
		if line.begins_with("#START"):
			should_read_metadata = false
			current_chart_index += 1
			tja.chart_metadata.push_back({})
		
		if not should_read_metadata and line.begins_with("#END"):
			should_read_metadata = true
		
		if should_read_metadata and line:
			tja.read_metadata(line, tja, current_chart_index)
	
	for i in tja.chart_metadata.size():
		if tja.chart_metadata[i].is_empty(): continue
		tja.chart_metadata[i]["cached_index"] = i
	tja.chart_metadata = tja.chart_metadata.filter(func(a: Dictionary): return not a.is_empty())
	tja.chart_metadata.sort_custom(func(a, b): return a and b and tja.get_level(a.get("course", "invalid")) < tja.get_level(b.get("course", "invalid")))
	
	file.close()
	return tja

func create_tja_from_meta() -> TJA:
	return ResourceLoader.load(path + file_name)
