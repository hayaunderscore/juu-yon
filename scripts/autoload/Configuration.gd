extends Node

var config: Dictionary = {
	"game": {
		"free_play": true,
		"song_folder": "songs/"
	},
	"audio": {
		"music": 100,
		"sound": 100,
	}
}
var config_path: String = "res://config.cfg"

func get_section_key(section: String, key: String) -> Variant:
	if not config.has(section):
		print("Unknown section!")
		return null
	return config[section].get(key)

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
