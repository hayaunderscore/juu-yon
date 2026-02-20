extends Control
class_name MainScene

var tja: TJA
var chart: TJAChartInfo
var current_note_list: Array[Dictionary]
var roll: bool = false

@onready var audio: AudioStreamPlayer = $Music
@onready var taiko: TaikoDrum = $TaikoArea/Taiko
@onready var note_drawer: TaikoNoteDrawer = $TaikoArea/Lane/Judge/NoteDrawer
@onready var top_back: Sprite2D = %Back
@onready var top_back_clear: Sprite2D = %Clear
@onready var top_back_fail: Sprite2D = %Fail

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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pick_random_bg()

# TODO 2P
var bg_path: String = "res://assets/game/top_bg/p1/"
func pick_random_bg():
	var dir: DirAccess = DirAccess.open(bg_path)
	var paths: PackedStringArray = dir.get_files()
	var filtered: PackedStringArray
	for path in paths:
		if path.get_extension() == "png":
			filtered.push_back(path)
	var picked: String = filtered[randi_range(0, filtered.size() - 1)]
	top_back.texture = ImageTexture.create_from_image(Image.load_from_file(bg_path + picked))
	if FileAccess.file_exists(bg_path.replace("p1", "clear") + picked):
		top_back_clear.texture = ImageTexture.create_from_image(Image.load_from_file(bg_path.replace("p1", "clear") + picked))
	if FileAccess.file_exists(bg_path.replace("p1", "fail") + picked):
		top_back_fail.texture = ImageTexture.create_from_image(Image.load_from_file(bg_path.replace("p1", "fail") + picked))

var difficulty_icons: Dictionary[int, Texture2D] = {
	TJAChartInfo.CourseType.EASY: preload("uid://by46t0vy31w7s"),
	TJAChartInfo.CourseType.NORMAL: preload("uid://buhdff8rjkb82"),
	TJAChartInfo.CourseType.HARD: preload("uid://p0pvanwm7qh1"),
	TJAChartInfo.CourseType.ONI: preload("uid://d04eby56jesxn"),
	TJAChartInfo.CourseType.EDIT: preload("uid://drsb8jnq80p1"),
}

func merge_branches_prelim(chart: TJAChartInfo):
	if not (chart.flags & TJAChartInfo.ChartFlags.BRANCHFUL): return
	# Append master notes FOR NOW
	# TODO actual REAL branching
	chart.notes.append_array(chart.branch_notes[TJAChartInfo.BranchType.MASTER])
	chart.barline_data.append_array(chart.branch_barlines[TJAChartInfo.BranchType.MASTER])
	# Redo draw data
	var sorted: Array[Dictionary] = chart.notes.duplicate(true)
	for i in range(0, sorted.size()):
		chart.notes[i]["cached_index"] = i
		chart.draw_data[i] = sorted[i]
	var s: Array = Globals.merge_sort(chart.notes, func(a, b): a["time"] < b["time"])
	chart.notes.assign(s)

func load_tja(new_tja: TJAMeta, diff: int):
	tja = new_tja.create_tja_from_meta()
	chart = tja.charts[diff]
	# TODO
	# merge_branches_prelim(chart)
	current_note_list = chart.notes
	audio.stream = tja.wave
	%SongTitle.text = tja.title_localized.get(TranslationServer.get_locale(), tja.title)
	Globals.song_name = %SongTitle.text
	audio.volume_linear = tja.song_volume / 100.0
	%Chara.bpm = tja.start_bpm
	$Symbol.texture = difficulty_icons[chart.course]
	$Symbol/SymbolHighlight.texture = difficulty_icons[chart.course]
	$Symbol/SymbolHighlightGood.texture = difficulty_icons[chart.course]
	%Gauge.difficulty = chart.course
	%Gauge.total_notes = current_note_list.filter(func(a): return a["note"] < 5 and a["note"] > 0).size()
	$Timer.start()

var elapsed: float = 0.0
var beat: float = 0.0
var bpm: float = 120.0

var auto_don_side: bool = false
var auto_kat_side: bool = false

var _latency: float = AudioServer.get_output_latency()

var gogo_tween: Tween

var command_log_offset: int = 0

func handle_play_events():
	for i in range(command_log_offset, chart.command_log.size()):
		var command: Dictionary = chart.command_log[i]
		if not command.has("time"): continue
		var type: TJAChartInfo.CommandType = command.get("com") as TJAChartInfo.CommandType
		var time: float = command.get("time")
		if time >= elapsed: continue
		command_log_offset += 1
		match type:
			TJAChartInfo.CommandType.GOGOSTART:
				if gogo_tween: gogo_tween.kill()
				gogo_tween = create_tween()
				gogo_tween.set_parallel(true)
				%Soul.scale = Vector2.ONE * 2
				const yellow: Color = Color(3.77, 3.77, 0.0)
				%Judge.self_modulate = yellow
				gogo_tween.tween_property(%Soul, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
				gogo_tween.tween_property(%GogoGradient, "scale:y", 1.0, 0.1)
				gogo_tween.tween_property(%GogoBackGradient, "modulate:a", 1.0, 0.2)
				%Chara.gogo = true
				var state = %Chara.state
				if state != %Chara.State.COMBO:
					%Chara.state = %Chara.State.GOGO
			TJAChartInfo.CommandType.GOGOEND:
				if gogo_tween: gogo_tween.kill()
				gogo_tween = create_tween()
				gogo_tween.set_parallel(true)
				gogo_tween.tween_property(%Soul, "scale", Vector2.ZERO, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
				gogo_tween.tween_property(%GogoGradient, "scale:y", 0.0, 0.1)
				gogo_tween.tween_property(%GogoBackGradient, "modulate:a", 0.0, 0.2)
				%Judge.self_modulate = Color.WHITE
				%Chara.gogo = false
				var state = %Chara.state
				if state != %Chara.State.COMBO:
					%Chara.state = %Chara.State.IDLE
			TJAChartInfo.CommandType.BPMCHANGE:
				%Chara.bpm = command.get("val1")

var roll_cnt: int = 0
var current_roll_note: Dictionary
func auto_roll():
	if not roll: return
	if roll_cnt % 4 == 0:
		taiko.taiko_input(0, 1 if auto_don_side else 0, 100, false)
		auto_don_side = !auto_don_side
		roll_cnt = 0
		if current_roll_note.get("note", 0) == 5:
			add_note_to_gauge(1, true)
		elif current_roll_note.get("note", 0) == 6:
			add_note_to_gauge(3, true)
	roll_cnt += 1

var add_mat: CanvasItemMaterial = preload("uid://j5mp4mbuaxqe")
var good_tex_effect: Array[Texture2D] = [
	preload("uid://c1b0xbse3rx76"),
	preload("uid://q3fnlvyn3nth"),
]
var ok_tex_effect: Array[Texture2D] = [
	preload("uid://dsv7c1aj7fekv"),
	preload("uid://dq3jrftb0u4e8"),
]
var good_tex_hit: Array[Texture2D] = [
	preload("uid://cyi07ksfk6xt8"),
	preload("uid://dcl6rfoch8x21"),
]
var ok_tex_hit: Array[Texture2D] = [
	preload("uid://dbrb5yxudsjmk"),
	preload("uid://870vju77rh3d"),
]
func create_judge_effect(good: bool = true, big: bool = false):
	var effect_table: Array[Texture2D] = good_tex_effect if good else ok_tex_effect
	var hit_table: Array[Texture2D] = good_tex_hit if good else ok_tex_hit
	# Judge effect
	var base: Sprite2D = Sprite2D.new()
	var big_base: Sprite2D = null
	base.texture = good_tex_effect[0]
	base.material = add_mat
	base.z_index = 1
	base.modulate.a = 0.75
	if big:
		big_base = Sprite2D.new()
		big_base.texture = effect_table[1]
		big_base.material = add_mat
		big_base.scale = Vector2.ONE * 0.5 # Starts small then scales later- see tween
		base.add_child(big_base)
	%LanePivot.add_child(base)
	# Lane note hit effect
	var note: Sprite2D = Sprite2D.new()
	note.texture = hit_table[1 if big else 0]
	%LanePivot.add_child(note)
	# Tween both of these together
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	if is_instance_valid(big_base): tween.tween_property(big_base, "scale", Vector2.ONE, 0.1)
	tween.tween_property(base, "modulate:a", 0, 0.1).set_delay(0.05)
	tween.tween_property(note, "modulate:a", 0, 0.3)
	tween.set_parallel(false)
	tween.tween_callback(func():
		base.queue_free()
		note.queue_free()
	)

var note_follow: PackedScene = preload("uid://bpksjoo45newj")
var note_rainbow: PackedScene = preload("uid://mfmyctup3c1t")
@onready var note_curve: Path2D = $NoteCurvePath
func add_note_to_gauge(type: int, skip_judge: bool = false, good: bool = true):
	var balloon: bool = false
	var balloon_tex: AtlasTexture
	var rainbow: TextureRect
	# Add rainbow effects
	if type == 7:
		balloon = true
		rainbow = note_rainbow.instantiate()
		%BalloonPivot.add_child(rainbow)
		balloon_tex = rainbow.texture as AtlasTexture
		balloon_tex.region.position.x = 0.0
		balloon_tex.region.size.x = 1.0
		type = 3
	# Create note path for this note type
	var note: PathFollow2D = note_follow.instantiate()
	var spr: Sprite2D = note.get_child(0)
	var anim: AnimationPlayer = note.get_node("AnimationPlayer")
	spr.texture = TaikoNoteDrawer.notes[type]
	note_curve.add_child(note)
	# Create judge effect
	if not skip_judge: create_judge_effect(good, type == 3 or type == 4)
	# TODO transition
	var tween: Tween = create_tween()
	tween.tween_property(note, "progress_ratio", 1.0, 0.3)
	if balloon:
		tween.set_parallel(true)
		tween.tween_property(balloon_tex, "region:size:x", balloon_tex.atlas.get_width(), 0.3)
		tween.set_parallel(false)
	tween.tween_callback(anim.play.bind("Hit"))
	if balloon:
		tween.set_parallel(true)
		tween.tween_property(rainbow, "position:x", balloon_tex.atlas.get_width(), 0.3)
		tween.tween_property(balloon_tex, "region:position:x", balloon_tex.atlas.get_width(), 0.3)
		tween.set_parallel(false)
		tween.tween_callback(rainbow.queue_free)

func update_top_back(delta: float):
	var target_clear: float = 0.0
	if %Chara.clear: target_clear = 1.0
	top_back_clear.modulate.a = move_toward(top_back_clear.modulate.a, target_clear, delta * 8)

func _process(delta: float) -> void:
	if not tja: return
	if not chart: return
	
	update_top_back(delta)
	
	elapsed = audio.get_playback_position()
	if !audio.stream_paused: elapsed += AudioServer.get_time_since_last_mix()
	# Compensate for output latency.
	elapsed -= _latency
	elapsed -= $Timer.time_left
	
	beat = calculate_beat_from_ms(elapsed, chart.bpm_log)
	var min: float = floor(elapsed / 60.0)
	var sec: float = fmod(elapsed, 60.0)
	%TimeLeft.text = "%02d:%02d" % [min, sec]
	%Beat.text = "%.2f" % [beat]
	# $Label.text = "Current time: %.3f\nCurrent beat: %.3f" % [elapsed, beat]
	
	note_drawer.bar_list = chart.barline_data
	note_drawer.current_beat = beat
	note_drawer.time = elapsed
	note_drawer.draw_list = chart.draw_data
	note_drawer.bemani_scroll = chart.flags & (TJAChartInfo.ChartFlags.BMSCROLL | TJAChartInfo.ChartFlags.HBSCROLL)
	
	%Chara.beat = beat
	%Soul.beat = beat
	%SongBorder.size.x = get_viewport_rect().size.x

func _physics_process(delta: float) -> void:
	if not tja: return
	if not chart: return
	
	if Input.is_action_just_pressed("pause"):
		audio.stream_paused = !audio.stream_paused
		if not $Timer.is_stopped(): $Timer.paused = !$Timer.paused
	
	handle_play_events()
	
	if current_note_list.size() <= 0: return
	
	auto_roll()
	
	while current_note_list.size() > 0 and current_note_list[-1]["time"] < elapsed:
		var note: Dictionary = current_note_list.pop_back()
		if not note.has("time"): continue
		var type: int = note["note"]
		var time: float = note["time"]
		# Do not include special notes from now on.
		if type >= 999: continue
		# Should we register a hit?
		if time >= elapsed: continue
		match type:
			1:
				taiko.taiko_input(0, 1 if auto_don_side else 0)
				taiko.combo += 1
				if taiko.combo % 10 == 0:
					%Chara.do_combo_animation()
				auto_don_side = !auto_don_side
				add_note_to_gauge(type)
				%Gauge.add_good()
			2:
				taiko.taiko_input(1, 1 if auto_kat_side else 0)
				taiko.combo += 1
				if taiko.combo % 10 == 0:
					%Chara.do_combo_animation()
				auto_kat_side = !auto_kat_side
				add_note_to_gauge(type)
				%Gauge.add_good()
			3:
				taiko.combo += 1
				for side in range(2):
					taiko.taiko_input(0, side)
				if taiko.combo % 10 == 0:
					%Chara.do_combo_animation()
				add_note_to_gauge(type)
				%Gauge.add_good()
			4:
				taiko.combo += 1
				for side in range(2):
					taiko.taiko_input(1, side)
				if taiko.combo % 10 == 0:
					%Chara.do_combo_animation()
				add_note_to_gauge(type)
				%Gauge.add_good()
		# if current_note_list.size() <= 0: break
		if type == 5 or type == 6 or type == 7:
			roll = true
			roll_cnt = 0
			current_roll_note = note
		if type == 8: 
			roll = false
			if note.has("roll_note") and note["roll_note"].has("note") and note["roll_note"]["note"] == 7:
				var rolln: Dictionary = note["roll_note"]
				var roll_type: int = rolln["note"]
				if roll_type == 7:
					SoundHandler.play_sound("geki.wav")
					add_note_to_gauge(7, true)
				chart.draw_data.erase(rolln.get("cached_index", chart.draw_data.find_key(rolln)))
		if type != 5 and type != 6 and type != 7 and type != 8: chart.draw_data.erase(note.get("cached_index", chart.draw_data.find_key(note)))

func _on_timer_timeout() -> void:
	audio.play()

func _on_music_finished() -> void:
	# TODO results screen
	TransitionHandler.change_scene_to_file("uid://b8jopawilsvnu", true)

func _on_gauge_filled_soul() -> void:
	%Chara.clear = true

func _on_gauge_unfilled_soul() -> void:
	%Chara.clear = false

func _on_gauge_rainbow_soul() -> void:
	%Chara.state = %Chara.State.SPIN
	var mat: ShaderMaterial = %Chara.material
	mat.set_shader_parameter("mixture", 0.5)

func _on_gauge_unrainbow_soul() -> void:
	var mat: ShaderMaterial = %Chara.material
	mat.set_shader_parameter("mixture", 0.0)

func _on_taiko_combo_callout(combo: int) -> void:
	$CalloutBalloon.show_combo(combo)
