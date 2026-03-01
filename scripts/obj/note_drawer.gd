extends Node2D
class_name TaikoNoteDrawer

var draw_list: Dictionary
var draw_data_offset: int = 0
var bar_list: Array[Dictionary]
var time: float = 0.0

@export var lane_texture: TextureRect

const notes: Array[Texture2D] = [
	null,													# Nothing
	preload("res://assets/game/notes/don.png"),				# Don
	preload("res://assets/game/notes/kat.png"),				# Kat
	preload("res://assets/game/notes/don_big.png"),			# Don (Big)
	preload("res://assets/game/notes/kat_big.png"),			# Kat (Big)
	preload("res://assets/game/notes/roll_head.png"),		# Roll head
	preload("res://assets/game/notes/roll_head_big.png"),	# Roll head (Big)
	preload("res://assets/game/notes/balloon_head.png"),	# Balloon head
	null,													# Roll/balloon end
]

var roll_body: Texture2D = preload("res://assets/game/notes/roll_body.png")
var roll_body_big: Texture2D = preload("res://assets/game/notes/roll_body_big.png")
var roll_tail: Texture2D = preload("res://assets/game/notes/roll_tail.png")
var roll_tail_big: Texture2D = preload("res://assets/game/notes/roll_tail_big.png")
var balloon_tail: Texture2D = preload("res://assets/game/notes/balloon_tail.png")
var bar_line: Texture2D = preload("res://assets/game/notes/bar.tres")
var bar_line_size: Vector2

var current_beat: float = 0.0
var bemani_scroll: bool = false
var speed_multiplier: Vector2 = Vector2.ONE

var lane_width: Vector2

func _ready() -> void:
	lane_width = get_viewport_rect().size - global_position.floor()
	bar_line_size = bar_line.get_size()

# Thanks to IID/IepIweidieng from the TJADB discord!
# (note_x, note_y) = scroll_modifier × ((scroll_x_t, scroll_y_t) × (time_note - time_current) + (scroll_x_b, scroll_y_b) × (beat_note - beat_current))

# scroll_[x/y]_t = scroll_[x/y] × (px_width_note_field / 4) × (bpm_note / 60 (s))  (#NMSCROLL), or otherwise 0
func get_note_position(ms, bpm, scroll: Vector2, beat: float):
	# print("HI")
	if bemani_scroll and ms >= time: 
		return get_note_hbscroll_position(scroll, beat)
	return Vector2((scroll.x * speed_multiplier.x * (lane_width.x/4) * (bpm / 60)) * (ms - time),
			(scroll.y * speed_multiplier.y * (lane_width.x/4) * (bpm / 60)) * (ms - time))

# scroll_[x/y]_b = {scroll_[x/y] (#HBSCROLL) or [1/0] (#BMSCROLL)} × (px_width_note_field / 4) (#HBSCROLL/#BMSCROLL), or otherwise 0
func get_note_hbscroll_position(scroll: Vector2, beat: float):
	return Vector2((scroll.x * speed_multiplier.x * (lane_width.x/4)) * (beat - current_beat),
			(scroll.y * speed_multiplier.y * (lane_width.x/4)) * (beat - current_beat))

func _draw() -> void:
	for note in bar_list:
		if not note.get("display", true): continue
		var pos = get_note_position(note["time"], note["bpm"], note["scroll"], note["beat_position"])
		if pos.x > lane_width.x + 96: continue
		if pos.x < -global_position.x: continue
		draw_set_transform(pos, pos.angle_to_point(Vector2.ZERO))
		var color: Color = Color.YELLOW if note.get("branch_start") else Color.WHITE
		draw_texture_rect(bar_line, Rect2(-bar_line_size / 2, bar_line_size), false, color)
	
	draw_set_transform(Vector2.ZERO)
	
	var arr = draw_list.keys()
	if arr.size() <= 0: return
	const MINIMUM_NOTE_COUNT: int = 512
	for i in range(maxi(0, arr.size() - MINIMUM_NOTE_COUNT), arr.size()):
		#if not draw_list.has(i): continue
		var note: Dictionary = draw_list[arr[i]]
		var type: int = note["note"]
		if type >= 999: continue
		var pos = get_note_position(note["time"], note["bpm"], note["scroll"], note["beat_position"])
		# print(pos)
		var col: Color = Color.WHITE
		if type != 8:
			if pos.x > lane_width.x + 96: continue
			if pos.x < - global_position.x - 96 and type != 7: continue
		if type < notes.size() and (notes[type] or type == 8):
			match type:
				8: # Roll end, these are handled differently
					var last_note: Dictionary = note["roll_note"]
					var last_type: int = last_note["note"]
					if last_type == 7: continue
					col = note["roll_color_mod"]
					# I think it's probably best we precalculate these
					# Doing this is not accurate to how TaikoJiro's rolls work
					# See: Oshama Scramble complex number chart
					var last_pos: Vector2 = get_note_position(last_note["time"], last_note["bpm"], last_note["scroll"], last_note["beat_position"])
					# if last_pos.x > 640+80: continue
					var graph: Texture2D = roll_body if last_type == 5 else roll_body_big
					var graph_size: Vector2 = graph.get_size()
					draw_set_transform(last_pos, last_pos.angle_to_point(pos))
					var dist: float = last_pos.distance_to(pos)
					# Draw tail body
					var rect = Rect2(-Vector2(0, graph_size.y / 2.0), Vector2(dist, graph_size.y)).abs()
					draw_texture_rect_region(graph, rect, Rect2(Vector2.ZERO, graph.get_size()), col)
					# Draw tail end
					graph = roll_tail if last_type == 5 else roll_tail_big
					rect = Rect2(Vector2(dist, -graph_size.y / 2.0), graph_size).abs()
					draw_set_transform(last_pos, last_pos.angle_to_point(pos))
					draw_texture_rect_region(graph, rect, Rect2(Vector2.ZERO, graph.get_size()), col)
					draw_set_transform(Vector2.ZERO)
				_:
					var graph: Texture2D = notes[type]
					var graph_size: Vector2 = graph.get_size()
					var roll_time: float =  note.get("roll_time", 0)
					if type == 7 and roll_time < time: pos = pos.max(Vector2.ZERO)
					draw_set_transform(pos - graph_size / 2)
					draw_texture_rect(graph, Rect2(Vector2.ZERO, graph_size), false)
					if type == 7:
						pos.x += graph_size.x
						graph = balloon_tail
						graph_size = graph.get_size()
						draw_set_transform(pos - graph_size / 2)
						draw_texture_rect(graph, Rect2(Vector2.ZERO, graph_size), false)

func _process(delta: float) -> void:
	lane_width = get_viewport_rect().size - global_position.floor()
	lane_texture.size.x = lane_width.x + global_position.x
	queue_redraw()
