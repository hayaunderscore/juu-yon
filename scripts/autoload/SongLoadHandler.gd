extends Node

func select_song(tja: TJAMeta, diff: int):
	TransitionHandler.change_scene_to_file("res://scenes/main.tscn")
	await get_tree().scene_changed
	var main: MainScene = get_tree().current_scene as MainScene
	main.load_tja(tja, tja.chart_metadata[diff]["cached_index"])
