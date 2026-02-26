extends Resource
class_name BranchSection

@export var condition: TJAChartInfo.BranchCondition = TJAChartInfo.BranchCondition.p
@export var expert_requirement: int
@export var master_requirement: int
@export var start_time: float
@export var index: int

@export var notes: Array[Dictionary] = []
@export var barlines: Array[Dictionary] = []
@export var command_log: Array[Dictionary] = []
@export var positive_delay_log: Array[Dictionary] = []
@export var bpm_log: Array[Dictionary] = []

func _sort_notes(a: Dictionary, b: Dictionary):
	if a["time"] == b["time"]:
		# Use index as a tie breaker
		return a.get("index", 0) > b.get("index", 0)
	return a["time"] > b["time"]

func sort_and_create_drawdata():
	#var sorted: Array[Dictionary] = notes.duplicate()
	#for i in range(0, sorted.size()):
		#notes[i]["cached_index"] = i
		#draw_data[i] = sorted[i]
	notes.sort_custom(_sort_notes)
