extends Node

func select_song(tja: TJAMeta, diff: int):
	var clr: Color = tja.from_box.box_back_color if tja.from_box else Color.WHITE
	var title: Label = TransitionHandler.fade.get_node(^"%Title")
	var subtitle: Label = TransitionHandler.fade.get_node(^"%Subtitle")
	var border: Control = TransitionHandler.fade.get_node(^"%Border")
	title.text = tja.title_localized.get(TranslationServer.get_locale(), tja.title)
	subtitle.text = (tja.subtitle_localized.get(TranslationServer.get_locale(), tja.subtitle) as String).replace("--", "")
	subtitle.visible = not subtitle.text.is_empty()
	TransitionHandler.change_scene_to_file("res://scenes/main.tscn", false, clr)
	await get_tree().scene_changed
	var tween: Tween = create_tween()
	tween.tween_property(border, "modulate:a", 1.0, 0.3)
	tween.tween_interval(3.0)
	tween.tween_property(border, "modulate:a", 0.0, 0.3)
	var main: MainScene = get_tree().current_scene as MainScene
	tween.tween_callback(func():
		TransitionHandler.anim.play("MoveOut")
		main.load_tja(tja, tja.chart_metadata[diff]["cached_index"])
	)
