@tool
extends Control

@export var padding: float = 32
@export var timer: Timer
@export var music: AudioStreamPlayer
@export var voice: AudioStreamPlayer
@export var visual_taiko: SelectTaiko
var visual_taiko_position: Vector2
@export var anim: AnimationPlayer

@onready var song_box: StyleBoxTexture = preload("res://assets/songselect/song_box.tres")
@onready var song_box_small: StyleBoxTexture = preload("res://assets/songselect/song_box_small.tres")
@onready var folder_box: StyleBoxTexture = preload("res://assets/songselect/song_box.tres")
@onready var box_selected: StyleBoxTexture = preload("res://assets/songselect/box_selected.tres")
@onready var font: Font = preload("res://assets/fonts/Modified-DFPKanteiryu-XB.ttf")
@onready var index_font: Font = preload("uid://cd45agtyt8161")
@onready var box_index: StyleBoxFlat = preload("uid://bedug0hi2tv7y")
@onready var box_difficulty: StyleBox = preload("uid://d2bbohpu08pon")
@onready var star_tex: Texture2D = preload("uid://diije4rcsic5f")

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
var box_side_transition: float = 0
var entry_transition: float = 0

var can_choose: bool = false

signal _box_done

var box_width: float = 96
var box_open_size: float = 480
var box_diff_select_size: float = 768

func play_voice_line(voice_line: String):
	voice.stop()
	voice.stream = voice_lines[voice_line]
	voice.play()

func find_tjas(path: String):
	var dir: DirAccess = DirAccess.open(path)
	if dir:
		var files: PackedStringArray = dir.get_directories()
		files.append_array(dir.get_files())
		for file in files:
			if dir.dir_exists(file):
				var npath: String = path + file + "/"
				find_tjas(npath)
				continue
			if file.get_extension() == "tja":
				songs.push_back(TJAMeta.load_from_file(path + file))

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_editor_hint(): return
	visual_taiko.active = false
	visual_taiko_position = visual_taiko.global_position
	for bvoice in ResourceLoader.list_directory("res://assets/snd/songselect/"):
		voice_lines.set(bvoice.replace("voice_", "").get_basename(), load("res://assets/snd/songselect/" + bvoice))
	find_tjas(Configuration.get_section_key("game", "song_folder"))
	
	if songs.size() == 0:
		OS.alert("No songs found!\nPlease check your song folder.")
		get_tree().quit()
		return
	
	queue_redraw()
	
	timer.timeout.connect(start_music)
	play_voice_line("enter")
	anim.play("DonStart")
	anim.advance(0)
	
	await anim.animation_finished
	anim.play("RESET")
	await get_tree().create_timer(0.15).timeout
	
	can_choose = true
	visual_taiko.active = true
	timer.start()

func start_music():
	if Engine.is_editor_hint(): return
	var song: TJAMeta = songs[selected_index]
	if !song.wave and song.wave_path:
		var header_value: String = song.wave_path
		var ext: String = header_value.get_extension()
		print(song.path + header_value)
		match ext.to_lower():
			"ogg": song.wave = AudioStreamOggVorbis.load_from_file(song.path + header_value)
			"mp3": song.wave = AudioStreamMP3.load_from_file(song.path + header_value)
			"wav": song.wave = AudioStreamWAV.load_from_file(song.path + header_value)
			_: printerr("Unknown music file extension! (Must be vorbis (ogg), mp3 or wav)")
	music.stream = song.wave
	music.play(song.demo_start)

func select_song():
	visual_taiko.side_active = false
	play_voice_line("start_song_1p")
	var song: TJAMeta = songs[selected_index]
	anim.play("SongTransition")
	await anim.animation_finished
	SongLoadHandler.select_song(song, selected_diff)

var selected: bool = false
var smoothed_selected_index: float = 0
var last_selected_index: int = 0

var target_box_size: float = box_open_size
var target_prev_box_size: float = box_width

func move_cursor(s: int = 1):
	anim.stop()
	anim.play("DonMove")
	# SoundHandler.play_sound("ka.wav")
	# visual_taiko.global_position.x += 8 * s
	# visual_taiko.global_position.y = visual_taiko_position.y + 8
	music.stop()
	if box_transition > 0:
		box_transition = minf(box_transition, 1.0)
		box_out = true
		await _box_done
	
	box_transition = 0
	selected_index = wrapi(selected_index + s, 0, songs.size())
	timer.start()

var song_select_cursor: int = 0
var ss_cursor_offset_y: float = 0
var selected_chart: Array[Dictionary]
var selected_diff: int = 0
var stupid_fucking_alpha_hack_i_will_remove_someday: bool = false

func song_select_move_cursor(s: int = 1):
	anim.play("DonMove")
	# SoundHandler.play_sound("ka.wav")
	# visual_taiko.global_position.x += 8 * s
	# visual_taiko.global_position.y = visual_taiko_position.y + 8
	ss_cursor_offset_y = 4
	song_select_cursor = wrapi(song_select_cursor + s, 0, 1 + selected_chart.size())
	selected_diff = song_select_cursor - 1

func song_select_to_diff_select():
	visual_taiko.side_active = false
	anim.play("DonSelect")
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
	visual_taiko.side_active = true

func diff_select_to_song_select():
	visual_taiko.side_active = false
	anim.play("DonSelect")
	state = State.DIFF_TO_SONG
	box_transition = 1.0
	target_prev_box_size = box_open_size
	target_box_size = box_diff_select_size
	stupid_fucking_alpha_hack_i_will_remove_someday = true
	box_side_transition = 1.0
	box_out = true
	await _box_done
	state = State.SONG_SELECT
	box_transition = 1.0
	target_box_size = box_open_size
	target_prev_box_size = box_width
	stupid_fucking_alpha_hack_i_will_remove_someday = false
	visual_taiko.side_active = true

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	queue_redraw()
	
	entry_transition += delta*3
	# entry_transition = minf(1.0, entry_transition)
	
	if not can_choose: 
		visual_taiko.active = false
		return
	
	visual_taiko.active = true
	if state == State.SONG_TO_DIFF or state == State.DIFF_TO_SONG:
		visual_taiko.active = false
	
	# visual_taiko.global_position.x = move_toward(visual_taiko.global_position.x, visual_taiko_position.x, delta*32)
	# visual_taiko.global_position.y = move_toward(visual_taiko.global_position.y, visual_taiko_position.y, delta*64)
	ss_cursor_offset_y = move_toward(ss_cursor_offset_y, 0, delta*24)
	
	if music.playing or state > State.SONG_SELECT: 
		box_transition += delta*3
	
	if state == State.SONG_TO_DIFF:
		box_side_transition += delta * 2
	if state == State.SONG_SELECT:
		box_side_transition -= delta * 2
		box_side_transition = maxf(0.0, box_side_transition)
	
	smoothed_selected_index = move_toward(smoothed_selected_index, selected_index, delta*10)
		# smoothed_selected_index = move_toward(smoothed_selected_index, selected_index, delta*8)
	
	if selected: 
		visual_taiko.active = false
		return
	if box_out: 
		visual_taiko.active = false
		var speed: float = 6
		box_transition -= delta*speed
		if box_transition <= 0:
			box_transition = 0
			box_out = false
			_box_done.emit()
		return
	
	if state == State.SONG_SELECT:
		if Input.is_action_just_pressed("kat_left"):
			move_cursor(-1)
		elif Input.is_action_just_pressed("kat_right"):
			move_cursor(1)
	elif state == State.DIFF_SELECT:
		if Input.is_action_just_pressed("kat_left"):
			song_select_move_cursor(-1)
		elif Input.is_action_just_pressed("kat_right"):
			song_select_move_cursor(1)
	
	# First to last
	if last_selected_index == 0 and (selected_index == songs.size() - 1):
		smoothed_selected_index = songs.size()
	# Last to first
	if selected_index == 0 and (last_selected_index == songs.size() - 1):
		smoothed_selected_index = -1
		
	last_selected_index = selected_index

	if Input.is_action_just_pressed("don_left") or Input.is_action_just_pressed("don_right"):
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
			select_song()

func ease_out_back(x: float):
	const c1 := 1.70158
	const c3 := c1 + 1
	
	return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)

func _draw() -> void:
	var x: float = 0
	var bwidth: float = minf(target_box_size, lerpf(target_prev_box_size, target_box_size, box_transition))
	x = (get_window().size.x / 2.0) - (bwidth / 2.0) - ((box_width + padding) * smoothed_selected_index) - ((8 - selected_index) * (box_width + padding))
	
	var trans: float = box_transition
	draw_set_transform(Vector2.RIGHT * x)
	var min_size: int = selected_index - 8
	var max_size: int = selected_index + 8
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
			right.y = lerpf(480, 0, ease_out_back(minf(1.0, (entry_transition) - (i / 4.0 + 1.25))))
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
		var box: StyleBox = song_box
		if i == selected_index: bsize.x = minf(target_box_size, lerpf(target_prev_box_size, target_box_size, trans))
		draw_style_box(box, Rect2(Vector2.ZERO, bsize + (23*Vector2.ONE)))
		if i == selected_index:
			draw_style_box(box_selected, Rect2(Vector2.ZERO, bsize))
		
		if state > State.SONG_SELECT or stupid_fucking_alpha_hack_i_will_remove_someday:
			trans = 1.0
		
		# Song index
		box = box_index
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
		if i == selected_index:
			var base_padding: float = 24
			if state >= State.DIFF_SELECT or stupid_fucking_alpha_hack_i_will_remove_someday:
				base_padding = lerpf(24, 96, minf(1.0, box_transition))
			var diff_width: float = (24*2 + base_padding) * song.chart_metadata.size()
			var diff_padding: float = (288 / diff_width) * base_padding
			var diff_x: float = x + diff_padding*2
			if state >= State.DIFF_SELECT or stupid_fucking_alpha_hack_i_will_remove_someday:
				diff_x += (bsize.x - box_open_size) / 2.0
			const diff_height: float = 372
			for k in range(song.chart_metadata.size()):
				var chart: Dictionary = song.chart_metadata[k]
				# if not chart: continue
				draw_set_transform(offset_x.call(diff_x))
				(box_difficulty as StyleBoxFlat).bg_color.a = minf(1, trans)
				draw_style_box(box_difficulty, Rect2(Vector2(0, 64), Vector2(24*2, diff_height)))
				
				# Difficulty icon
				var diff: int = chart.get("course_enum", -1)
				var star_star_clr: Color = Color.WHITE
				star_star_clr.a = minf(1, trans)
				
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
				star_clr.a = minf(1, trans)
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
				clr.a = minf(1, trans)
				draw_string(font, Vector2(24, 78), diff_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, clr, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_VERTICAL)
				
				diff_x += diff_padding + 24*2
		
		# Song title
		var title: String = song.title_localized.get("ja", song.title)
		var y: float = right.y + 24
		if state >= State.DIFF_SELECT:
			var t_ofs: float = 0.0
			if state == State.DIFF_SELECT:
				t_ofs = 1.0
			y = lerpf(24, 0, minf(1.0, maxf(0.0, box_transition - t_ofs)))
		var font_size: int = 28
		var height: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size,TextServer.JUSTIFICATION_NONE,TextServer.DIRECTION_AUTO,TextServer.ORIENTATION_VERTICAL).y
		var font_v_scale: float = minf(1.0, 424.0 / height)
		var x_ofs: float = 48 + (bsize.x - box_width)
		draw_set_transform(Vector2((x + box_ofs) + x_ofs, y), 0.0, Vector2(1.0, font_v_scale))
		draw_string_outline(font, Vector2.ZERO, title, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 18, Color.BLACK, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_VERTICAL)
		draw_string(font, Vector2.ZERO, title, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_VERTICAL)
		
		# Subtitle if applicable
		var subtitle: String = song.subtitle.lstrip("--")
		if subtitle.is_empty() or i != selected_index:
			x += padding + bsize.x
			continue
		font_size = 22
		x_ofs -= font_size + 16
		height = font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size,TextServer.JUSTIFICATION_NONE,TextServer.DIRECTION_AUTO,TextServer.ORIENTATION_VERTICAL).y
		y += 48
		font_v_scale = minf(1.0, 376.0 / height)
		var outline_color: Color = Color.BLACK
		var subtitle_color: Color = Color.WHITE
		outline_color.a = minf(1, trans)
		subtitle_color.a = minf(1, trans)
		draw_set_transform(Vector2((x + box_ofs) + x_ofs, y), 0.0, Vector2(1.0, font_v_scale))
		draw_string_outline(font, Vector2.ZERO, subtitle, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 18, outline_color, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_VERTICAL)
		draw_string(font, Vector2.ZERO, subtitle, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, subtitle_color, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_VERTICAL)
		x += padding + bsize.x
