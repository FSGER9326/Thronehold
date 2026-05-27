class_name TimeManager
extends Node

const TICKS_PER_DAY: int = 4
const DAYS_PER_SEASON: int = 10
const SEASONS = ["Spring", "Summer", "Autumn", "Winter"]

var tick_interval: float = 0.5
var speed_multiplier: float = 1.0
var is_paused: bool = false
var _tick_accumulator: float = 0.0

func _ready() -> void:
	set_process(false)
	EventBus.game_paused.connect(func(): stop())
	EventBus.game_resumed.connect(func(): start())

func start() -> void:
	set_process(true)
	is_paused = false

func stop() -> void:
	set_process(false)

func set_speed(mult: float) -> void:
	speed_multiplier = clamp(mult, 0.25, 8.0)
	EventBus.speed_changed.emit(speed_multiplier)

func _process(delta: float) -> void:
	if is_paused:
		return

	_tick_accumulator += delta * speed_multiplier
	while _tick_accumulator >= tick_interval:
		_tick_accumulator -= tick_interval
		_advance_tick()

func _advance_tick() -> void:
	var data = ColonyData
	data.current_tick += 1

	if data.current_tick % TICKS_PER_DAY == 0:
		data.current_day += 1
		if data.current_day > DAYS_PER_SEASON:
			data.current_day = 1
			_advance_season()

	EventBus.tick_advanced.emit(
		data.current_tick,
		data.current_day,
		data.current_season,
		data.current_year
	)

func _advance_season() -> void:
	var data = ColonyData
	var idx = SEASONS.find(data.current_season)
	idx = (idx + 1) % SEASONS.size()
	data.current_season = SEASONS[idx]
	EventBus.season_changed.emit(data.current_season, data.current_year)
	if idx == 0:
		data.current_year += 1
		EventBus.year_changed.emit(data.current_year)
