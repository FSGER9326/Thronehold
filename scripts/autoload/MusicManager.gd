class_name MusicManager
extends Node

const MUSIC_DIR = "res://assets/audio/music/"
const SFX_DIR = "res://assets/audio/sfx/"

enum MusicState { MENU, PEACEFUL, WAR, UNDERGROUND, VICTORY, DEFEAT }
var current_state: MusicState = MusicState.MENU
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_pool_size: int = 8
var _sfx_index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	_create_music_player()
	_create_sfx_pool()
	_connect_signals()
	play_music(MusicState.MENU)

func _setup_audio_buses() -> void:
	AudioServer.set_bus_count(5)
	AudioServer.set_bus_name(0, "Master")
	AudioServer.set_bus_name(1, "Music")
	AudioServer.set_bus_name(2, "SFX")
	AudioServer.set_bus_name(3, "Ambient")
	AudioServer.set_bus_name(4, "UI")
	AudioServer.set_bus_volume_db(1, -6.0)
	AudioServer.set_bus_volume_db(2, -3.0)
	AudioServer.set_bus_volume_db(3, -10.0)
	AudioServer.set_bus_volume_db(4, -2.0)

func _create_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)

func _create_sfx_pool() -> void:
	for i in range(sfx_pool_size):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)

func _connect_signals() -> void:
	EventBus.tile_clicked.connect(func(_x, _y): _play_sfx("click"))
	EventBus.building_placed.connect(func(_x, _y, _b, _n): _play_sfx("build"))
	EventBus.battle_fought.connect(func(_a, _d, _r): _play_sfx("battle"))
	EventBus.victory_achieved.connect(func(_t, _d): play_music(MusicState.VICTORY))
	EventBus.war_declared.connect(func(_a, _d): play_music(MusicState.WAR))
	EventBus.peace_signed.connect(func(_a, _b): play_music(MusicState.PEACEFUL))
	EventBus.underground_toggled.connect(func(e): play_music(MusicState.UNDERGROUND if e else MusicState.PEACEFUL))
	EventBus.resource_critical.connect(func(_n, _r, _a): _play_sfx("alert"))
	EventBus.game_paused.connect(func(): music_player.stream_paused = true)
	EventBus.game_resumed.connect(func(): music_player.stream_paused = false)

func play_music(state: MusicState) -> void:
	if current_state == state and music_player.playing:
		return
	current_state = state
	var track = ""
	match state:
		MusicState.MENU: track = MUSIC_DIR + "menu.ogg"
		MusicState.PEACEFUL: track = MUSIC_DIR + "peaceful.ogg"
		MusicState.WAR: track = MUSIC_DIR + "battle.ogg"
		MusicState.UNDERGROUND: track = MUSIC_DIR + "underground.ogg"
		MusicState.VICTORY: track = MUSIC_DIR + "victory.ogg"
		MusicState.DEFEAT: track = MUSIC_DIR + "defeat.ogg"
	if not FileAccess.file_exists(track):
		print("[Music] File not found: %s" % track)
		return
	music_player.stream = load(track)
	music_player.play()

func _play_sfx(name: String) -> void:
	var path = SFX_DIR + name + ".ogg"
	if not FileAccess.file_exists(path):
		return
	var p = sfx_players[_sfx_index % sfx_pool_size]
	_sfx_index += 1
	p.stream = load(path)
	p.play()

func set_music_volume(db: float) -> void:
	AudioServer.set_bus_volume_db(1, db)

func set_sfx_volume(db: float) -> void:
	AudioServer.set_bus_volume_db(2, db)
