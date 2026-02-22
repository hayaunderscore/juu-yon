extends Resource
class_name TJAChartInfo

enum CourseType {
	## INVALID
	INVALID = -1,
	## The Easy difficulty.
	EASY,
	## The Normal difficulty.
	NORMAL,
	## The Hard difficulty.
	HARD,
	## The Oni/Extreme difficulty.
	## This is usually the default for most single-course charts.
	ONI,
	## Usually for variations of existing charts, this is now reserved as Ura Oni (Oni Inner) difficulty.
	EDIT, # Or Ura-Oni
	## Refers to "Taiko Tower" notecharts, where roll notes are drawn on top of don and kat notes.
	TOWER,
	## Used for Dan-Dojo mode. Unused.
	DAN,
}

enum ChartFlags {
	NONE,
	BMSCROLL = (1 << 0),
	HBSCROLL = (1 << 1),
	BRANCHFUL = (1 << 2),
}

enum NoteType {
	NONE,
	DON,
	KAT,
	BIG_DON,
	BIG_KAT,
	ROLL,
	BIG_ROLL,
	BALLOON,
	END_ROLL,
	KUSADAMA,
	# OpenTaiko-Outfox standard
	SWAP,	# G
	BOMB,	# C
	FUSE,	# D
	ADLIB,	# F
	# Special "notes" (starts at 999)
	BARLINE = 999, # Yes. A barline is a notetype.
	GOGOSTART,
	GOGOEND,
}

enum CommandType {
	INVALID,
	BPMCHANGE,
	MEASURE,
	DELAY,
	SCROLL,
	SPEED,
	REVERSE,
	BRANCHSTART,
	BRANCHEND,
	GOGOSTART,
	GOGOEND,
}

## The course of this specific chart.
@export var course: CourseType = CourseType.ONI
## The level displayed for this chart.
## Standard levels go from 1-10, though this may exceed that.
@export var level: int

## Balloons in the current chart.
@export var balloons: PackedFloat64Array = PackedFloat64Array()

## Chart flags, used only for scroll types for now.
@export_flags("BMSCROLL", "HBSCROLL") var flags: int = ChartFlags.NONE

# var disable_scroll: bool = false

# Format for these goes like this
# {time_in_ms, scroll, type_of_note, big_note}
## The notes currently in the chart.
@export var notes: Array[Dictionary]
## 'Special' notes that are visual only and non-interactable.
@export var specil: Array[Dictionary]
# {command_type, value1, value2}
## Logs of non-bpm and non-delay related commands.
@export var command_log: Array[Dictionary]
## BPM logs to change BPM internally.
@export var bpm_log: Array[Dictionary]
## Delay logs to change time and such accordingly.
@export var positive_delay_log: Array[Dictionary]

# Draw data
## Draw data for this chart.
@export var draw_data: Dictionary
## Barline data.
@export var barline_data: Array[Dictionary]

# Branch related
enum BranchType {
	NORMAL,
	EXPERT,
	MASTER
}
enum BranchCondition {
	p,		# Percentage
	r,		# Roll count
	s,		# Score
}

@export_group("Branches", "branch_")
## Branch notes for each of the 3 branches.
@export var branch_notes: Array[Array] = [[], [], []]
## Branch barlines for each of the 3 branches.
@export var branch_barlines: Array[Array] = [[], [], []]
## Branch drawdata for each of the 3 branches.
@export var branch_drawdata: Array[Dictionary] = [{}, {}, {}]

# Default values according to TJAPlayer3
@export_group("Scoring", "score")
## Set of initial values to base the score off of.
@export var scoreinit: PackedInt32Array = [300, 1000]:
	set(n_scoreinit):
		if n_scoreinit.size() < 2: return
		if n_scoreinit[0] == 0 or n_scoreinit[1] == 0: return
		scoreinit = n_scoreinit
## Common difference used to calculate the score.
@export var scorediff: int = 120
## Type of score mode used.
@export var scoremode: int = ScoreHandler.ScoreType.AC14
@export_group("", "")
