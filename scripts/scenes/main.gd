extends Control
class_name MainScene

var tja: TJA
var chart: TJAChartInfo
var current_note_list: Array[Dictionary]
var roll: bool = false

@onready var audio: AudioStreamPlayer = $Music
@onready var taiko: TaikoDrum = $TaikoArea/Taiko
@onready var note_drawer: TaikoNoteDrawer = $TaikoArea/Lane/Judge/NoteDrawer

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
	pass

func load_tja(new_tja: TJAMeta, diff: int):
	tja = new_tja.create_tja_from_meta()
	chart = tja.charts[diff]
	current_note_list = chart.notes
	audio.stream = tja.wave
	%SongTitle.text = tja.title_localized.get("ja", tja.title)
	Globals.song_name = %SongTitle.text
	audio.volume_linear = tja.song_volume / 100.0

var elapsed: float = 0.0
var beat: float = 0.0

var auto_don_side: bool = false
var auto_kat_side: bool = false

var _latency: float = AudioServer.get_output_latency()

var gogo_tween: Tween

func handle_play_events():
	for command in chart.command_log:
		if not command.has("time"): continue
		var type: TJAChartInfo.CommandType = command.get("com") as TJAChartInfo.CommandType
		var time: float = command.get("time")
		if time >= elapsed: continue
		match type:
			TJAChartInfo.CommandType.GOGOSTART:
				if gogo_tween: gogo_tween.kill()
				gogo_tween = create_tween()
				gogo_tween.tween_property(%GogoGradient, "scale:y", 1.0, 0.1)
			TJAChartInfo.CommandType.GOGOEND:
				if gogo_tween: gogo_tween.kill()
				gogo_tween = create_tween()
				gogo_tween.tween_property(%GogoGradient, "scale:y", 0.0, 0.1)

var roll_cnt: int = 0
func auto_roll():
	if not roll: return
	if roll_cnt % 4 == 0:
		taiko.taiko_input(0, 1 if auto_don_side else 0)
		auto_don_side = !auto_don_side
		roll_cnt = 0
	roll_cnt += 1

func _physics_process(delta: float) -> void:
	if not tja: return
	if not chart: return
	
	if Input.is_action_just_pressed("pause"):
		audio.stream_paused = !audio.stream_paused
		if not $Timer.is_stopped(): $Timer.paused = !$Timer.paused
	
	elapsed = audio.get_playback_position()
	if !audio.stream_paused: elapsed += AudioServer.get_time_since_last_mix()
	# Compensate for output latency.
	elapsed -= _latency
	elapsed -= $Timer.time_left
	
	beat = calculate_beat_from_ms(elapsed, chart.bpm_log)
	var min: float = floor(elapsed / 60.0)
	var sec: float = fmod(elapsed, 60.0)
	$TimeLeft.text = "%02d:%02d" % [min, sec]
	$Beat.text = "%.2f" % [beat]
	# $Label.text = "Current time: %.3f\nCurrent beat: %.3f" % [elapsed, beat]
	
	note_drawer.bar_list = chart.barline_data
	note_drawer.current_beat = beat
	note_drawer.time = elapsed
	note_drawer.draw_list = chart.draw_data
	note_drawer.bemani_scroll = chart.flags & (TJAChartInfo.ChartFlags.BMSCROLL | TJAChartInfo.ChartFlags.HBSCROLL)
	
	%SongBorder.size.x = get_viewport_rect().size.x
	
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
				auto_don_side = !auto_don_side
			2:
				taiko.taiko_input(1, 1 if auto_kat_side else 0)
				taiko.combo += 1
				auto_kat_side = !auto_kat_side
			3:
				taiko.combo += 1
				for side in range(2):
					taiko.taiko_input(0, side)
			4:
				taiko.combo += 1
				for side in range(2):
					taiko.taiko_input(1, side)
		# if current_note_list.size() <= 0: break
		if type == 5 or type == 6 or type == 7:
			roll = true
			roll_cnt = 0
		if type == 8: 
			roll = false
		if type != 5 and type != 6 and type != 7 and type != 8: chart.draw_data.erase(note.get("cached_index", tja.charts[0].draw_data.find_key(note)))

func _on_timer_timeout() -> void:
	audio.play()

func _on_music_finished() -> void:
	# TODO results screen
	TransitionHandler.change_scene_to_file("uid://b8jopawilsvnu", true)
