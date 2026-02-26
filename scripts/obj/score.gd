extends Node
class_name ScoreHandler

enum ScoreType {
	NONE = -1,
	DONDERFUL,		# SCOREMODE:0
	AC14,			# SCOREMODE:1
	AC15,			# SCOREMODE:2
	NIJIRO,			# SCOREMODE:3
}

const RATING_MULTIPLIER: PackedFloat32Array = [0, 0.5, 1, 2]
const GOGO_MULTIPLIER: float = 1.2

var score_mode: ScoreType = ScoreType.AC14
var score_init: int = 300
var score_diff: int = 120

# Taken from Splitlane since fuck doing the logic for this myself
# except for nijiro since thats more simple lmaoao
var score_calc: Dictionary = {
	Note = [
		func(score, combo, _init, _diff, judge, gogo): 
			return floorf((score + ((1000 if (combo < 200) else 2000) * RATING_MULTIPLIER[judge] * (GOGO_MULTIPLIER if gogo else 1.0))) / 10) * 10,
		func(score, combo, init, diff, judge, gogo): 
			return floorf((score + ((init + max(0, int(diff) * floorf((min(combo, 100) - 1) / 10))) * RATING_MULTIPLIER[judge] * (GOGO_MULTIPLIER if gogo else 1.0))) / 10) * 10,
		func(score, combo, init, diff, judge, gogo): 
			return floorf((score + ((init + diff * (8 if combo >= 100 else 4 if combo >= 50 else 2 if combo >= 30 else 1 if combo >= 10 else 0)) * RATING_MULTIPLIER[judge] * (GOGO_MULTIPLIER if gogo else 1.0))) / 10) * 10,
		func(score, _combo, init, _diff, judge, gogo):
			return floorf((score + init * RATING_MULTIPLIER[mini(judge, 2)] * (GOGO_MULTIPLIER if gogo else 1.0)) / 10) * 10,
	],
	Drumroll = [
		func(score, notetype, gogo): return score + ((600 if notetype == 3 else 300) * (GOGO_MULTIPLIER if gogo else 1.0)),
		func(score, notetype, gogo): return score + ((600 if notetype == 3 else 300) * (GOGO_MULTIPLIER if gogo else 1.0)),
		func(score, notetype, gogo): return score + ((200 if notetype == 3 else 100) * (GOGO_MULTIPLIER if gogo else 1.0)),
		func(score, _notetype, gogo): return score + (200 * (GOGO_MULTIPLIER if gogo else 1.0))
	],
	Balloon = [
		func(score, _notetype, gogo): return score + (300 * (GOGO_MULTIPLIER if gogo else 1.0)),
		func(score, _notetype, gogo): return score + (300 * (GOGO_MULTIPLIER if gogo else 1.0)),
		func(score, _notetype, gogo): return score + (300 * (GOGO_MULTIPLIER if gogo else 1.0)),
		func(score, _notetype, gogo): return score + (300 * (GOGO_MULTIPLIER if gogo else 1.0))
	],
	BalloonPop = [
		func(score, _notetype, gogo): return score + (5000 * (GOGO_MULTIPLIER if gogo else 1.0)),
		func(score, _notetype, gogo): return score + (5000 * (GOGO_MULTIPLIER if gogo else 1.0)),
		func(score, _notetype, gogo): return score + (5000 * (GOGO_MULTIPLIER if gogo else 1.0)),
		func(score, _notetype, gogo): return score + (5000 * (GOGO_MULTIPLIER if gogo else 1.0))
	]
}

func calc_score(score: int, combo: int, judge: int, gogo: bool):
	combo += 1
	return [score_calc["Note"][score_mode].call(score, combo, score_init, score_diff, judge, gogo), combo]

func calc_roll(score: int, judge: int, gogo: bool):
	return score_calc["Drumroll"][score_mode].call(score, judge, gogo)

func calc_balloon(score: int, judge: int, gogo: bool):
	return score_calc["Balloon"][score_mode].call(score, judge, gogo)

func calc_balloon_pop(score: int, judge: int, gogo: bool):
	return score_calc["BalloonPop"][score_mode].call(score, judge, gogo)

# This does not account for balloons and drumrolls since those are variable!!!
func calc_max_score_and_combo(notes: Array[Dictionary]):
	var max_score: int = 0
	var max_combo: int = 0
	for note in notes:
		if note.has("dummy"): continue
		if note["note"] >= 5 and note["note"] != 10: continue
		var s: Array = calc_score(max_score, max_combo, int(3 if note["note"] > 2 else 2), int(note["gogotime"]))
		max_score = s[0]
		max_combo = s[1]
	return [max_score, max_combo]
