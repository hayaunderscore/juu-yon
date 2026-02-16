@tool
extends ResourceFormatLoader
## Loads [code].tja[/code] files and returns a [TJA] resource.
class_name TJAFormatLoader

#region Resource Identification
func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["tja"])

func _handles_type(type: StringName) -> bool:
	return type == "Resource"

func _get_resource_script_class(path: String) -> String:
	if path.get_extension() == "tja": return "TJA"
	return ""

func _get_resource_type(path: String) -> String:
	if path.get_extension() == "tja": return "Resource"
	return ""
#endregion
#region TJA-parser related helpers
var header_regex: RegEx = RegEx.new()
var comment_regex: RegEx = RegEx.new()
var number_regex: RegEx = RegEx.new()

func get_header(line: String) -> PackedStringArray:
	var matches: RegExMatch = header_regex.search(line)
	if not matches: return ["", ""]
	return [matches.get_string("header"), matches.get_string("value")]

func read_metadata(line: String, tja: TJA):
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
			var ext: String = header_value.get_extension()
			match ext.to_lower():
				"ogg": tja.wave = AudioStreamOggVorbis.load_from_file(tja.path + header_value)
				"mp3": tja.wave = AudioStreamMP3.load_from_file(tja.path + header_value)
				"wav": tja.wave = AudioStreamWAV.load_from_file(tja.path + header_value)
				_: printerr("Unknown music file extension! (Must be vorbis (ogg), mp3 or wav)")
		"songvol":
			tja.song_volume = header_value.to_int()
		"sevol":
			tja.se_volume = header_value.to_int()
		# Handle chart values
		"course", "level", "balloon", "scoremode", "scoreinit", "scorediff":
			tja.chart_meta[header_name.to_lower()] = header_value
		_:
			if header_name.begins_with("title"):
				var locale: String = header_name.replace("title", "")
				tja.title_localized.set(locale, header_value)
				return
			if header_name.begins_with("subtitle"):
				var locale: String = header_name.replace("subtitle", "")
				tja.subtitle_localized.set(locale, header_value)
				return
			print("Unknown header! (%s: %s)" % [header_name, header_value])

func get_level(level: String) -> int:
	if level.is_valid_int(): return level.to_int()
	return TJAChartInfo.CourseType.get(level.to_upper(), TJAChartInfo.CourseType.ONI)

func parse_complex_number(s: String) -> PackedFloat64Array:
	var t: PackedFloat64Array = [0, 0]
	var current: String = ""
	for c in s:
		if c == "+" or c == "-":
			t[0] += current.to_float()
			current = c
		elif c == "i":
			# leniency when parsing complex: 1+i or 1-i allowed
			if current == "+" or current == "-" or current == "":
				current += "1"
			t[1] += current.to_float()
			current = ""
		else:
			current += c
	if current != "":
		t[0] += current.to_float()
	return t
#endregion
#region Rendering related
# https://github.com/Yonokid/PyTaiko/blob/8164a71b451311e7a6790e68055062745fc9dc38/global_funcs.py#L134C1-L138C45
func get_pixels_per_frame(bpm, fps, time_signature, distance):
	var beat_duration = fps / bpm
	var total_time = time_signature * beat_duration
	var total_frames = fps * total_time
	return (distance / total_frames) * (fps/60)

var screen_distance: float = (640 * 1) - 148
var screen_distance_y: float = 640 - 148
#endregion
#region Beat and delay calculations
func calculate_beat_from_ms(ms: float, bpmevents: Array[Dictionary]):
	var current_beat: float = 0.0
	for i in range(0, bpmevents.size()):
		var bpmchange = bpmevents[i]
		if ms >= bpmchange["time"]:
			current_beat += bpmchange["beat_duration"]
			continue
		# Hackity hack, on my back
		if i < bpmevents.size()-2:
			current_beat += (ms - bpmchange["time"]) * bpmevents[max(0,i-1)]["beat_breakdown"]
		else:
			current_beat += (ms - bpmchange["time"]) * bpmevents[min(bpmevents.size()-1,i+1)]["beat_breakdown"]
		break
	return current_beat

func calculate_positive_delay(ms: float, events: Array[Dictionary]):
	var current_time: float = 0.0
	for i in range(0, events.size()):
		var change = events[i]
		if ms >= change["time"]:
			continue
		current_time += (ms - change["time"])
		break
	return current_time
#endregion
#region Merge sort implementation
func merge_sort(cards: Array, fun: Callable) -> Array:
	if cards.size() <= 1:
		return cards
	var mid: int = floori(cards.size() / 2.0)
	var left: Array = merge_sort(cards.slice(0, mid), fun)
	var right: Array = merge_sort(cards.slice(mid, cards.size()), fun)
	return merge(left, right, fun)

func merge(left: Array, right: Array, fun: Callable) -> Array:
	var result: Array = []
	var i: int = 0
	var j: int = 0
	while i < left.size() and j < right.size():
		if fun.call(left[i], right[j]):
			result.append(left[i])
			i += 1
		else:
			result.append(right[j])
			j += 1

	while i < left.size():
		result.append(left[i])
		i += 1

	while j < right.size():
		result.append(right[j])
		j += 1

	return result
#endregion

func _load(path: String, original_path: String, use_sub_threads: bool, cache_mode: int) -> Variant:
	print("Loading TJA file %s" % [path])
	
	# Compile regexes
	header_regex.compile("(?m)^[ \t]*(?<header>[^ \t:]*)[ \t]*:(?<value>.*)$")
	comment_regex.compile("(\\/\\/)(.+?)(?=[\\n\\r]|\\*\\))")
	number_regex.compile("((\\d|-)+)(.*)")
	
	var tja: TJA = TJA.new()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var should_read_metadata: bool = true
	tja.path = path.get_base_dir() + "/"
	
	var bpm: float = 0.0
	var time: float = 0.0
	var meter: float = 4.0 * 4.0 / 4.0
	var scroll: Vector2 = Vector2.RIGHT
	var chart: TJAChartInfo
	var flags: int = TJAChartInfo.ChartFlags.NONE
	
	var cur_note: Dictionary
	var barlines: bool = true
	var gogotime: bool = false
	
	var measures: PackedStringArray
	var notes_in_measure: int = 0
	var cont_measure: bool = false # Measure continues on beyond one line
	
	# Branch related
	var branch_start_time: float = 0.0
	var branch_start_bpm: float = 0.0
	var branch_start_meter: float = 0.0
	var branch_start_scroll: Vector2 = Vector2.ZERO
	var currently_branching: bool = false
	var current_note_data: Array
	var current_barline_data: Array
	var current_balloon_data: PackedFloat64Array = PackedFloat64Array()
	
	while file.get_position() < file.get_length():
		# Current line
		var line: String = file.get_line().strip_edges()
		# Empty?
		if line.is_empty() or line.begins_with("//"): continue
		line = comment_regex.sub(line+"\n", "", true).strip_escapes().strip_edges()
		
		var add_bpm_change: Callable = func(added_time: float, added_bpm: float, current_chart: TJAChartInfo):
			if current_chart.bpm_log.size() > 0:
				var last_bpm_change: Dictionary = current_chart.bpm_log[current_chart.bpm_log.size()-1]
				last_bpm_change["duration"] = (added_time) - last_bpm_change["time"]
				last_bpm_change["beat_duration"] = (last_bpm_change["bpm"] / 60) * last_bpm_change["duration"]
			# print("uhhh beat duration ", last_bpm_change["duration"], " and in beats ", last_bpm_change["beat_duration"])
			current_chart.command_log.append({
				"time": added_time, 
				"com": TJAChartInfo.CommandType.BPMCHANGE, 
				"val1": added_bpm
			})
			current_chart.bpm_log.append({
				"time": added_time,
				"bpm": added_bpm,
				"duration": 0,
				"beat_duration": 0,
				"beat_breakdown": (added_bpm / 60)
			})
		
		var add_positive_delay: Callable = func(added_time: float, added_delay: float, current_chart: TJAChartInfo):
			if current_chart.positive_delay_log.size() > 0:
				var last_bpm_change: Dictionary = current_chart.positive_delay_log[current_chart.positive_delay_log.size()-1]
				last_bpm_change["duration"] = (added_time) - last_bpm_change["time"]
			# print("uhhh beat duration ", last_bpm_change["duration"], " and in beats ", last_bpm_change["beat_duration"])
			current_chart.positive_delay_log.append({
				"time": added_time,
				"delay": added_delay,
				"duration": 0,
			})
		
		# Handle gimmick modes
		# TODO make this a command instead
		if line.begins_with("#BMSCROLL"):
			flags |= TJAChartInfo.ChartFlags.BMSCROLL
		if line.begins_with("#HBSCROLL"):
			flags |= TJAChartInfo.ChartFlags.HBSCROLL
		
		# Read metadata
		if should_read_metadata:
			if line.begins_with("#START"):
				should_read_metadata = false
				# Set bpm and other stuff back to the start
				bpm = tja.start_bpm
				time = -tja.offset
				scroll.x = tja.head_scroll
				scroll.y = 0
				# Create a new chart
				chart = TJAChartInfo.new()
				# And set parameters
				chart.course = get_level(tja.chart_meta.get("course", "oni")) as TJAChartInfo.CourseType
				chart.level = (tja.chart_meta.get("level", "1") as String).to_int()
				var balloons: PackedStringArray = (tja.chart_meta.get("balloon", "") as String).split(",")
				for s in balloons:
					chart.balloons.push_back(s.to_float())
				# chart.balloons = (tja.chart_meta.get("balloon", "") as String).split_floats(",")
				var init: PackedFloat64Array = (tja.chart_meta.get("scoreinit", "300,1000") as String).split_floats(",", false)
				if init.size() >= 1:
					chart.scoreinit[0] = floor(init[0])
				if init.size() == 2:
					chart.scoreinit[1] = floor(init[1])
				chart.scorediff = (tja.chart_meta.get("scorediff", "") as String).to_int()
				chart.scoremode = (tja.chart_meta.get("scoremode", "") as String).to_int()
				current_note_data = chart.notes
				current_barline_data = chart.barline_data
				current_balloon_data = chart.balloons
				# Add dummy bpm changes to base next bpm changes
				add_bpm_change.call(time, bpm, chart)
				add_positive_delay.call(time, 0, chart)
			else:
				read_metadata(line, tja)
			continue
		
		# Chart has ended, read metadata again
		if line.begins_with("#END"):
			should_read_metadata = true
			# Implicit #BRANCHEND
			if currently_branching:
				currently_branching = false
				current_note_data = chart.notes
				current_barline_data = chart.barline_data
			# More bpm and delay stuff
			add_bpm_change.call(time, bpm, chart)
			add_bpm_change.call(tja.wave.get_length(), bpm, chart)
			add_positive_delay.call(time, 0, chart)
			add_positive_delay.call(tja.wave.get_length(), 0, chart)
			# Calculate beat positions
			for note in chart.notes:
				note["beat_position"] = calculate_beat_from_ms(note["time"], chart.bpm_log)
			for note in chart.barline_data:
				note["beat_position"] = calculate_beat_from_ms(note["time"], chart.bpm_log)
			for i in range(chart.branch_notes.size()):
				var note_data: Array = chart.branch_notes[i]
				for note in note_data:
					note["beat_position"] = calculate_beat_from_ms(note["time"], chart.bpm_log)
				var barline_data: Array = chart.branch_barlines[i]
				for note in barline_data:
					note["beat_position"] = calculate_beat_from_ms(note["time"], chart.bpm_log)
			# Sort all notes by time
			var sorted: Array[Dictionary] = chart.notes.duplicate(true)
			for i in range(0, sorted.size()):
				chart.notes[i]["cached_index"] = i
				chart.draw_data[i] = sorted[i]
			for i in range(chart.branch_notes.size()):
				var note_data: Array = chart.branch_notes[i]
				var sorted_data = note_data.duplicate(true)
				for j in range(0, sorted_data.size()):
					note_data[j]["cached_index"] = j
					chart.branch_drawdata[i][j] = sorted_data[j]
			# Filter out dummy notes from any time
			chart.notes = chart.notes.filter(func(a): return not a.has("dummy"))
			var s: Array = merge_sort(chart.notes, func(a, b): a["time"] < b["time"])
			chart.notes.assign(s)
			for i in range(chart.branch_notes.size()):
				var note_data: Array = chart.branch_notes[i]
				note_data = note_data.filter(func(a): return not a.has("dummy"))
				note_data = merge_sort(note_data, func(a, b): a["time"] < b["time"])
				chart.branch_notes[i] = note_data
			chart.flags = flags
			flags = 0
			tja.charts.push_back(chart)
		
		if line.is_empty(): continue
		
		# Add a barline.
		# This is early to account for scroll specific issues ffs
		if barlines and not line.begins_with("#") and not cont_measure:
			current_barline_data.append({"time": time, "scroll": scroll, "bpm": bpm, "meter": meter, "note": TJAChartInfo.NoteType.BARLINE})
		
		# Handle measures.
		measures.append(line)
		var nline: String = ""
		var lpos: int = file.get_position()
		# Continue in next line until we hit a measure terminator
		if not line.ends_with(",") and not line.begins_with("#") and not cont_measure:
			notes_in_measure += line.strip_edges().trim_suffix(",").length()
			cont_measure = true
			while not nline.ends_with(",") and file.get_position() < file.get_length():
				nline = file.get_line().strip_edges()
				nline = comment_regex.sub(nline+"\n", "", true).strip_edges().strip_escapes()
				if not nline.begins_with("#"):
					notes_in_measure += nline.trim_suffix(",").length()
			# print("done! seek back to... ", lpos, " from ", file.get_position())
			file.seek(lpos)
		elif line.ends_with(",") and not cont_measure:
			# print("at: " + str(file.get_position()) + ", seek measure....")
			notes_in_measure += line.trim_suffix(",").length()
		# -1 means nothing lol
		if line.begins_with("#") and not cont_measure:
			# print("reset measure length")
			notes_in_measure = -1
		if line.ends_with(","):
			cont_measure = false
		
		# Handle commands and note addition.
		for l in measures:
			# Commands
			if l.begins_with("#"):
				var args: PackedStringArray = l.replace("#", "").to_lower().split(" ", false, 1)
				if args.size() == 0: continue
				var command_name: String = args[0]
				var command_value: String = args[1] if args.size() > 1 else ""
				# This jit cracks numbers
				# Some old charts tend to not add a space between commands which is ANNOYING
				var s: RegExMatch = number_regex.search(command_name)
				if s:
					var matc: String = s.get_string()
					command_name = command_name.replace(matc, "")
					command_value = matc
				match command_name:
					# #GOGOTIME and #GOGOEND
					"gogostart":
						gogotime = true
						chart.command_log.append({"time": time, "com": TJAChartInfo.CommandType.GOGOSTART})
					"gogoend":
						gogotime = false
						chart.command_log.append({"time": time, "com": TJAChartInfo.CommandType.GOGOEND})
					# #BARLINEON and #BARLINEOFF
					"barlineon":
						barlines = true
					"barlineoff":
						barlines = false
					# #BPMCHANGE <float-value>
					"bpmchange":
						if command_value.is_valid_float():
							bpm = command_value.to_float()
							add_bpm_change.call(time, bpm, chart)
					# #DELAY <float-value>
					"delay":
						if not command_value.is_valid_float(): continue
						var delay: float = command_value.to_float()
						if delay > 0:
							add_bpm_change.call(time, 0, chart)
						time += delay
						if delay > 0:
							add_bpm_change.call(time, bpm, chart)
							add_positive_delay.call(time, delay, chart)
						chart.command_log.append({"time": time, "com": TJAChartInfo.CommandType.DELAY, "val1": command_value})
					# #MEASURE <float-value>/<float-value>
					"measure":
						var line_data: PackedFloat64Array = command_value.split_floats("/")
						if line_data.size() < 2: continue
						meter = (4.0 * line_data[0]) / line_data[1]
						chart.command_log.append({"time": time, "com": TJAChartInfo.CommandType.MEASURE, "val1": meter})
					"scroll":
						if command_value.is_empty(): continue
						if flags & TJAChartInfo.ChartFlags.BMSCROLL: continue
						if not command_value.contains("i"):
							scroll = Vector2.RIGHT * command_value.to_float()
						else:
							var numbers: PackedFloat64Array = parse_complex_number(command_value)
							scroll = Vector2(numbers[0], numbers[1])
						chart.command_log.append({"time": time, "com": TJAChartInfo.CommandType.SCROLL, "val1": scroll})
					"branchstart":
						var comargs: PackedStringArray = command_value.split(",")
						if comargs.size() < 3:
							print("#BRANCHSTART requires 3 arguments! Ignoring...")
							continue
						
						branch_start_bpm = bpm
						branch_start_meter = meter
						branch_start_scroll = scroll
						branch_start_time = time
						currently_branching = true
						
						flags |= TJAChartInfo.ChartFlags.BRANCHFUL
						
						var cond: int = TJAChartInfo.BranchCondition.get(comargs[0], "r")
						var expert_req: int = comargs[1].to_int()
						var master_req: int = comargs[2].to_int()
						chart.command_log.append({"time": time, "com": TJAChartInfo.CommandType.BRANCHSTART, "branch_cond": cond, "expert_req": expert_req, "master_req": master_req})
					"branchend":
						if not currently_branching:
							print("Invalid #BRANCHEND (No branch found for this branch!)")
							continue
						currently_branching = false
						current_note_data = chart.notes
						current_barline_data = chart.barline_data
					"n":
						if not currently_branching:
							print("Invalid #N (No branch found for this path!)")
							continue
						bpm = branch_start_bpm
						meter = branch_start_meter
						scroll = branch_start_scroll
						time = branch_start_time
						current_note_data = chart.branch_notes[TJAChartInfo.BranchType.NORMAL]
						current_barline_data = chart.branch_barlines[TJAChartInfo.BranchType.NORMAL]
					"e":
						if not currently_branching:
							print("Invalid #E (No branch found for this path!)")
							continue
						bpm = branch_start_bpm
						meter = branch_start_meter
						scroll = branch_start_scroll
						time = branch_start_time
						current_note_data = chart.branch_notes[TJAChartInfo.BranchType.EXPERT]
						current_barline_data = chart.branch_barlines[TJAChartInfo.BranchType.EXPERT]
					"m":
						if not currently_branching:
							print("Invalid #M (No branch found for this path!)")
							continue
						bpm = branch_start_bpm
						meter = branch_start_meter
						scroll = branch_start_scroll
						time = branch_start_time
						# TODO Branches.
						# Branches are easily the hardest part of making a simulator
						# And even more so with how I set up the notes and draw data
						# For now, force everything to master branch
						#current_note_data = chart.branch_notes[TJAChartInfo.BranchType.MASTER]
						#current_barline_data = chart.branch_barlines[TJAChartInfo.BranchType.MASTER]
						current_note_data = chart.notes
						current_barline_data = chart.barline_data
					
				continue
			# Notes
			for idx in l.trim_suffix(","):
				if idx == "/": break
				var n: int = idx.to_int()
				if n > 0:
					if n == 9: n = 7
					var no: Dictionary = {
						"note": n,
						"time": floor(time * 1000) / 1000,
						"bpm": bpm,
						"meter": meter,
						"scroll": scroll,
						"roll_note": null,
						"roll_time": 0.0,
						"roll_loadms": Vector2(-INF, -INF),
						"balloon_value": 0,
						"gogotime": gogotime
					}
					var last_note: Dictionary = {}
					if n == 8: # Handle
						var rnoteidx: int = current_note_data.find(cur_note)
						current_note_data[rnoteidx].get_or_add("roll_time", time)
						current_note_data[rnoteidx]["roll_color_mod"] = Color.WHITE
						cur_note["roll_tail"] = current_note_data.size()
						last_note = current_note_data[rnoteidx]
					# Set current note
					cur_note = no
					if n == 8:
						cur_note["roll_note"] = last_note
						cur_note["roll_note_type"] = last_note["note"]
						cur_note["roll_color_mod"] = Color.WHITE
					current_note_data.append(cur_note)
				time += 60.0 * (meter / notes_in_measure) / bpm
		
		if notes_in_measure == 0:
			time += 60 * meter / bpm
		
		measures.clear()
		if line.ends_with(",") or (line.begins_with("#") and not cont_measure):
			notes_in_measure = 0
	
	print("We are done!")
	file.close()
	return tja
