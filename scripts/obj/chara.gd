@tool
extends TextureRect
class_name TaikoCharacter

enum State {
	IDLE_STILL,
	IDLE,
	COMBO,
	GOGO,
	SPIN,
	CLEAR,
	FAIL,
	MISC,
	BALLOON,
	BALLOON_POP,
	BALLOON_FAIL,
}

@export var player_number: int = 1
@export var state: State = State.IDLE_STILL:
	set(v): 
		if _cant_change_state and not Engine.is_editor_hint(): return
		var changed: bool = false
		if gogo and v == State.IDLE:
			v = State.GOGO
		if clear and v == State.IDLE:
			v = State.CLEAR
		if idiot and v == State.IDLE:
			v = State.FAIL
		if v != state:
			frame = 0; _last_interval = 0; _current_interval = 0;
			changed = true
		state = v; 
		if state == State.SPIN:
			_cant_change_state = true
		if changed: _update_texture();
@export var frame: int = 0:
	set(v): 
		if v != frame:
			frame = v;
			_update_texture()

var _do_not_update: bool = false

@warning_ignore_start("integer_division")
func _update_texture():
	if _do_not_update: return
	if idle_texture == null: return
	var atlas: AtlasTexture
	# We do NOT need a new texture if we already have an atlas texture!
	if texture: atlas = texture
	else: atlas = AtlasTexture.new()
	var state_key: String = (State.find_key(state) as String).to_lower()
	if state_key == "idle_still": state_key = "idle"
	if state_key == "balloon": state_key = "idle"
	if state_key == "balloon_pop": state_key = "misc"
	if state_key == "balloon_fail": state_key = "fail"
	var tex: Texture2D = get(state_key + "_texture")
	atlas.atlas = tex
	atlas.region = Rect2(0, 0, tex.get_width() / get(state_key + "_frames"), tex.get_height())
	texture = atlas
	var max_frames: int = get(state_key + "_frames")
	var f = wrapi(frame, 0, max_frames)
	var tex_width: int = atlas.atlas.get_width()
	atlas.region.position.x = f * (tex_width / max_frames)
@warning_ignore_restore("integer_division")

@export_group("Idle", "idle_")
@export var idle_texture: Texture2D:
	set(v): idle_texture = v; _update_texture()
@export var idle_frames: int = 1:
	set(v): idle_frames = v; _update_texture()
@export var idle_speed: float = 1.0
@export var idle_offset: Vector2 = Vector2.ZERO

@export_group("10 Combo", "combo_")
@export var combo_texture: Texture2D:
	set(v): combo_texture = v; _update_texture()
@export var combo_frames: int = 1:
	set(v): combo_frames = v; _update_texture()
@export var combo_speed: float = 1.0
@export var combo_offset: Vector2 = Vector2.ZERO

@export_group("GoGo Time", "gogo_")
@export var gogo_texture: Texture2D:
	set(v): gogo_texture = v; _update_texture()
@export var gogo_frames: int = 1:
	set(v): gogo_frames = v; _update_texture()
@export var gogo_speed: float = 1.0
@export var gogo_offset: Vector2 = Vector2.ZERO

@export_group("Spin", "spin_")
@export var spin_texture: Texture2D:
	set(v): spin_texture = v; _update_texture()
@export var spin_frames: int = 1:
	set(v): spin_frames = v; _update_texture()
@export var spin_speed: float = 1.0
@export var spin_offset: Vector2 = Vector2.ZERO

@export_group("Clear", "clear_")
@export var clear_texture: Texture2D:
	set(v): clear_texture = v; _update_texture()
@export var clear_frames: int = 1:
	set(v): clear_frames = v; _update_texture()
@export var clear_speed: float = 1.0
@export var clear_offset: Vector2 = Vector2.ZERO

@export_group("Fail", "fail_")
@export var fail_texture: Texture2D:
	set(v): fail_texture = v; _update_texture()
@export var fail_frames: int = 1:
	set(v): fail_frames = v; _update_texture()
@export var fail_speed: float = 1.0
@export var fail_offset: Vector2 = Vector2.ZERO

@export_group("Miscellaneous Frames", "misc_")
@export var misc_texture: Texture2D:
	set(v): misc_texture = v; _update_texture()
@export var misc_frames: int = 1:
	set(v): misc_frames = v; _update_texture()
@export var misc_offset: Vector2 = Vector2.ZERO
var misc_speed: float = 1.0
var balloon_frame: int = 7
var balloon_offset: Vector2 = Vector2(120, 100)

var _current_interval: int = 0
var _last_interval: int = 0
var _combo_tween: Tween
var _cant_change_state: bool = false

var beat: float = 0
var bpm: float = 120
var gogo: bool = false
var clear: bool = false
var idiot: bool = false
var rainbow: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_editor_hint(): return
	# Get textures based on the selected skin
	var skin: String = Globals.player_skins[player_number - 1]
	# Read config file
	var config: ConfigFile = ConfigFile.new()
	var base_path: String = ""
	# Check if its available in the user://charas/ folder
	if DirAccess.dir_exists_absolute("user://charas/" + skin):
		var err: Error = config.load("user://charas/%s/chara.cfg" % [skin])
		if err != Error.OK:
			printerr("Invalid/nonexistent chara.cfg file for %s!" % [skin])
			return
		else:
			base_path = "user://charas"
	# Check for our resources
	if DirAccess.dir_exists_absolute("res://assets/game/chara/" + skin):
		config.load("res://assets/game/chara/%s/chara.cfg" % [skin])
		base_path = "res://assets/game/chara"
	# Still nothing? Abort!
	if config.get_sections().size() == 0: 
		Globals.log("CHARA", "Character skin doesn't exist!")
		return
	
	# Load character images
	_do_not_update = true # Don't update everytime yet!
	for state_key in State.keys():
		var state_string: String = (state_key as String).to_lower()
		if state_string == "idle_still": continue
		if state_string == "balloon": continue
		if state_string == "balloon_pop": continue
		if state_string == "balloon_fail": continue
		var sec: String = state_string.to_pascal_case()
		if config.has_section(sec):
			Globals.log("CHARA", "Loading %s state definition for skin %s" % [state_string, skin])
			var tex: Texture2D = get("%s_texture" % [state_string])
			var tex_path: String = "%s/%s/%s.png" % [base_path, skin, state_string]
			if ResourceLoader.exists(tex_path):
				tex = load(tex_path)
			elif FileAccess.file_exists(tex_path):
				tex = ImageTexture.create_from_image(Image.load_from_file(tex_path))
			set("%s_texture" % [state_string], tex)
			set("%s_frames" % [state_string], config.get_value(sec, "frames", get("%s_frames" % [state_string])))
			set("%s_speed" % [state_string], config.get_value(sec, "speed", get("%s_speed" % [state_string])))
			set("%s_offset" % [state_string], config.get_value(sec, "offset", get("%s_offset" % [state_string])))
			if sec == "misc" and config.has_section_key(sec, "balloon_frame"):
				balloon_frame = config.get_value(sec, "balloon_frame", balloon_frame)
			if sec == "misc" and config.has_section_key(sec, "balloon_offset"):
				balloon_offset = config.get_value(sec, "balloon_offset", balloon_offset)
	_do_not_update = false
	_update_texture()

func do_combo_animation(height: float = 24, return_to_idle: bool = true):
	if gogo and state != State.SPIN: return
	if state >= State.BALLOON: return
	if state == State.SPIN and frame != spin_frames - 1: return
	var prev: State = state
	_cant_change_state = false
	state = State.COMBO
	_cant_change_state = true
	# Use spin frame if our previous state was a spin
	if prev == State.SPIN:
		var atlas: AtlasTexture = texture as AtlasTexture
		atlas.atlas = spin_texture
		atlas.region = Rect2((spin_frames - 1) * (spin_texture.get_width() / spin_frames), 0, spin_texture.get_width() / spin_frames, spin_texture.get_height())
		spin_current_frame = 0
	if _combo_tween: _combo_tween.custom_step(9999); _combo_tween.kill()
	var cur_y: float = position.y
	_combo_tween = create_tween()
	_combo_tween.tween_property(self, "position:y", position.y - height, minf(30 / bpm, 1.0)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_combo_tween.tween_property(self, "position:y", cur_y, minf(30 / bpm, 1.0)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_combo_tween.tween_callback(func(): _cant_change_state = false)
	if return_to_idle: 
		_combo_tween.tween_property(self, "state", State.IDLE, 0)

func set_alpha(alpha: float):
	var sh: ShaderMaterial = material as ShaderMaterial
	sh.set_shader_parameter("alpha", alpha)

@onready var balloon_spr: Sprite2D = $Balloon
func start_balloon_animation():
	if state == State.BALLOON: return
	if state == State.BALLOON_POP:
		if _balloon_tween: _balloon_tween.custom_step(9999); _balloon_tween.kill()
	state = State.BALLOON
	z_index += 2
	_cant_change_state = true
	balloon_spr.frame = 0
	balloon_spr.offset = balloon_offset
	balloon_spr.show()
	frame = 0

var _balloon_tween: Tween
func use_balloon():
	if _balloon_tween: _balloon_tween.kill()
	_balloon_tween = create_tween()
	_balloon_tween.tween_property(self, "frame", balloon_frame, 0)
	_balloon_tween.tween_property(self, "frame", 0, 0).set_delay(0.05)
	balloon_spr.frame = clampi(balloon_spr.frame + 1, 0, balloon_spr.hframes - 3)

func pop_balloon():
	if _balloon_tween: _balloon_tween.kill()
	_cant_change_state = false
	state = State.BALLOON_POP
	_cant_change_state = true
	frame = 1 # Second frame of MISC animation...
	balloon_spr.frame = balloon_spr.hframes - 1
	_balloon_tween = create_tween()
	var cur_y: float = position.y
	_balloon_tween.tween_property(self, "position:y", position.y - 32, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_balloon_tween.tween_callback(balloon_spr.hide)
	_balloon_tween.tween_property(self, "position:y", cur_y, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_balloon_tween.tween_method(set_alpha, 1.0, 0.0, 0.1).set_delay(0.3)
	_balloon_tween.tween_callback(func(): 
		_cant_change_state = false
		state = State.IDLE
		z_index -= 2
	)
	_balloon_tween.tween_method(set_alpha, 0.0, 1.0, 0.05)

func fail_balloon():
	if _balloon_tween: _balloon_tween.kill()
	_cant_change_state = false
	state = State.BALLOON_FAIL
	_cant_change_state = true
	frame = 0
	_balloon_tween = create_tween()
	balloon_spr.hide()
	_balloon_tween.tween_property(self, "frame", 1, 0).set_delay(0.1)
	_balloon_tween.tween_method(set_alpha, 1.0, 0.0, 0.1).set_delay(0.4)
	_balloon_tween.tween_callback(func(): 
		_cant_change_state = false
		state = State.IDLE
		z_index -= 2
	)
	_balloon_tween.tween_method(set_alpha, 0.0, 1.0, 0.05)

var spin_current_frame: int = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	var state_key: String = (State.find_key(state) as String).to_lower()
	if state_key == "idle_still": state_key = "idle"
	if state_key == "balloon": state_key = "idle"
	if state_key == "balloon_pop": state_key = "misc"
	if state_key == "balloon_fail": state_key = "fail"
	var max_frames: int = get(state_key + "_frames")
	var speed: float = get(state_key + "_speed")
	var offset: Vector2 = get(state_key + "_offset")
	if state >= State.BALLOON:
		offset = balloon_offset
	_current_interval = floori(beat / ((1.0 / (max_frames)) * (1.0 / speed)))
	if _current_interval != _last_interval:
		_last_interval = _current_interval
		if state != State.MISC and state != State.IDLE_STILL and state != State.BALLOON and state != State.BALLOON_POP and state != State.BALLOON_FAIL:
			if state != State.SPIN:
				frame = (_current_interval % max_frames)
			else:
				# Compared to other states, we want the full length of the spin state to go
				frame = spin_current_frame
				spin_current_frame += 1
				if spin_current_frame >= spin_frames - 1:
					do_combo_animation()
	
	if material:
		var sh: ShaderMaterial = material as ShaderMaterial
		# Fun fact about the full gauge tint- it seems to switch
		# between additive and traditional lerp color mixing
		# So emulate that
		if rainbow:
			var rprev: float = sh.get_shader_parameter("lerp_to_add")
			var rtarget: float = 0.0
			if state == State.GOGO:
				if (frame / 4) % 2 == 0:
					rtarget = 1.0
			elif frame % 2 == 0:
				rtarget = 1.0
			sh.set_shader_parameter("lerp_to_add", lerpf(rprev, rtarget, delta*8))
		# Transition the yellow tint when entering
		var prev: float = sh.get_shader_parameter("mixture")
		var target: float = 0.0 if not rainbow else 0.5
		sh.set_shader_parameter("mixture", lerpf(prev, target, delta*8))
		# Offset the character
		# Yes I did this in shader over just putting this in a subnode
		sh.set_shader_parameter("offset", offset)
		# print("HI")
	
	# $Label.text = "State: %s" % [State.find_key(state)]
	# $Label2.text = "Frame: %d" % [frame]
	# $Label3.text = "Interval: %02d, Last: %02d" % [_current_interval, _last_interval] 
