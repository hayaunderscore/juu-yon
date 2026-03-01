extends Node

# Plays the music, meant to be overriden
var music_player := AudioStreamPlayer.new()
# Plays a sound, can be multiple
var sound_player := AudioStreamPlayer.new()

var music : Dictionary[String, AudioStreamOggVorbis] = {}
var current_music : String = ""
var cached_sounds : Dictionary[String, AudioStream] = {}
var music_tween: Tween

func add_music(file: String, prefix: String, dir: String = ""):
	if file.is_valid_filename():
		music.get_or_add(dir + file.get_basename(), load(prefix + file))
	else: # Assume its a folder
		for f in ResourceLoader.list_directory(prefix + file):
			add_music(f, prefix + file, dir + file)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Setup sound players
	music_player.name = "Music"
	sound_player.name = "Sound"
	music_player.bus = "Music"
	sound_player.bus = "Sound"
	
	# Music streams are cached
	#var files := ResourceLoader.list_directory("res://assets/music/")
	#for file in files:
		#add_music(file, "res://assets/music/")
	
	# Taiko: normal sound effects like don, kat, and geki are all cached immediately
	var files := ResourceLoader.list_directory("res://assets/snd/")
	for file in files:
		if file.get_extension() != "wav": continue
		cached_sounds.set(file, load("res://assets/snd/" + file))
	
	# Sound effects use a polyphonic stream
	sound_player.stream = AudioStreamPolyphonic.new()
	sound_player.max_polyphony = 32
	
	# add the players
	add_child.call_deferred(music_player)
	add_child.call_deferred(sound_player)
	sound_player.play.call_deferred() # Polyphonic streams are empty but still should be played

func play_music(mus: String, delay: float = 0.01):
	if current_music == mus: return
	if music_tween:
		music_tween.stop()
		music_tween = null
		music_player.volume_linear = 1.0
	if mus == "none": 
		music_player.stop()
		current_music = ""
		return
	music_player.stream_paused = false
	music_player.stream = music.get(mus)
	music_player.play.call_deferred()
	# Globals.music_indicator.change_music_indicator(music_player.stream, delay)
	current_music = mus

func fade_out_music(duration: float = 1.0):
	if not music_player.playing: return
	music_tween = get_tree().create_tween()
	music_tween.set_parallel(true)
	music_tween.tween_property(music_player, "volume_linear", 0, duration)

func pause_music():
	music_player.stream_paused = true

func stop_music():
	music_player.stop()
	current_music = ""
	if music_tween:
		music_tween.stop()
		music_tween = null
		music_player.volume_linear = 1.0

func unpause_music():
	music_player.stream_paused = false

func save_stream(snd: String):
	var stream: AudioStream = load("res://assets/snd/" + snd)
	cached_sounds.set(snd, stream)

func play_sound(snd: String, volume: float = 1.0) -> int:
	if not sound_player.has_stream_playback(): return -1
	var db: float = linear_to_db(volume)
	var playback: AudioStreamPlaybackPolyphonic = sound_player.get_stream_playback()
	if cached_sounds.get(snd):
		return playback.play_stream(cached_sounds[snd], 0, db, 1.0, AudioServer.PLAYBACK_TYPE_DEFAULT, "Sound")
	var task: int = WorkerThreadPool.add_task(save_stream.bind(snd))
	WorkerThreadPool.wait_for_task_completion(task)
	return playback.play_stream(cached_sounds[snd], 0, db, 1.0, AudioServer.PLAYBACK_TYPE_DEFAULT, "Sound")

func stop_sound(id: int):
	if not sound_player.has_stream_playback(): return
	var playback: AudioStreamPlaybackPolyphonic = sound_player.get_stream_playback()
	playback.stop_stream(id)
