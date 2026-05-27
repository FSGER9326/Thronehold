extends Node

enum GameState {
	MAIN_MENU, CLASS_SELECT, WORLD_SETUP, PLAYING, PAUSED, SPECTATOR,
	EVENT_DIALOG, DIPLOMACY_SCREEN, DEITY_SCREEN, SKILL_TREE_SCREEN,
	INFLUENCE_SCREEN, PROPHET_SCREEN,
	DEFEATED
}

var current_state: GameState = GameState.CLASS_SELECT

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func change_state(new_state: GameState) -> void:
	if current_state == new_state:
		return

	var prev = current_state
	current_state = new_state

	match new_state:
		GameState.PLAYING, GameState.SPECTATOR:
			EventBus.game_resumed.emit()
		GameState.PAUSED:
			EventBus.game_paused.emit()

	print("[GameManager] %s -> %s" % [GameState.keys()[prev], GameState.keys()[new_state]])

func start_new_game() -> void:
	# State is already MAIN_MENU by default
	# Scene is already main.tscn
	pass

func world_setup_complete() -> void:
	change_state(GameState.PLAYING)
	# Time was paused during setup; the caller should start TimeManager

func class_selection_complete() -> void:
	change_state(GameState.WORLD_SETUP)
	EventBus.world_generation_requested.emit()
