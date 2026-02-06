@tool
extends Panel
class_name BumpinPanel

var overrided: bool = false
@export var note_texture: Texture2D = preload("res://assets/game/notes/don.png"):
	set(v):
		note_texture = v
		if get_node_or_null("TextureRect"):
			$TextureRect.texture = note_texture
@export var color: Color = Color.from_string("#F84828", Color.WHITE):
	set(v):
		color = v
		if get_node_or_null("MarginContainer/PanelContainer"):
			var style_box: StyleBoxFlat = $MarginContainer/PanelContainer.get_theme_stylebox("panel") as StyleBoxFlat
			if not overrided:
				overrided = true
				var duplicated: StyleBoxFlat = style_box.duplicate()
				$MarginContainer/PanelContainer.add_theme_stylebox_override("panel", duplicated)
				style_box = duplicated
			style_box.bg_color = color
@export_multiline var text: String = "あと   コインで\n参加できます":
	set(v):
		text = v
		if get_node_or_null("MarginContainer/PanelContainer/MarginContainer/Label"):
			$MarginContainer/PanelContainer/MarginContainer/Label.text = text

func _ready() -> void:
	var style_box: StyleBoxFlat = $MarginContainer/PanelContainer.get_theme_stylebox("panel") as StyleBoxFlat
	$MarginContainer/PanelContainer.add_theme_stylebox_override("panel", style_box.duplicate())
	$AnimationPlayer.play("Bump")

func _process(_delta: float) -> void:
	pivot_offset = size / 2.0

var disabled: bool = false
func disable():
	if disabled: return
	disabled = true
	pivot_offset = size / 2.0
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale:x", 2, 0.4)
	tween.tween_property(self, "scale:y", 0, 0.4)
	tween.set_trans(Tween.TRANS_SINE)
	# tween.tween_property(self, "modulate:a", 0, 0.4)
