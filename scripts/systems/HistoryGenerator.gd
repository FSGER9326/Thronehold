class_name HistoryGenerator
extends Node

var _rng: RandomNumberGenerator

func generate_history() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = randi()
	ColonyData.world_history = {
		"past_wars": _generate_past_wars(),
		"migrations": _generate_migrations(),
		"ancient_empires": _generate_ancient_empires(),
		"trade_leagues": _generate_trade_league_history(),
	}
	EventBus.history_events_generated.emit()

func _generate_past_wars() -> Array[Dictionary]:
	var wars: Array[Dictionary] = []
	var count = _rng.randi_range(2, 5)
	var races = ColonyData.RACES.keys()
	for i in range(count):
		wars.append({
			"name": _war_name(),
			"aggressor_race": races[_rng.randi() % races.size()],
			"defender_race": races[_rng.randi() % races.size()],
			"outcome": ["aggressor_victory", "defender_victory", "stalemate"][_rng.randi() % 3],
			"year_offset": -(_rng.randi_range(10, 500))
		})
	return wars

func _generate_migrations() -> Array[Dictionary]:
	var migrations: Array[Dictionary] = []
	var count = _rng.randi_range(1, 3)
	var races = ColonyData.RACES.keys()
	var biomes = ["plains", "forest", "hills", "mountain", "coast", "desert"]
	for i in range(count):
		migrations.append({
			"race": races[_rng.randi() % races.size()],
			"from_biome": biomes[_rng.randi() % biomes.size()],
			"to_biome": biomes[_rng.randi() % biomes.size()],
			"population_moved": _rng.randi_range(100, 2000),
			"year_offset": -(_rng.randi_range(20, 300))
		})
	return migrations

func _generate_ancient_empires() -> Array[Dictionary]:
	var empires: Array[Dictionary] = []
	var names = ["The First Empire", "Empire of Dawn", "Obsidian Dominion", "Silver Concord", "Thorn Dynasty"]
	var races = ColonyData.RACES.keys()
	var reasons = ["civil_war", "plague", "invasion", "economic_collapse", "environmental", "unknown"]
	var count = _rng.randi_range(1, 3)
	for i in range(count):
		empires.append({
			"name": names[_rng.randi() % names.size()],
			"dominant_race": races[_rng.randi() % races.size()],
			"peak_size_tiles": _rng.randi_range(200, 800),
			"collapse_reason": reasons[_rng.randi() % reasons.size()],
			"year_offset": -(_rng.randi_range(200, 2000))
		})
	return empires

func _generate_trade_league_history() -> Array[Dictionary]:
	var leagues: Array[Dictionary] = []
	var names = ["Gilded Compact", "Free Trade League", "Merchant Coalition", "Silver Road Pact"]
	var count = _rng.randi_range(1, 2)
	for i in range(count):
		leagues.append({
			"name": names[_rng.randi() % names.size()],
			"founder_race": 		ColonyData.RACES.keys()[_rng.randi() % ColonyData.RACES.size()],
			"member_count": _rng.randi_range(2, 4),
			"year_offset": -(_rng.randi_range(10, 150))
		})
	return leagues

func _war_name() -> String:
	var prefixes = ["Great", "Bloody", "Iron", "Crimson", "War of the"]
	var suffixes = ["War", "Conflict", "Campaign", "Crusade", "Invasion"]
	return prefixes[_rng.randi() % prefixes.size()] + " " + suffixes[_rng.randi() % suffixes.size()]

func _ready() -> void:
	pass
