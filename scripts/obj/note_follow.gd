extends PathFollow2D

var firework_scene: PackedScene = preload("uid://cs0tdie35o5om")
var type: int
var balloon: bool = false

var interval: int = randi_range(0, 2)
func _physics_process(delta: float) -> void:
	if not (type == 3 or type == 4): return
	if balloon: return
	if interval % 2 == 0 and progress_ratio > 0.1 and not $AnimationPlayer.is_playing():
		var firework: TaikoFirework = firework_scene.instantiate()
		firework.type = TaikoFirework.FireworkType.RED if type == 3 else TaikoFirework.FireworkType.BLUE
		firework.global_position = global_position
		firework.z_index = -1
		firework.scale = Vector2.ONE * (2.0 - progress_ratio) * 0.85
		add_sibling(firework)
	interval += 1
