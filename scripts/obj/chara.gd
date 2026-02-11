@tool
extends TextureRect
class_name TaikoCharacter

enum State {
	IDLE_STILL,
	IDLE,
	COMBO,
	GOGO,
}

@export var state: State = State.IDLE_STILL:
	set(v): 
		var changed: bool = false
		if v != state:
			frame = 0; _last_interval = 0; _current_interval = 0;
			changed = true
		state = v; 
		if changed: _update_texture();
@export var frame: int = 0:
	set(v): 
		if v != frame:
			frame = v;
			_update_texture()

func _update_texture():
	if idle_texture == null: return
	var atlas: AtlasTexture = AtlasTexture.new()
	match state:
		State.IDLE_STILL, State.IDLE:
			atlas.atlas = idle_texture
			atlas.region = Rect2(0, 0, idle_texture.get_width() / idle_frames, idle_texture.get_height())
		State.COMBO:
			atlas.atlas = combo_texture
			atlas.region = Rect2(0, 0, combo_texture.get_width() / combo_frames, combo_texture.get_height())
		State.GOGO:
			atlas.atlas = gogo_texture
			atlas.region = Rect2(0, 0, gogo_texture.get_width() / gogo_frames, gogo_texture.get_height())
	texture = atlas
	var max_frames: int = 0
	match state:
		State.IDLE_STILL:
			max_frames = idle_frames
		State.IDLE:
			max_frames = idle_frames
		State.COMBO:
			max_frames = combo_frames
		State.GOGO:
			max_frames = gogo_frames
	var f = wrapi(frame, 0, max_frames)
	var tex_width: int = atlas.atlas.get_width()
	atlas.region.position.x = f * (tex_width / max_frames)

@export_group("Idle", "idle_")
@export var idle_texture: Texture2D:
	set(v): idle_texture = v; _update_texture()
@export var idle_frames: int = 1:
	set(v): idle_frames = v; _update_texture()
@export var idle_speed: float = 1.0

@export_group("10 Combo", "combo_")
@export var combo_texture: Texture2D:
	set(v): combo_texture = v; _update_texture()
@export var combo_frames: int = 1:
	set(v): combo_frames = v; _update_texture()
@export var combo_speed: float = 1.0

@export_group("GoGo Time", "gogo_")
@export var gogo_texture: Texture2D:
	set(v): gogo_texture = v; _update_texture()
@export var gogo_frames: int = 1:
	set(v): gogo_frames = v; _update_texture()
@export var gogo_speed: float = 1.0

var _current_interval: int = 0
var _last_interval: int = 0

var beat: float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	var max_frames: int = 0
	var speed: float = 1.0
	match state:
		State.IDLE_STILL:
			max_frames = idle_frames
			speed = 1.0
		State.IDLE:
			max_frames = idle_frames
			speed = idle_speed
		State.COMBO:
			max_frames = combo_frames
			speed = combo_speed
		State.GOGO:
			max_frames = gogo_frames
			speed = gogo_speed
	_current_interval = floori(beat / ((1.0 / (max_frames)) * (1.0 / speed)))
	if _current_interval != _last_interval:
		_last_interval = _current_interval
		frame += 1
	
	$Label.text = "State: %s" % [State.find_key(state)]
	$Label2.text = "Frame: %d" % [frame]
	$Label3.text = "Interval: %02d, Last: %02d" % [_current_interval, _last_interval] 
