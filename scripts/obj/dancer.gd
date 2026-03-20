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
@export var dancer_texture_prefix: String = "tetsuo"
@export var dancer_number: int = 0:
	set(value):
		if value == dancer_number: return
		dancer_number = mini(4, maxi(value, 0))

@export var state: DancerState = DancerState.APPEAR:
	set(value):
		if value == state: return
		state = value
		if is_inside_tree():
			_update_textures_and_intervals()
var beat: float = 0.0
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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
