extends Node

var config: Dictionary = {
	"Game": {
		"free_play": true,
		"song_folder": "res://songs/",
		"language": "ja",
	},
	"Player1": {
		"chara": "default",
		"name": "Don-chan",
	},
	"Player2": {
		"chara": "default",
		"name": "Kat-chan",
	},
	"Audio": {
		"music": 100,
		"sound": 100,
	}
}
var config_path: String = "user://config.cfg"

func get_section_key(section: String, key: String) -> Variant:
	if not config.has(section):
		print("Unknown section!")
		return null
	return config[section].get(key)

func get_section_key_from_string(st: String) -> Variant:
	var split: PackedStringArray = st.split(":")
	return get_section_key(split[0], split[1])

func set_section_key_from_string(st: String, val: Variant):
	var split: PackedStringArray = st.split(":")
	(config[split[0]] as Dictionary).set(split[1], val)
	if split[1] == "free_play":
		Globals.change_free_play(val)

func save_options():
	var cfg: ConfigFile = ConfigFile.new()
	for section in config.keys():
		var sec: Dictionary = config[section]
		for key in sec:
			cfg.set_value(section, key, sec[key])
	cfg.save(config_path)

func _ready() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if FileAccess.file_exists(config_path):
		cfg.load(config_path)
		for section in cfg.get_sections():
			if not config.has(section): continue
			var sec: Dictionary = config.get(section)
			for key in cfg.get_section_keys(section):
				if not sec.has(key): continue
				sec.set(key, cfg.get_value(section, key, sec.get(key)))
	else:
		for section in config.keys():
			var sec: Dictionary = config[section]
			for key in sec:
				cfg.set_value(section, key, sec[key])
		cfg.save(config_path)
	
	TranslationServer.set_locale(get_section_key("Game", "language"))
	Globals.change_free_play(get_section_key("Game", "free_play"))
	Globals.player_skins[0] = get_section_key("Player1", "chara")
	Globals.player_skins[1] = get_section_key("Player2", "chara")
