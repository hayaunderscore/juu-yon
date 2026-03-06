extends Node

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	UNKNOWN
}

const PUCHICHARA_PATH: String = "user://puchicharas/"

class Puchichara extends Resource:
	@export var name: String
	@export var rarity: Rarity
	@export var author: String
	@export var image_path: String
	@export var texture: Texture2D

var puchicharas: Dictionary[String, Puchichara] = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var dir: DirAccess = DirAccess.open(PUCHICHARA_PATH)
	if not dir: return
	# TODO: Puchichara paths do not support nesting!
	var files: PackedStringArray = dir.get_directories()
	for file in files:
		# Only include if metadata for this puchichara exists!
		var metadata_path: String = PUCHICHARA_PATH + file + "/Metadata.json"
		if not FileAccess.file_exists(metadata_path): continue
		var js: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
		if not js or js.is_empty(): continue
		
		var puchi: Puchichara = Puchichara.new()
		puchi.name = js.name
		puchi.rarity = Rarity.get((js.rarity as String).to_upper(), Rarity.UNKNOWN)
		puchi.author = js.author
		puchi.image_path = PUCHICHARA_PATH + file + "/Chara.png" # This is always the same
		
		puchicharas.set(puchi.name, puchi)
		Globals.log("PUCHI", "Added %s to puchichara database" % [puchi.name])

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
