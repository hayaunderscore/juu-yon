@tool
extends EditorPlugin

var vertical_text_parser: VerticalText2DTranslationParserPlugin

func _enter_tree() -> void:
	print("Hi")
	vertical_text_parser = preload("res://addons/taiko_locale/parsers/verticaltext2d.gd").new()
	add_translation_parser_plugin(vertical_text_parser)


func _exit_tree() -> void:
	print("Bye")
	if is_instance_valid(vertical_text_parser):
		remove_translation_parser_plugin(vertical_text_parser)
		vertical_text_parser = null
