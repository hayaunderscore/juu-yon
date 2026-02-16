@tool
class_name VerticalText2DTranslationParserPlugin
extends EditorTranslationParserPlugin

func _parse_vertical_text(res: VerticalText2D) -> PackedStringArray:
	return PackedStringArray([res.text])

func _parse_scene(res: PackedScene) -> Array[PackedStringArray]:
	var sample: Node = res.instantiate()
	var trects: Array[Node] = sample.find_children("", "TextureRect")
	var ret: Array[PackedStringArray] = []
	for trect in trects:
		if trect is TextureRect and trect.texture is VerticalText2D:
			ret.append(_parse_vertical_text(trect.texture))
	return ret

func _parse_file(path: String) -> Array[PackedStringArray]:
	var ret: Array[PackedStringArray] = []
	var r: Resource = ResourceLoader.load(path)
	if not r: return ret
	if r is PackedScene:
		ret.append_array(_parse_scene(r))
	elif r is VerticalText2D:
		ret.append(_parse_vertical_text(r))
	return ret

func _get_recognized_extensions() -> PackedStringArray:
	return ["tres", "tscn"]
