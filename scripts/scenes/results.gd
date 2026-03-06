extends Control
class_name ResultsScreen

@onready var fade: AnimationPlayer = $Fade/AnimationPlayer
@onready var panels: Array[VBoxContainer] = [%Player1Panel]
@onready var scores: Array[MinimalMonoLabel] = [%P1Score]
@onready var note_hits: Array[MinimalMonoLabel] = [%P1NotesHit]
@onready var gauges: Array[TextureProgressBar] = [%P1Gauge]
@onready var percentages: Array[MinimalMonoLabel] = [%P1Percentage]
@onready var goods: Array[MinimalMonoLabel] = [%P1Goods]
@onready var oks: Array[MinimalMonoLabel] = [%P1Oks]
@onready var bads: Array[MinimalMonoLabel] = [%P1Bads]
@onready var rolls: Array[MinimalMonoLabel] = [%P1Rolls]
@onready var turning_things: Array[TextureRect] = [%P1TurnImage, %P2TurnImage]

var total_notes: int = 33892
var total_score: PackedFloat64Array = [1257360]
var total_percentage: PackedFloat64Array = [100]
var total_gauge: PackedFloat64Array = [100]

var hit_notes: PackedFloat64Array = [24592]
var hit_rolls: PackedFloat64Array = [100]
var hit_goods: PackedFloat64Array = [100]
var hit_oks: PackedFloat64Array = [50]
var hit_bads: PackedFloat64Array = [20]

var current_score: PackedFloat64Array = [0]
var current_percent: PackedFloat64Array = [0]
var current_percentages: PackedFloat64Array = [0]
var current_goods: PackedFloat64Array = [0]
var current_oks: PackedFloat64Array = [0]
var current_bads: PackedFloat64Array = [0]
var current_rolls: PackedFloat64Array = [0]

enum ResultsState {
	SEISEKI_HAPPYO,
	SCORE_TICK,
	NOTES_HIT,
	GOODS,
	OKS,
	BADS,
	ROLLS,
	DONE,
	WAITING
}

var state: ResultsState = ResultsState.SEISEKI_HAPPYO
var tick: bool = false
var count: float = 0.0

var title: String:
	set(value):
		if value == title: return
		title = value
		if is_inside_tree() and is_instance_valid(%Title):
			%Title.text = title
var subtitle: String:
	set(value):
		if value == subtitle: return
		subtitle = value
		if is_inside_tree() and is_instance_valid(%Subtitle):
			%Subtitle.text = subtitle
			%Subtitle.visible = not subtitle.is_empty()
var course: Array[TJAChartInfo.CourseType] = [TJAChartInfo.CourseType.ONI]:
	set(value):
		if value == course: return
		course = value
		if is_inside_tree(): _update_course()

const difficulty_colors: Dictionary[int, Color] = {
	-1: Color.WHITE,
	0: Color("#FF8463"),
	1: Color("#C6D65A"),
	2: Color("#8CBDDE"),
	3: Color("ff85e2"),
	4: Color("ed823b")
}

func _update_course():
	for i in range(Globals.players_entered.size()):
		var val: bool = Globals.players_entered[i]
		if not val: continue
		var diff: TJAChartInfo.CourseType = course[i]
		var icon: TextureRect = get_node("%%P%dDiffIcon" % [i + 1])
		var label: Label = get_node("%%P%dDiffName" % [i + 1])
		var panel: PanelContainer = get_node("%%P%dDiffContainer" % [i + 1])
		var diff_name: String = (TJAChartInfo.CourseType.find_key(diff) as String).to_pascal_case()
		icon.texture = SongSelectColumns.difficulty_icons[diff]
		label.text = diff_name
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
		style.bg_color = difficulty_colors[diff]

var results_music: Array[AudioStream] = [load("uid://c2c3wkg7ejqgp"), load("uid://0podvvpu8ixr")]
@onready var chara: Array[TaikoCharacter] = [$CanvasLayer/TextureRect]

func _ready() -> void:
	$AnimationPlayer.play("Enter")
	fade.play("FadeIn", -1, 99999)
	fade.advance(0)
	Globals.control_banner.hide()
	if Globals.players_entered == [false, false]:
		Globals.players_entered[0] = true
	await get_tree().create_timer(2.5).timeout
	_update_course()
	state = ResultsState.SCORE_TICK
	fade.play("FadeOut")
	$Music.stream = results_music.pick_random()
	$Music.play()
	await fade.animation_finished
	$CanvasLayer.layer = 0

var fail: Array[bool] = [false, false]
func check_fail(player: int):
	var back: TextureRect = $Back/Fail
	if gauges[player].value >= TaikoGauge.clear_start:
		back = $Back/Clear
		chara[player].state = TaikoCharacter.State.SPIN
		chara[player].gogo = true
		SoundHandler.play_sound("result/norma_clear.wav")
	else:
		fail[player] = true
		chara[player].state = TaikoCharacter.State.FAIL
		SoundHandler.play_sound("result/norma_failed.wav")
	var back_tween: Tween = create_tween()
	back_tween.set_parallel(true)
	back_tween.tween_property(back, "modulate:a", 1.0, 0.4)
	if total_notes == hit_goods[player] + hit_oks[player]:
		back_tween.tween_callback(SoundHandler.play_sound.bind("result/fullcombo.wav")).set_delay(2.5)

var fast: bool = false

func increase_value(player: int, varname: StringName, labelname: StringName, amount: float = 1, max: float = 0, format: String = "%d"):
	var arr: PackedFloat64Array = get(varname)
	var wait: bool = false
	if fast: amount = 1.0
	arr[player] = lerpf(0, max, amount)
	if arr[player] >= max:
		arr[player] = max
		wait = true
	var val: float = arr[player]
	if labelname == "scores":
		val = (floori(arr[player]) / 10) * 10
	var label: MinimalMonoLabel = get(labelname)[player] as MinimalMonoLabel
	label.text = format % [floori(val)]
	if labelname == "note_hits":
		current_percentages[player] = lerpf(0.0, floori((float(hit_notes[player]) / float(total_notes)) * 100), amount)
		percentages[player].text = "%d%%" % [clampf(current_percentages[player], 0, 100)]
		gauges[player].value = lerpf(0.0, total_gauge[player], amount)
	if wait:
		if not fast:
			SoundHandler.play_sound("dong.wav")
		var prev: ResultsState = state
		state = ResultsState.WAITING
		if not fast:
			await get_tree().create_timer(0.5).timeout
		count = 0.0
		state = ((prev as int) + 1) as ResultsState
		if state == ResultsState.DONE:
			check_fail(player)
		else:
			var t: Tween = create_tween()
			chara[player].frame = 7
			t.tween_callback(func(): chara[player].frame = 0).set_delay(0.15)
	elif not fast:
		SoundHandler.play_sound("result/count.wav")

func _physics_process(delta: float) -> void:
	for turny_thing in turning_things:
		turny_thing.pivot_offset_ratio = Vector2.ONE * 0.5
		turny_thing.rotation_degrees = Engine.get_process_frames() / 10.0
	
	var elapsed: float = $Music.get_playback_position() + AudioServer.get_time_since_last_mix()
	if not $Music.stream: elapsed = 0.0
	for i in range(Globals.players_entered.size()):
		var val: bool = Globals.players_entered[i]
		if not val: continue
		var donchan: TaikoCharacter = chara[i]
		if $Music.stream:
			donchan.bpm = ($Music.stream as AudioStreamOggVorbis).bpm
		if $Music.stream == results_music[1]:
			elapsed -= 0.25
		donchan.beat = maxf(0.0, elapsed * (donchan.bpm / 60.0) / (2.0 if fail[i] else 1.0))
	
	if state == ResultsState.WAITING or state == ResultsState.SEISEKI_HAPPYO: return
	
	if state == ResultsState.DONE:
		if Input.is_action_just_pressed("don_left_p1") or Input.is_action_just_pressed("don_right_p1"):
			process_mode = Node.PROCESS_MODE_DISABLED
			SoundHandler.play_sound("dong.wav")
			TransitionHandler.change_scene_to_file("uid://b8jopawilsvnu", true)
			return
	else:
		if (Input.is_action_just_pressed("don_left_p1") or Input.is_action_just_pressed("don_right_p1")) and not fast:
			SoundHandler.play_sound("dong.wav")
			fast = true
	
	tick = not tick
	if tick:
		count += delta
		for i in range(Globals.players_entered.size()):
			var val: bool = Globals.players_entered[i]
			if not val: continue
			var amt: float = count
			match state:
				ResultsState.SCORE_TICK:
					increase_value(i, "current_score", "scores", amt, total_score[i])
				ResultsState.NOTES_HIT:
					increase_value(i, "current_percent", "note_hits", amt, hit_notes[i])
				ResultsState.GOODS:
					increase_value(i, "current_goods", "goods", amt, hit_goods[i])
				ResultsState.OKS:
					increase_value(i, "current_oks", "oks", amt, hit_oks[i])
				ResultsState.BADS:
					increase_value(i, "current_bads", "bads", amt, hit_bads[i])
				ResultsState.ROLLS:
					increase_value(i, "current_rolls", "rolls", amt, hit_rolls[i])
