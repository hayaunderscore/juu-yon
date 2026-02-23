extends ColorRect
class_name TaikoControlBanner

@onready var taikos: Array[SelectTaiko] = [
	%TaikoP1, %TaikoP2
]
@onready var hint_labels: Array[Label] = [
	%ControlLabelP1, %ControlLabelP2
]
@export var side_active_at_start: bool = true
@export var entry_mode: bool = false:
	set(value): 
		if value == entry_mode: return
		entry_mode = value
		for i in taikos.size():
			var taiko: SelectTaiko = taikos[i]
			taiko.entry_mode = entry_mode

signal don_pressed(id)
signal kat_pressed(id, dir)
signal player_entry(id)

func active() -> bool:
	return visible

func _ready() -> void:
	for i in taikos.size():
		var taiko: SelectTaiko = taikos[i]
		taiko.side_active = side_active_at_start
		taiko.player = i
		taiko.entry_mode = entry_mode
		taiko.don_pressed.connect(func(id):
			don_pressed.emit(id)
			if entry_mode and not Globals.players_entered[id]:
				hint_labels[id].hide()
				Globals.players_entered[id] = true
				taiko.visible = true
				player_entry.emit(id)
		)
		taiko.kat_pressed.connect(func(id, dir):
			kat_pressed.emit(id, dir)
		)

func activate():
	for i in taikos.size():
		var taiko: SelectTaiko = taikos[i]
		if Globals.players_entered[i]:
			taiko.active = true

func deactivate():
	for i in taikos.size():
		var taiko: SelectTaiko = taikos[i]
		if Globals.players_entered[i]:
			taiko.active = false

func activate_side():
	for i in taikos.size():
		var taiko: SelectTaiko = taikos[i]
		if Globals.players_entered[i]:
			taiko.side_active = true

func deactivate_side():
	for i in taikos.size():
		var taiko: SelectTaiko = taikos[i]
		if Globals.players_entered[i]:
			taiko.side_active = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("auto_p1") and Globals.players_entered[0]:
		Globals.players_auto[0] = not Globals.players_auto[0]
		$Player1/AutoIcon.visible = Globals.players_auto[0]
	if Input.is_action_just_pressed("auto_p2") and Globals.players_entered[1]:
		Globals.players_auto[1] = not Globals.players_auto[1]
		$Player1/AutoIcon.visible = Globals.players_auto[1]
	
	if not active():
		for i in taikos.size():
			var taiko: SelectTaiko = taikos[i]
			taiko.full_active = false
		return
	else:
		for i in taikos.size():
			var taiko: SelectTaiko = taikos[i]
			taiko.full_active = true
	for label in hint_labels:
		label.modulate.a = minf(1.0, sin(Engine.get_physics_frames() / 30.0) + 0.5)
