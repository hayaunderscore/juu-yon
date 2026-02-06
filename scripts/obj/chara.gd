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
	set(v): state = v; _update_texture()
@export var frame: int = 0:
	set(v): frame = v; _update_texture()

func _update_texture():
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

@export_group("10 Combo", "combo_")
@export var combo_texture: Texture2D:
	set(v): combo_texture = v; _update_texture()
@export var combo_frames: int = 1:
	set(v): combo_frames = v; _update_texture()

@export_group("GoGo Time", "gogo_")
@export var gogo_texture: Texture2D:
	set(v): gogo_texture = v; _update_texture()
@export var gogo_frames: int = 1:
	set(v): gogo_frames = v; _update_texture()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
