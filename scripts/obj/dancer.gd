@tool
extends Control
class_name TaikoDancer

enum AppearPattern {
	STILL, # in Love
	VERTICAL,
}

enum DancerState {
	APPEAR,
	LOOP,
	DISAPPEAR,
}

const MAX_DANCERS: int = 5
const DANCERS_PATH: String = "res://assets/game/dancers/"

static var DANCERS_CACHE: Dictionary[String, Array] = {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var overlay: Sprite2D = $Overlay
@export var dancer_texture_prefix: String = "tetsuo"
@export var dancer_number: int = 0:
	set(value):
		if value == dancer_number: return
		dancer_number = mini(4, maxi(value, 0))
		if is_inside_tree():
			_update_textures_and_intervals()

@export var state: DancerState = DancerState.APPEAR:
	set(value):
		if value == state: return
		state = value
		if is_inside_tree():
			_update_textures_and_intervals()
var beat: float = 0.0
var index: int = 0
var current_interval: float
var current_order: PackedInt64Array

var appear_interval: float = 4.0
var appear_order: PackedInt64Array
var appear_frames: Vector2i
var appear_pattern: AppearPattern = AppearPattern.STILL

var loop_interval: float = 4.0
var loop_order: PackedInt64Array
var loop_frames: Vector2i

var disappear_interval: float = 4.0
var disappear_order: PackedInt64Array
var disappear_frames: Vector2i
var disappear_pattern: AppearPattern = AppearPattern.STILL

var shakushi: bool = false
var overlay_order: PackedInt64Array

var auto_beat: bool = false
var bpm: float = 120.0

func _update_textures_and_intervals():
	var lowercase_state: String = (DancerState.find_key(state) as String).to_lower()
	current_interval = get("%s_interval" % [lowercase_state])
	current_order = get("%s_order" % [lowercase_state])
	var frames: Vector2i = get("%s_frames" % [lowercase_state])
	sprite.hframes = frames.x
	sprite.vframes = frames.y
	var key: String = dancer_texture_prefix + "_" + lowercase_state
	if DANCERS_CACHE[key].size() - 1 > dancer_number:
		sprite.texture = DANCERS_CACHE[key][dancer_number]
	
	index = 0
	sprite.frame = 0
	sprite.offset = Vector2.ZERO
	overlay.offset = Vector2.ZERO
	
	var conf_path: String = DANCERS_PATH + dancer_texture_prefix + "/dancer.cfg"
	if not FileAccess.file_exists(conf_path): return
	var conf: ConfigFile = ConfigFile.new()
	conf.load(conf_path)
	
	var id: String = "dancer%d" % [dancer_number]
	sprite.offset = conf.get_value("offsets", id, Vector2.ZERO)
	overlay.offset = sprite.offset
	var overlay_enabled: bool = conf.get_value("overlays", "%s_overlay" % [id], false)
	if overlay_enabled:
		var path: String = DANCERS_PATH + dancer_texture_prefix
		overlay.texture = load("%s/%d_overlay.png" % [path, dancer_number])
		overlay.hframes = conf.get_value("overlays", "%s_overlay_hframes" % [id], 1)
		overlay.vframes = conf.get_value("overlays", "%s_overlay_vframes" % [id], 1)
		overlay.show()
		shakushi = conf.get_value("overlays", "%s_overlay_shakushi" % [id], false)
		overlay_order = conf.get_value("overlays", "%s_overlay_order" % [id], [])
	else:
		overlay.hide()

func _init_dancers():
	if DirAccess.dir_exists_absolute(DANCERS_PATH + dancer_texture_prefix):
		for i in range(0, MAX_DANCERS):
			for state_name in DancerState.keys():
				var id: String = "%d_%s" % [i, state_name.to_lower()]
				var path: String = "%s/%s.png" % [DANCERS_PATH + dancer_texture_prefix, id]
				var key: String = dancer_texture_prefix + "_" + state_name.to_lower()
				if not DANCERS_CACHE.get(key):
					DANCERS_CACHE[key] = []
				if DANCERS_CACHE[key].size() >= i:
					DANCERS_CACHE[key].push_back(load(path))
	
	if FileAccess.file_exists(DANCERS_PATH + dancer_texture_prefix + "/dancer.cfg"):
		var conf: ConfigFile = ConfigFile.new()
		conf.load(DANCERS_PATH + dancer_texture_prefix + "/dancer.cfg")
		for state_name in DancerState.keys():
			var real_state: String = state_name.to_lower()
			set("%s_interval" % [real_state], conf.get_value(real_state, "interval"))
			set("%s_order" % [real_state], conf.get_value(real_state, "order"))
			var frames: Vector2i = Vector2i(conf.get_value(real_state, "hframes"), conf.get_value(real_state, "vframes"))
			set("%s_frames" % [real_state], frames)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_init_dancers()
	_update_textures_and_intervals()
	auto_beat = get_tree().current_scene == self

var _last_interval: int = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	
	if auto_beat:
		var elapsed: float = Time.get_ticks_msec() / 1000.0
		beat = elapsed * (bpm / 60)
	
	var _current_interval: int = floori(beat * (current_interval / 4.0))
	if _current_interval != _last_interval:
		_last_interval = _current_interval
		index = _current_interval % current_order.size()
		sprite.frame = current_order[index] - 1
		if overlay_order.size() > 0:
			overlay.frame = overlay_order[sprite.frame] - 1
