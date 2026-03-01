extends Control
class_name MainScene

var chart: TJAChartInfo
var current_note_list: Array[Dictionary]
var roll: bool = false
var score_delay: bool = true

@onready var audio: AudioStreamPlayer = $Music
@onready var taiko: TaikoDrum = $TaikoArea/Taiko
@onready var note_drawer: TaikoNoteDrawer = $TaikoArea/Lane/Judge/NoteDrawer
@onready var top_back: Sprite2D = %Back
@onready var top_back_clear: Sprite2D = %Clear
@onready var top_back_fail: Sprite2D = %Fail
var score_handler: ScoreHandler = ScoreHandler.new()

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
	pick_random_footer()
	%Nametag.text = Configuration.get_section_key_from_string("Player1:name") if not Globals.players_auto[0] else tr("game_mod_auto")
	if len(%Nametag.text) > 8:
		%Nametag.scale.x = 8.0 / len(%Nametag.text)

# TODO 2P
var bg_path: String = "res://assets/game/top_bg/p1/"
func pick_random_bg():
	var paths: PackedStringArray = ResourceLoader.list_directory(bg_path)
	var filtered: PackedStringArray
	for path in paths:
		if path.get_extension() == "png":
			filtered.push_back(path)
	var picked: String = filtered[randi_range(0, filtered.size() - 1)]
	top_back.texture = load(bg_path + picked)
	if ResourceLoader.exists(bg_path.replace("p1", "clear") + picked):
		top_back_clear.texture = load(bg_path.replace("p1", "clear") + picked)
	if ResourceLoader.exists(bg_path.replace("p1", "fail") + picked):
		top_back_fail.texture = load(bg_path.replace("p1", "fail") + picked)

var footer_path: String = "res://assets/game/stage/"
func pick_random_footer():
	var paths: PackedStringArray = ResourceLoader.list_directory(footer_path)
	var filtered: PackedStringArray
	for path in paths:
		if path.get_extension() == "png":
			filtered.push_back(path)
	var picked: String = filtered[randi_range(0, filtered.size() - 1)]
	$Footer.texture = load(footer_path + picked)

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
	for i in range(chart.branch_section_notes[TJAChartInfo.BranchType.MASTER].size()):
		var sec: BranchSection = chart.branch_section_notes[TJAChartInfo.BranchType.MASTER][i]
		merge_branch_section(sec, true)
	# Redo draw data
	chart.draw_data.clear()
	var sorted: Array[Dictionary] = chart.notes.duplicate()
	for i in range(0, sorted.size()):
		chart.notes[i]["cached_index"] = i
		chart.draw_data[i] = sorted[i]

func merge_branch_section(branch_section: BranchSection, skip_draw_data: bool = false):
	if branch_section == null: return
	
	chart.notes.append_array(branch_section.notes)
	chart.barline_data.append_array(branch_section.barlines)
	chart.command_log.append_array(branch_section.command_log)
	
	# Sort all of these!
	for arr in [chart.notes, chart.barline_data, chart.command_log]:
		for i in range(0, arr.size()):
			arr[i]["index"] = i
		arr.sort_custom(Globals.sort_notes)
	
	if skip_draw_data: return
	
	# Redo draw data
	chart.draw_data.clear()
	var sorted: Array[Dictionary] = chart.notes.duplicate()
	for i in range(0, sorted.size()):
		chart.notes[i]["cached_index"] = i
		chart.draw_data[i] = sorted[i]

var is_branch: bool = false
var branch_condition: Dictionary
var branch_condition_count: float = 0
var branch_note_count: int = 0
var drumroll_count: int = 0
var total_drumrolls: int = 0

var expert_branch_color: Color = Color("#305770")
var master_branch_color: Color = Color("#7E2E6E")
var branch_tween: Tween

var last_level: int = 0
var ll_real: int = 0
@onready var branch_text: TextureRect = %BranchText
@onready var branch_text_transition: TextureRect = %BranchTextTransition

var branch_indicator_textures: Array[Texture2D] = [
	preload("uid://c18t0odfy2g45"),
	preload("uid://csri2tngypeb1"),
	preload("uid://71ecur1e1mhc"),
]

func change_branch_visual(level: TJAChartInfo.BranchType):
	if branch_tween:
		branch_tween.custom_step(99999)
		branch_tween.kill()
	if level == ll_real: return
	branch_tween = create_tween()
	var level_diff: int = (level as int) - last_level
	var dir: int = sign(level_diff)
	var count: int = 0
	while count < abs(level_diff):
		branch_tween.tween_callback(func():
			branch_text_transition.texture = branch_indicator_textures[clampi(last_level + dir, 0, 2)]
			branch_text.texture = branch_indicator_textures[clampi(last_level, 0, 2)]
			branch_text_transition.position.y = 26 + (branch_text_transition.size.y * 0.5 * -dir)
			branch_text.position.y = 26
			branch_text.position.x = 595
			branch_text_transition.position.x = 595
			branch_text.modulate.a = 1.0
			branch_text_transition.modulate.a = 0.0
			last_level += dir
		)
		ll_real += dir
		match ll_real:
			TJAChartInfo.BranchType.EXPERT:
				if %BranchBG.self_modulate.a < 1.0:
					%BranchBG.self_modulate = expert_branch_color
					%BranchBG.self_modulate.a = 0.0
				branch_tween.tween_property(%BranchBG, "self_modulate", expert_branch_color, 0.1)
			TJAChartInfo.BranchType.MASTER:
				if %BranchBG.self_modulate.a < 1.0:
					%BranchBG.self_modulate = master_branch_color
					%BranchBG.self_modulate.a = 0.0
				branch_tween.tween_property(%BranchBG, "self_modulate", master_branch_color, 0.1)
			_:
				branch_tween.tween_property(%BranchBG, "self_modulate:a", 0, 0.1)
		branch_tween.set_parallel(true)
		branch_tween.tween_property(branch_text, "position:y", branch_text.size.y * 0.5 * dir, 0.15).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK).as_relative()
		branch_tween.tween_property(branch_text, "modulate:a", 0.0, 0.1).set_delay(0.05)
		branch_tween.tween_property(branch_text_transition, "position:y", branch_text_transition.size.y * 0.5 * dir, 0.15).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK).as_relative()
		branch_tween.tween_property(branch_text_transition, "modulate:a", 1.0, 0.1).set_delay(0.05)
		branch_tween.set_parallel(false)
		branch_tween.tween_interval(0.2)
		count += 1
	if not branch_tween.is_running():
		branch_tween.kill()

func evaluate_branch():
	if not is_branch: return
	var end_time: float = branch_condition["end_time"]
	var cond: TJAChartInfo.BranchCondition = branch_condition["cond"]
	var expr: int = branch_condition["exp"]
	var mas: int = branch_condition["mas"]
	
	# if elapsed < end_time: return
	is_branch = false
	
	if cond == TJAChartInfo.BranchCondition.p:
		branch_condition_count = maxi(mini(floori(float(branch_condition_count) / branch_note_count * 100.0), 100), 0)
	elif cond == TJAChartInfo.BranchCondition.r:
		branch_condition_count = maxi(drumroll_count, floori(branch_condition_count))
	
	if branch_condition_count >= expr and branch_condition_count < mas and expr > 0:
		var expert_track: Array = chart.branch_section_notes[TJAChartInfo.BranchType.EXPERT]
		merge_branch_section(expert_track.pop_back())
		chart.branch_section_notes[TJAChartInfo.BranchType.MASTER].pop_back()
		chart.branch_section_notes[TJAChartInfo.BranchType.NORMAL].pop_back()
		change_branch_visual(TJAChartInfo.BranchType.EXPERT)
		print("SWITCHED BRANCH TO EXPERT VIA %s" % [TJAChartInfo.BranchCondition.find_key(cond)])
	elif branch_condition_count >= mas:
		var master_track: Array = chart.branch_section_notes[TJAChartInfo.BranchType.MASTER]
		merge_branch_section(master_track.pop_back())
		chart.branch_section_notes[TJAChartInfo.BranchType.EXPERT].pop_back()
		chart.branch_section_notes[TJAChartInfo.BranchType.NORMAL].pop_back()
		change_branch_visual(TJAChartInfo.BranchType.MASTER)
		print("SWITCHED BRANCH TO MASTER VIA %s" % [TJAChartInfo.BranchCondition.find_key(cond)])
	else:
		var normal_track: Array = chart.branch_section_notes[TJAChartInfo.BranchType.NORMAL]
		merge_branch_section(normal_track.pop_back())
		chart.branch_section_notes[TJAChartInfo.BranchType.EXPERT].pop_back()
		chart.branch_section_notes[TJAChartInfo.BranchType.MASTER].pop_back()
		change_branch_visual(TJAChartInfo.BranchType.NORMAL)
		print("SWITCHED BRANCH TO NORMAL VIA %s" % [TJAChartInfo.BranchCondition.find_key(cond)])
	
	branch_condition_count = 0
	branch_note_count = 0

func handle_branch_params(command: Dictionary):
	var cond: TJAChartInfo.BranchCondition = command["condition"] as TJAChartInfo.BranchCondition
	var expr: int = command["expert_req"]
	var mas: int = command["master_req"]
	
	if not is_branch:
		is_branch = true
		branch_condition = {
			"cond": cond, "exp": expr, "mas": mas
		}
		var branch_condition_end_time: float = 0.0
		var master: Array = chart.branch_section_notes[TJAChartInfo.BranchType.MASTER]
		var expert: Array = chart.branch_section_notes[TJAChartInfo.BranchType.EXPERT]
		var normal: Array = chart.branch_section_notes[TJAChartInfo.BranchType.NORMAL]
		if (not master.is_empty() and not master.back().notes.is_empty()):
			branch_condition_end_time = master.back().notes.back()["time"]
		elif (not expert.is_empty() and not expert.back().notes.is_empty()):
			branch_condition_end_time = expert.back().notes.back()["time"]
		elif (not normal.is_empty() and not normal.back().notes.is_empty()):
			branch_condition_end_time = normal.back().notes.back()["time"]
		else:
			branch_condition_end_time = current_note_list.back()["time"]
		branch_condition["end_time"] = branch_condition_end_time

var last_tja_meta: TJAMeta
var last_diff: int

func reload_tja():
	load_tja(last_tja_meta, last_diff)
	%Chara.reset()

func load_tja(new_tja: TJAMeta, diff: int):
	last_tja_meta = new_tja
	last_diff = diff
	
	var tja: TJA = new_tja.create_tja_from_meta()
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
	var note_arr: Array = current_note_list.duplicate()
	for sec in chart.branch_section_notes[TJAChartInfo.BranchType.MASTER]:
		note_arr.append_array((sec as BranchSection).notes)
	%Gauge.total_notes = note_arr.filter(func(a): return a["note"] < 5 and a["note"] > 0).size()
	$Timer.start()
	# Score parameters
	if chart.scoremode == -1:
		chart.scoremode = Globals.default_score_mode
	score_handler.score_mode = clampi(chart.scoremode, 0, 3) as ScoreHandler.ScoreType
	score_handler.score_init = chart.scoreinit[0]
	score_handler.score_diff = chart.scorediff
	score_delay = Configuration.get_section_key("Game", "score_delay")
	if chart.flags & TJAChartInfo.ChartFlags.BRANCHFUL:
		var t: Tween = create_tween()
		t.tween_property(%BranchText, "position:x", %BranchText.position.x - %BranchText.size.x - 24, 0.1).set_delay(1.0)

var popin: PackedScene = preload("uid://dj3s7wst6dpip")
var score_real: int = 0
func create_score_diff(val: int):
	var prev: int = score_real
	score_real = val
	var diff: int = val - prev
	var score_pop: TaikoNumber = popin.instantiate()
	var anim: AnimationPlayer = score_pop.get_node("AnimationPlayer")
	score_pop.value = diff
	anim.play("default")
	%Score.add_child(score_pop)
	if score_delay:
		await anim.animation_finished
	%Score.value += diff

var elapsed: float = 0.0
var beat: float = 0.0
var bpm: float = 120.0

var auto_don_side: bool = false
var auto_kat_side: bool = false

var _latency: float = AudioServer.get_output_latency()

var gogo_tween: Tween

var command_log_offset: int = 0

func handle_play_events():
	while chart.command_log.size() > 0 and chart.command_log[-1]["time"] < elapsed:
		var command: Dictionary = chart.command_log.pop_back()
		if not command.has("time"): continue
		var type: TJAChartInfo.CommandType = command.get("com") as TJAChartInfo.CommandType
		var time: float = command.get("time")
		if time >= elapsed: continue
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

func handle_branch_timeline():
	while chart.branch_timeline.size() > 0 and chart.branch_timeline.back()["time"] < elapsed:
		var branch_params: Dictionary = chart.branch_timeline.pop_back()
		var time: float = branch_params["time"]
		if time >= elapsed: continue
		print(branch_params)
		handle_branch_params(branch_params)

var roll_cnt: int = 0
var current_roll_note: Dictionary
func auto_roll():
	if not roll: return
	if roll_cnt % 3 == 0:
		taiko.taiko_input(0, 1 if auto_don_side else 0, 100, false)
		auto_don_side = !auto_don_side
		roll_cnt = 0
		if current_roll_note.get("note", 0) == 5:
			create_score_diff(score_handler.calc_roll(score_real, 1, %Chara.gogo))
			add_note_to_gauge(1, true)
			drumroll_count += 1
			roll_hits += 1
		elif current_roll_note.get("note", 0) == 6:
			create_score_diff(score_handler.calc_roll(score_real, 3, %Chara.gogo))
			add_note_to_gauge(3, true)
			drumroll_count += 1
			roll_hits += 1
		elif current_roll_note.get("note", 0) == 7:
			if current_roll_note.has("balloon_count"):
				current_roll_note["balloon_count"] -= 1
				if current_roll_note["balloon_count"] <= 0:
					roll = false
					pop_balloon(current_roll_note["roll_tail_ref"])
					%Chara.pop_balloon()
				else:
					%Chara.start_balloon_animation()
					%Chara.use_balloon()
					create_score_diff(score_handler.calc_balloon(score_real, 0, %Chara.gogo))
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
func create_judge_effect(good: bool = true, big: bool = false, bad: bool = false):
	if not bad:
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
		tween.tween_property(base, "modulate:a", 0, 0.02).set_delay(0.075)
		tween.tween_property(note, "modulate:a", 0, 0.3)
		tween.set_parallel(false)
		tween.tween_callback(func():
			base.queue_free()
			note.queue_free()
		)
	judge_create(JudgeType.BAD if bad else JudgeType.GOOD if good else JudgeType.OK)

enum JudgeType {
	BAD,
	OK,
	GOOD,
	ROLL
}

var judge_bad: Texture2D = preload("uid://htanu7exw36e")
var judge_ok: Texture2D = preload("uid://bv3mhdwnknuf5")
var judge_good: Texture2D = preload("uid://biohn4qhfd10f")

var good_hits: int
var ok_hits: int
var bad_hits: int
var roll_hits: int

func judge_create(type: JudgeType):
	var var_name: String = "%s_hits" % [(JudgeType.find_key(type) as String).to_lower()]
	if get(var_name):
		set(var_name, get(var_name) + 1)
	add_hit_to_gauge(type)
	var judge: Sprite2D = Sprite2D.new()
	judge.texture = get("judge_%s" % [(JudgeType.find_key(type) as String).to_lower()])
	judge.modulate.a = 0.0
	judge.offset.y = -48
	%JudgePoint.add_child(judge)
	var judge_tween: Tween = create_tween()
	judge_tween.set_parallel(true)
	judge_tween.tween_property(judge, "modulate:a", 1.0, 0.02)
	judge_tween.tween_property(judge, "offset:y", -72, 0.06)
	judge_tween.tween_property(judge, "modulate:a", 0.0, 0.1).set_delay(0.35)
	judge_tween.set_parallel(false)
	judge_tween.tween_callback(judge.queue_free)
	
var note_follow: PackedScene = preload("uid://bpksjoo45newj")
var note_rainbow: PackedScene = preload("uid://mfmyctup3c1t")
@onready var note_curve: Path2D = $NoteCurvePath
func add_note_to_gauge(type: int, skip_judge: bool = false, judgetype: JudgeType = JudgeType.GOOD):
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
	if not skip_judge: 
		# TODO create score effect
		var j: int = judgetype
		if (type == 3 or type == 4) and judgetype != JudgeType.BAD:
			j += 1
		create_score_diff(score_handler.calc_score(score_real, taiko.combo, j, %Chara.gogo)[0])
		create_judge_effect(judgetype == JudgeType.GOOD, type == 3 or type == 4, judgetype == JudgeType.BAD)
	# TODO transition
	var tween: Tween = create_tween()
	tween.tween_property(note, "progress_ratio", 1.0, 0.35)
	if balloon:
		tween.set_parallel(true)
		tween.tween_property(balloon_tex, "region:size:x", balloon_tex.atlas.get_width(), 0.35)
		tween.set_parallel(false)
	tween.tween_callback(anim.play.bind("Hit"))
	if balloon:
		tween.set_parallel(true)
		tween.tween_property(rainbow, "position:x", balloon_tex.atlas.get_width(), 0.35)
		tween.tween_property(balloon_tex, "region:position:x", balloon_tex.atlas.get_width(), 0.35)
		tween.set_parallel(false)
		tween.tween_callback(rainbow.queue_free)

func update_top_back(delta: float):
	var target_clear: float = 0.0
	if %Chara.clear: target_clear = 1.0
	top_back_clear.modulate.a = move_toward(top_back_clear.modulate.a, target_clear, delta * 4)
	target_clear = 0.0
	if %Chara.idiot: target_clear = 1.0
	top_back_fail.modulate.a = move_toward(top_back_fail.modulate.a, target_clear, delta * 4)

func _process(delta: float) -> void:
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

func pop_balloon(note: Dictionary):
	if note.has("roll_note") and note["roll_note"].has("note") and note["roll_note"]["note"] == 7:
		var rolln: Dictionary = note["roll_note"]
		var roll_type: int = rolln["note"]
		if roll_type == 7:
			SoundHandler.play_sound("geki.wav")
			add_note_to_gauge(7, true)
			create_score_diff(score_handler.calc_balloon_pop(score_real, 0, %Chara.gogo))
		chart.draw_data.erase(rolln.get("cached_index", chart.draw_data.find_key(rolln)))

func auto_play():
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
				add_note_to_gauge(type)
				# %Gauge.add_good()
			2:
				taiko.taiko_input(1, 1 if auto_kat_side else 0)
				taiko.combo += 1
				auto_kat_side = !auto_kat_side
				add_note_to_gauge(type)
				# %Gauge.add_good()
			3:
				taiko.combo += 1
				for side in range(2):
					taiko.taiko_input(0, side)
				add_note_to_gauge(type)
				# %Gauge.add_good()
			4:
				taiko.combo += 1
				for side in range(2):
					taiko.taiko_input(1, side)
				add_note_to_gauge(type)
				# %Gauge.add_good()
			5, 6, 7:
				roll = true
				roll_cnt = 0
				current_roll_note = note
			8:
				roll = false
				
		if type != 5 and type != 6 and type != 7 and type != 8: chart.draw_data.erase(note.get("cached_index", chart.draw_data.find_key(note)))

const JUDGEMENT_GREAT = 0.042
const JUDGEMENT_GOOD = 0.075
const JUDGEMENT_BAD = 0.108

var drumrolls: Array[bool] = [false, false, false, false, false, true, true, true, true, true, false, false, true, false]

func hit_note(type: int, time: float) -> JudgeType:
	if drumrolls[type]: return JudgeType.ROLL
	var judgetype: int = JudgeType.BAD
	if time - JUDGEMENT_GREAT <= elapsed and elapsed <= (time + JUDGEMENT_GREAT):
		judgetype = JudgeType.GOOD
	elif time - JUDGEMENT_GOOD <= elapsed and elapsed <= (time + JUDGEMENT_GOOD):
		judgetype = JudgeType.OK
	# Change score!
	if judgetype != JudgeType.BAD:
		taiko.combo += 1
		add_note_to_gauge(type, false, judgetype)
		%Chara.idiot = false
		if %Chara.state == %Chara.State.FAIL:
			%Chara.state = %Chara.State.IDLE
	else:
		taiko.combo = 0
		create_judge_effect(false, false, true)
		%Chara.idiot = true
		if %Chara.state == %Chara.State.IDLE:
			%Chara.state = %Chara.State.FAIL
	return judgetype as JudgeType

func check_note(check_type: int) -> JudgeType:
	var hit: JudgeType = JudgeType.BAD
	if current_note_list.size() <= 0: return hit
	var offset: int = 0
	while current_note_list.size() > 0 and not (current_note_list[-1-offset]["time"] > elapsed + JUDGEMENT_BAD):
		var note: Dictionary = current_note_list[-1-offset]
		var type: int = note["note"]
		var time: float = note["time"]
		var old_type: int = type
		match check_type:
			1:
				if type == 3:
					type = 1
			2:
				if type == 4:
					type = 2
		if type != check_type: 
			offset += 1
			continue
		type = old_type
		var result = hit_note(type, time)
		current_note_list.pop_back()
		if result == JudgeType.ROLL: 
			offset += 1
			continue
		chart.draw_data.erase(note.get("cached_index", chart.draw_data.find_key(note)))
		hit = result
		break
	return hit

func hit_don(player: int, event: InputEvent) -> int:
	if event.is_echo(): return -1
	if event.is_action_pressed("don_left_p%d" % [player]):
		return 0
	if event.is_action_pressed("don_right_p%d" % [player]):
		return 1
	return -1

func hit_kat(player: int, event: InputEvent) -> int:
	if event.is_echo(): return -1
	if event.is_action_pressed("kat_left_p%d" % [player]):
		return 0
	if event.is_action_pressed("kat_right_p%d" % [player]):
		return 1
	return -1

func hit_either(player: int, event: InputEvent) -> PackedInt64Array:
	if event.is_echo(): return [-1, -1]
	if event.is_action_pressed("don_left_p%d" % [player]):
		return [0, 0]
	if event.is_action_pressed("don_right_p%d" % [player]):
		return [0, 1]
	if event.is_action_pressed("kat_left_p%d" % [player]):
		return [1, 0]
	if event.is_action_pressed("kat_right_p%d" % [player]):
		return [1, 1]
	return [-1, -1]

func handle_lingering_notes():
	if current_note_list.size() <= 0: return
	while current_note_list.size() > 0 and current_note_list[-1]["time"] < elapsed:
		var note: Dictionary = current_note_list[-1]
		# Look, we can't detect if we should hit if we don't have one.
		if not note.has("time"): break
		if note.has("dummy"): break
		var type: int = note["note"]
		var time: float = note["time"]
		# Do not include special notes from now on.
		if type >= 999: break
		match type:
			5, 6, 7:
				roll = true
				roll_cnt = 0
				current_roll_note = note
				current_note_list.pop_back()
			8:
				# Still rolling????
				drumroll_count = 0
				if current_roll_note.get("note", 0) == 7 and roll:
					%Chara.fail_balloon()
				roll = false
				if note.has("roll_note") and note["roll_note"].has("note") and note["roll_note"]["note"] == 7:
					var rolln: Dictionary = note["roll_note"]
					chart.draw_data.erase(rolln.get("cached_index", chart.draw_data.find_key(rolln)))
					# print("DIE")
				current_note_list.pop_back()
		if time > elapsed - JUDGEMENT_BAD: break
		var result: JudgeType = hit_note(type, time)
		current_note_list.pop_back()
		if result == JudgeType.ROLL: break
		add_hit_to_gauge(result)
		branch_condition_count -= 1
		chart.draw_data.erase(note.get("cached_index", chart.draw_data.find_key(note)))

func add_hit_to_gauge(hit: JudgeType):
	if hit == JudgeType.GOOD:
		%Gauge.add_good()
		branch_condition_count += 1
	if hit == JudgeType.BAD:
		%Gauge.add_bad()
		# branch_condition_count -= 1
	if hit == JudgeType.OK:
		%Gauge.add_ok()
		branch_condition_count += 0.5
	branch_note_count += 1

func handle_note_input(player: int, event: InputEvent):
	if Globals.players_auto[player]: return
	player += 1 # Adjust for action names
	
	var res: int = hit_don(player, event)
	if res != -1 and not roll:
		var hit: JudgeType = check_note(1)
		taiko.taiko_input(0, res, 100, hit == JudgeType.GOOD)
		# add_hit_to_gauge(hit)
	res = hit_kat(player, event)
	if res != -1 and not roll:
		var hit: JudgeType = check_note(2)
		taiko.taiko_input(1, res, 100, hit == JudgeType.GOOD)
		# add_hit_to_gauge(hit)
	var roll_res: PackedInt64Array = hit_either(player, event)
	if roll_res[0] != -1 and roll and not current_roll_note.is_empty():
		res = hit_don(player, event)
		if res != -1: 
			taiko.taiko_input(0, res, 100, false)
			if current_roll_note.get("note", 0) == 5:
				create_score_diff(score_handler.calc_roll(score_real, 1, %Chara.gogo))
				add_note_to_gauge(1, true)
				roll_hits += 1
				drumroll_count += 1
			elif current_roll_note.get("note", 0) == 6:
				create_score_diff(score_handler.calc_roll(score_real, 3, %Chara.gogo))
				add_note_to_gauge(3, true)
				roll_hits += 1
				drumroll_count += 1
			elif current_roll_note.get("note", 0) == 7:
				if current_roll_note.has("balloon_count"):
					current_roll_note["balloon_count"] -= 1
					if current_roll_note["balloon_count"] <= 0:
						roll = false
						pop_balloon(current_roll_note["roll_tail_ref"])
						%Chara.pop_balloon()
					else:
						%Chara.start_balloon_animation()
						%Chara.use_balloon()
						create_score_diff(score_handler.calc_balloon(score_real, 0, %Chara.gogo))
		res = hit_kat(player, event)
		if res != -1: 
			taiko.taiko_input(1, res, 100, false)
			if current_roll_note.get("note", 0) == 5:
				create_score_diff(score_handler.calc_roll(score_real, 1, %Chara.gogo))
				add_note_to_gauge(2, true)
				drumroll_count += 1
			elif current_roll_note.get("note", 0) == 6:
				create_score_diff(score_handler.calc_roll(score_real, 3, %Chara.gogo))
				add_note_to_gauge(4, true)
				drumroll_count += 1

func _input(event: InputEvent) -> void:
	if not chart: return
	if audio.stream_paused: return
	
	handle_note_input(0, event)

func _physics_process(delta: float) -> void:
	if not chart: return
	
	if Input.is_action_just_pressed("pause"):
		$Pause.open()
	
	handle_play_events()
	handle_branch_timeline()
	evaluate_branch()
	
	if current_note_list.size() <= 0: return
	if Globals.players_auto[0]: auto_play()
	else: handle_lingering_notes()

func _on_timer_timeout() -> void:
	audio.play()

func _on_music_finished() -> void:
	# TODO results screen
	TransitionHandler.change_scene_to_file("uid://b8jopawilsvnu", true)

func _on_gauge_filled_soul() -> void:
	%Chara.clear = true
	if %Chara.state == %Chara.State.IDLE:
		%Chara.state = %Chara.State.CLEAR

func _on_gauge_unfilled_soul() -> void:
	%Chara.clear = false
	if %Chara.state == %Chara.State.CLEAR:
		%Chara.state = %Chara.State.IDLE

func _on_gauge_rainbow_soul() -> void:
	%Chara.state = %Chara.State.SPIN
	%Chara.rainbow = true

func _on_gauge_unrainbow_soul() -> void:
	%Chara.rainbow = false

func _on_taiko_combo_callout(combo: int) -> void:
	%Chara.do_combo_animation()
	$CalloutBalloon.show_combo(combo)
