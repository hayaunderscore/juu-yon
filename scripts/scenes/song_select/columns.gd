@tool
extends Control

@export var padding: float = 24
@export var timer: Timer
@export var music: AudioStreamPlayer
@export var voice: AudioStreamPlayer
@export var background: Sprite2D
@export var header_text: TaikoText
@export var genre_text: TaikoText
@export var anim: AnimationPlayer

@onready var song_box: StyleBoxTexture = preload("res://assets/songselect/song_box.tres")
@onready var song_box_small: StyleBoxTexture = preload("res://assets/songselect/song_box_small.tres")
@onready var folder_box: StyleBoxTexture = preload("res://assets/songselect/song_box.tres")
@onready var box_selected: StyleBoxTexture = preload("res://assets/songselect/box_selected.tres")
@onready var font: Font = preload("uid://cpafoyo5od38s")
@onready var index_font: Font = preload("uid://cd45agtyt8161")
@onready var box_index: StyleBoxFlat = preload("uid://bedug0hi2tv7y")
@onready var box_difficulty: StyleBox = preload("uid://d2bbohpu08pon")
@onready var star_tex: Texture2D = preload("uid://diije4rcsic5f")
@onready var box_highlight: StyleBox = preload("uid://bkaa0v40ceirc")

@onready var cursors: Array[Texture2D] = [
	preload("uid://b57gmo6jjosyi")
]

var voice_lines: Dictionary[String, AudioStream]

@onready var difficulty_icons: Dictionary[int, Texture2D] = {
	-1: preload("uid://cexj018sv5j55"),
	0: preload("uid://15kqjjs1ycyb"),
	1: preload("uid://do2s2dpehwixs"),
	2: preload("uid://cybdg5l5gvukn"),
	3: preload("uid://db4dvb22tbyhi"),
	4: preload("uid://cho4uhsh8blcq")
}

enum State {
	SONG_SELECT,
	SONG_TO_DIFF,
	DIFF_SELECT,
	DIFF_TO_SONG,
}
var state: State = State.SONG_SELECT

var songs: Array[TJAMeta]
var selected_index: int = 0
var box_transition: float = 0
var box_out: bool = false
var entry_retransition: bool = false
var box_side_transition: float = 0
var entry_transition: float = 0

var can_choose: bool = false:
	set(value):
		if value == can_choose: return
		can_choose = value
		if Globals and Globals.control_banner:
			if value:
				Globals.control_banner.activate()
			else:
				Globals.control_banner.deactivate()

signal _box_done

var box_width: float = 96
var box_open_size: float = 480
var box_diff_select_size: float = 768

func play_voice_line(voice_line: String):
	voice.stop()
	voice.stream = voice_lines[voice_line]
	voice.play()

var box_stack: Array[TJAMeta]
var box_prev_positions: PackedInt64Array
var deep: int = 0
var prev_box: TJAMeta
var pref_box: TJAMeta

func find_tjas(path: String, skip_box: bool = false):
	var dir: DirAccess = DirAccess.open(path)
	if dir:
		if dir.file_exists("box.def") and not skip_box:
			var box: TJAMeta = TJAMeta.load_from_file(path + "box.def")
			box.set_style_box()
			box.set_text()
			songs.push_back(box)
			Globals.log("COLUMNS", "Found box definition for folder %s" % [path])
			return
		var files: PackedStringArray = dir.get_directories()
		files.append_array(dir.get_files())
		for file in files:
			if dir.dir_exists(file):
				var npath: String = path + file + "/"
				find_tjas(npath)
				continue
			if file.get_extension() == "tja":
				var tja: TJAMeta = TJAMeta.load_from_file(path + file)
				tja.set_text()
				if pref_box:
					tja.from_box = pref_box
					tja.set_style_box()
				Globals.log("COLUMNS", "Found song definition with filename %s" % [file])
				songs.push_back(tja)

func _exit_tree() -> void:
	Globals.control_banner.don_pressed.disconnect(don_pressed)
	Globals.control_banner.kat_pressed.disconnect(kat_pressed)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_editor_hint(): return
	Globals.control_banner.deactivate()
	Globals.control_banner.activate_side()
	Globals.control_banner.don_pressed.connect(don_pressed)
	Globals.control_banner.kat_pressed.connect(kat_pressed)
	for bvoice in ResourceLoader.list_directory("res://assets/snd/songselect/"):
		voice_lines.set(bvoice.replace("voice_", "").get_basename(), load("res://assets/snd/songselect/" + bvoice))
	find_tjas(Configuration.get_section_key("game", "song_folder"))
	
	if songs.size() == 0:
		OS.alert("No songs found!\nPlease check your song folder.")
		get_tree().quit()
		return
	
	if songs[0].box and songs[0].box_back_color:
		background.modulate = songs[0].box_back_color
	
	queue_redraw()
	
	timer.timeout.connect(start_music)
	play_voice_line("enter")
	await get_tree().create_timer(0.9).timeout
	
	can_choose = true
	Globals.control_banner.activate()
	timer.start()

func start_music():
	if Engine.is_editor_hint(): return
	var song: TJAMeta = songs[selected_index]
	if song.box: return
	if !song.wave and song.wave_path:
		var header_value: String = song.wave_path
		var ext: String = header_value.get_extension()
		match ext.to_lower():
			"ogg": song.wave = AudioStreamOggVorbis.load_from_file(song.path + header_value)
			"mp3": song.wave = AudioStreamMP3.load_from_file(song.path + header_value)
			"wav": song.wave = AudioStreamWAV.load_from_file(song.path + header_value)
			_: printerr("Unknown music file extension! (Must be vorbis (ogg), mp3 or wav)")
		Globals.log("COLUMNS", "Loaded music file for %s" % [song.title])
	music.stream = song.wave
	music.play(song.demo_start)

func select_song():
	Globals.control_banner.deactivate_side()
	play_voice_line("start_song_1p")
	var song: TJAMeta = songs[selected_index]
	await get_tree().create_timer(0.7).timeout
	SongLoadHandler.select_song(song, selected_diff)

var selected: bool = false
var smoothed_selected_index: float = 0
var last_selected_index: int = 0

var target_box_size: float = box_open_size
var target_prev_box_size: float = box_width

func move_cursor(s: int = 1):
	music.stop()
	if box_transition > 0:
		box_transition = minf(box_transition, 1.0)
		box_out = true
		Globals.control_banner.deactivate()
		await _box_done
		Globals.control_banner.activate()
	
	box_transition = 0
	selected_index = wrapi(selected_index + s, 0, songs.size())
	# First to last
	if last_selected_index == 0 and (selected_index == songs.size() - 1):
		smoothed_selected_index = songs.size()
	# Last to first
	if selected_index == 0 and (last_selected_index == songs.size() - 1):
		smoothed_selected_index = -1
	timer.start()

var song_select_cursor: int = 0
var ss_cursor_offset_y: float = 0
var selected_chart: Array[Dictionary]
var selected_diff: int = 0
var stupid_fucking_alpha_hack_i_will_remove_someday: bool = false

func song_select_move_cursor(s: int = 1):
	ss_cursor_offset_y = 4
	song_select_cursor = wrapi(song_select_cursor + s, 0, 1 + selected_chart.size())
	selected_diff = song_select_cursor - 1

func box_select():
	Globals.control_banner.deactivate_side()
	state = State.SONG_TO_DIFF
	box_transition = 1.0
	box_side_transition = 0.0
	entry_transition = 3.0
	entry_retransition = true
	can_choose = false
	await get_tree().create_timer(1).timeout
	
	var box: TJAMeta = songs[selected_index].duplicate()
	if box.back and box_stack.size() > 0:
		box_stack.pop_back()
		
		if box_stack.size() == 0:
			# Annoying fix
			box.path = Configuration.get_section_key("game", "song_folder")
	
	var back: TJAMeta = TJAMeta.new()
	var prev: TJAMeta = box_stack.back() if box_stack.size() > 0 else null
	back.title = "Back"
	back.box_back_color = Color.CHOCOLATE
	back.box = true
	back.set_style_box()
	back.set_text()
	back.back = true
	back.from_box = prev if box.back else box
	back.path = prev.path if prev and prev.box else Configuration.get_section_key("game", "song_folder")
	
	songs.clear()
	if box.path != Configuration.get_section_key("game", "song_folder"):
		songs.push_back(back)
		
	pref_box = box
	if box.back:
		pref_box = prev
	find_tjas(box.path, true)
	pref_box = null
	entry_retransition = false
	entry_transition = 0
	box_transition = 0
	state = State.SONG_SELECT
	
	if not box.back:
		box_stack.push_back(box)
		box_prev_positions.push_back(selected_index)
		selected_index = 0
		smoothed_selected_index = 0
	else:
		var idx: int = box_prev_positions[-1]
		selected_index = idx
		smoothed_selected_index = idx
		box_prev_positions.remove_at(box_prev_positions.size() - 1)
	
	await get_tree().create_timer(0.3).timeout
	
	can_choose = true
	Globals.control_banner.activate_side()
	timer.start()

func song_select_to_diff_select():
	Globals.control_banner.deactivate()
	Globals.control_banner.deactivate_side()
	state = State.SONG_TO_DIFF
	box_transition = 1.0
	box_side_transition = 0.0
	await get_tree().create_timer(0.75).timeout
	box_transition = 0
	state = State.DIFF_SELECT
	target_prev_box_size = box_open_size
	target_box_size = box_diff_select_size
	selected_chart = songs[selected_index].chart_metadata
	await get_tree().create_timer(0.25).timeout
	play_voice_line("select_diff")
	Globals.control_banner.activate()
	Globals.control_banner.activate_side()

func diff_select_to_song_select():
	Globals.control_banner.deactivate()
	Globals.control_banner.deactivate_side()
	state = State.DIFF_TO_SONG
	box_transition = 1.0
	target_prev_box_size = box_open_size
	target_box_size = box_diff_select_size
	stupid_fucking_alpha_hack_i_will_remove_someday = true
	box_side_transition = 1.0
	box_out = true
	await _box_done
	state = State.SONG_SELECT
	box_transition = 1.5
	target_box_size = box_open_size
	target_prev_box_size = box_width
	stupid_fucking_alpha_hack_i_will_remove_someday = false
	Globals.control_banner.activate()
	Globals.control_banner.activate_side()

func don_pressed(_id):
	if songs[selected_index].box:
		box_select()
		return
	if state == State.SONG_SELECT:
		# SoundHandler.play_sound("dong.wav")
		song_select_to_diff_select()
	elif state == State.DIFF_SELECT and song_select_cursor == 0 and box_transition >= 1.0:
		SoundHandler.play_sound("cancel.wav")
		diff_select_to_song_select()
	elif state == State.DIFF_SELECT and box_transition >= 1.0:
		# SoundHandler.play_sound("dong.wav")
		selected = true
		music.stop()
		Globals.control_banner.deactivate()
		select_song()

func kat_pressed(_id, side):
	if state == State.SONG_SELECT:
		move_cursor(side)
	elif state == State.DIFF_SELECT:
		song_select_move_cursor(side)

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	
	var song: TJAMeta = songs[selected_index]
	
	if target_box_size == box_open_size:
		target_box_size = 480 if not song.box else 256
	box_open_size = 480 if not song.box else 256
	queue_redraw()
	
	var back_color: Color = song.box_back_color
	var header_color: Color = song.index_box.bg_color
	if song.back or song.from_box: 
		back_color = song.from_box.box_back_color
		header_color = song.from_box.index_box.bg_color

	background.modulate = lerp(background.modulate, back_color, delta*6)
	header_text.first_outline_color = header_color
	header_text.first_outline_color.a = 1.0
	genre_text.first_outline_color = header_text.first_outline_color
	if song.box and not song.back:
		genre_text.text = song.title_localized.get("ja", song.title)
	
	if entry_retransition:
		entry_transition -= delta*3
	else:
		entry_transition += delta*3
	# entry_transition = minf(1.0, entry_transition)
	
	if not can_choose: 
		return
	
	ss_cursor_offset_y = move_toward(ss_cursor_offset_y, 0, delta*24)
	
	if music.playing or state > State.SONG_SELECT or (songs[selected_index].box and timer.is_stopped()): 
		box_transition += delta*(6 if song.box else 3)
	
	if state == State.SONG_TO_DIFF and not songs[selected_index].box:
		box_side_transition += delta * 2
	if state == State.SONG_SELECT:
		box_side_transition -= delta * 2
		box_side_transition = maxf(0.0, box_side_transition)
	
	smoothed_selected_index = move_toward(smoothed_selected_index, selected_index, delta*10)
		# smoothed_selected_index = move_toward(smoothed_selected_index, selected_index, delta*8)
	
	if selected: 
		return
	if box_out: 
		var speed: float = 6 if not songs[selected_index].box else 16
		box_transition -= delta*speed
		if box_transition <= 0:
			box_transition = 0
			box_out = false
			_box_done.emit()
		return
		
	last_selected_index = selected_index

func ease_out_back(x: float):
	const c1 := 1.70158
	const c3 := c1 + 1
	
	return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)

func _draw() -> void:
	if songs.size() == 0: return
	
	var x: float = 0
	var bwidth: float = minf(target_box_size, lerpf(target_prev_box_size, target_box_size, box_transition))
	x = (get_viewport_rect().size.x / 2.0) - (bwidth / 2.0) - ((box_width + padding) * smoothed_selected_index) - ((5 - selected_index) * (box_width + padding))
	
	var trans: float = box_transition
	draw_set_transform(Vector2.RIGHT * x)
	var min_size: int = selected_index - 5
	var max_size: int = selected_index + 6
	for i in range(min_size, max_size):
		var wrapped_i: int = wrapi(i, 0, songs.size())
		var song: TJAMeta = songs[wrapped_i]
		var box_ofs: float = lerpf(0, -480 if i < selected_index else 480, maxf(0.0, box_side_transition))
		if i == selected_index: box_ofs = 0
		
		trans = box_transition
		
		var bsize: Vector2 = Vector2(box_width, 472)
		if box_side_transition >= 1.0 and i != selected_index:
			x += padding + bsize.x
			continue
		
		var right: Vector2 = Vector2.RIGHT
		if entry_transition < 16:
			right.y = lerpf(480, 0, ease_out_back(minf(1.0, (entry_transition) - ((i - selected_index) / 4.0 + 1.25))))
		if state >= State.DIFF_SELECT:
			var t_ofs: float = 0.0
			if state == State.DIFF_SELECT:
				t_ofs = 1.0
			bsize.y = lerpf(472, 472 + 32, minf(1.0, maxf(0.0, box_transition - t_ofs)))
			# print(bsize.y)
			right.y = 472 - bsize.y
		
		var offset_x: Callable = func(new_x: float):
			return Vector2(right.x + new_x, right.y)
		
		# Main box
		draw_set_transform(offset_x.call(x + box_ofs))
		var box: StyleBox = song.style_box
		if i == selected_index: bsize.x = minf(target_box_size, lerpf(target_prev_box_size, target_box_size, trans))
		draw_style_box(box, Rect2(Vector2.ZERO, bsize + (23*Vector2.ONE)))
		if i == selected_index:
			draw_style_box(box_selected, Rect2(Vector2.ZERO, bsize))
		else:
			draw_style_box(box_highlight, Rect2(Vector2.ZERO, bsize))
		
		if state > State.SONG_SELECT or stupid_fucking_alpha_hack_i_will_remove_someday:
			trans = 1.0
		
		# Song index
		box = song.index_box
		bsize.y = 30
		var alpha: float = 1.0 - minf(1.0, box_side_transition)
		if state == State.DIFF_SELECT:
			alpha = 0
		box.bg_color.a = alpha
		draw_style_box(box, Rect2(Vector2(0, -bsize.y), bsize))
		var count_str: String = "%d" % [wrapped_i + 1]
		var str_width: float = font.get_string_size(count_str, HORIZONTAL_ALIGNMENT_CENTER).x
		draw_string(font, Vector2((bsize.x / 2.0) - (str_width / 2.0), -bsize.y + 24), count_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(1, 1, 1, alpha))
		
		if state >= State.DIFF_SELECT and i == selected_index:
			var clr: Color = Color.WHITE
			clr.a = minf(1.0, lerpf(0.0, 1.0, maxf(0.0, box_transition - 1.0)))
			draw_set_transform(offset_x.call((x + box_ofs) + 32))
			if song_select_cursor == 0:
				# TODO p2 cursor
				var cursor: Texture2D = cursors[0]
				draw_texture(cursor, Vector2(48 - (cursor.get_width() / 2.0), 24 + ss_cursor_offset_y), clr)
			song_box_small.modulate_color.a = clr.a
			draw_style_box(song_box_small, Rect2(Vector2(24, 64), Vector2(48, 240)))
			var bl: Color = Color.BLACK
			bl.a = clr.a
			draw_string(font, Vector2(48, 80), "Back", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, bl, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_VERTICAL)
		
		# Difficulties
		if i == selected_index and not song.box:
			var base_padding: float = 24
			if state >= State.DIFF_SELECT or stupid_fucking_alpha_hack_i_will_remove_someday:
				base_padding = lerpf(24, 96, minf(1.0, box_transition))
			var diff_width: float = (24*2 + base_padding) * song.chart_metadata.size()
			var diff_padding: float = (288 / diff_width) * base_padding
			var diff_x: float = x + diff_padding*2
			if state >= State.DIFF_SELECT or stupid_fucking_alpha_hack_i_will_remove_someday:
				diff_x += (bsize.x - box_open_size) / 2.0
			const diff_height: float = 372
			var diff_trans: float = trans
			if state == State.SONG_SELECT:
				diff_trans = trans - 0.5
			for k in range(song.chart_metadata.size()):
				var chart: Dictionary = song.chart_metadata[k]
				# if not chart: continue
				draw_set_transform(offset_x.call(diff_x))
				(box_difficulty as StyleBoxFlat).bg_color.a = minf(1, diff_trans)
				draw_style_box(box_difficulty, Rect2(Vector2(0, 64), Vector2(24*2, diff_height)))
				
				# Difficulty icon
				var diff: int = chart.get("course_enum", -1)
				var star_star_clr: Color = Color.WHITE
				star_star_clr.a = minf(1, diff_trans)
				
				if difficulty_icons.has(diff):
					var icon: Texture2D = difficulty_icons[diff]
					draw_texture(icon, Vector2(24, 46) - icon.get_size() / 2, star_star_clr)
				
				if (song_select_cursor - 1) == k:
					var cursor: Texture2D = cursors[0]
					draw_texture(cursor, Vector2(24, 20 + ss_cursor_offset_y) - cursor.get_size() / 2)
				
				# Difficulty stars
				var max_stars: int = 0
				match diff:
					TJAChartInfo.CourseType.EASY:
						max_stars = 5
					TJAChartInfo.CourseType.NORMAL:
						max_stars = 7
					TJAChartInfo.CourseType.HARD:
						max_stars = 8
					TJAChartInfo.CourseType.ONI:
						max_stars = 10
					TJAChartInfo.CourseType.EDIT:
						max_stars = 15
				var star_y: float = diff_height + 64 - 24 - 9
				var star_clr: Color = Color.from_string("#E77627", Color.WHITE)
				star_clr.a = minf(1, diff_trans)
				var level: int = chart.get("level", "0").to_int()
				for j in range(maxi(max_stars, chart.get("level", "0").to_int())):
					if j <= max_stars:
						draw_circle(Vector2(24, star_y + 3), 4, star_clr)
					if j < level:
						draw_texture(star_tex, Vector2(15, star_y - 8), star_star_clr)
					star_y -= 20

				# Funny text
				var diff_name: String = (TJAChartInfo.CourseType.find_key(chart.get("course_enum", -1))).to_pascal_case()
				var clr: Color = Color.BLACK
				clr.a = minf(1, diff_trans)
				draw_string(font, Vector2(24, 78), diff_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, clr, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_VERTICAL)
				
				diff_x += diff_padding + 24*2
		
		# Song title
		var y: float = right.y + 24
		if state >= State.DIFF_SELECT:
			var t_ofs: float = 0.0
			if state == State.DIFF_SELECT:
				t_ofs = 1.0
			y = lerpf(24, 0, minf(1.0, maxf(0.0, box_transition - t_ofs)))
		var height: float = 0 if not song.title_texture else song.title_texture.get_height()
		var x_ofs: float = 48 + (bsize.x - box_width)
		if song.box and i == selected_index:
			x_ofs -= lerp(0, 28, minf(1.0, box_transition))
		var outline_color: Color = Color.BLACK
		if not song.back and song.from_box:
			outline_color = song.from_box.box_fore_color
		if song.box and not song.back:
			outline_color = song.box_fore_color
		if i == selected_index:
			outline_color = Color.BLACK
		if song.title_texture:
			song.title_texture.outline_color = outline_color
			draw_texture(song.title_texture, Vector2((x + box_ofs) + x_ofs - (song.title_texture.get_width() / 2), y))
		
		# Boxes may have descriptions
		if song.box and i == selected_index and song.title_texture:
			x_ofs -= song.title_texture.get_width() + 14
			for j in len(song.box_description):
				var ccolor: Color = Color.WHITE
				ccolor.a = minf(1, trans)
				if state == State.SONG_SELECT:
					ccolor.a = minf(1, trans - 1)
				# draw_set_transform(Vector2((x + box_ofs) + x_ofs, y), 0.0, Vector2(1.0, font_v_scale))
				if song.box_description_texture[j]:
					var w: int = song.box_description_texture[j].get_width()
					draw_texture(song.box_description_texture[j], Vector2((x + box_ofs) + x_ofs - w / 2, y), ccolor)
					x_ofs -= 32
		
		# Subtitle if applicable
		var subtitle: String = song.subtitle_localized.get("ja", song.subtitle).lstrip("--")
		if subtitle.is_empty() or i != selected_index or not song.subtitle_texture:
			x += padding + bsize.x
			continue
		x_ofs -= song.title_texture.get_width() + 16
		height = song.subtitle_texture.get_height()
		y += 48
		var subtitle_color: Color = Color.WHITE
		outline_color.a = minf(1, trans)
		subtitle_color.a = minf(1, trans)
		# song.subtitle_texture.scale.y = font_v_scale
		# draw_set_transform(Vector2((x + box_ofs) + x_ofs, y), 0.0, Vector2(1.0, font_v_scale))
		draw_texture(song.subtitle_texture, Vector2((x + box_ofs) + x_ofs - (song.subtitle_texture.get_width() / 2), y), subtitle_color)
		#draw_string_outline(font, Vector2.ZERO, subtitle, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 18, outline_color, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_VERTICAL)
		#draw_string(font, Vector2.ZERO, subtitle, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, subtitle_color, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_VERTICAL)
		x += padding + bsize.x
