class_name SaveManager
extends Node

# =============================================================================
# SAVE / LOAD SYSTEM
# =============================================================================

const SAVE_VERSION = 1
const DEFAULT_SAVE_PATH = "user://save.json"

func _ready() -> void:
	EventBus.save_requested.connect(_on_save_requested)
	EventBus.load_requested.connect(_on_load_requested)

# =============================================================================
# PUBLIC API
# =============================================================================

func save_game(path: String = DEFAULT_SAVE_PATH) -> bool:
	var save_dict = _build_save_dict()
	var json_string = JSON.stringify(save_dict, "\t")
	if json_string.is_empty():
		printerr("[SaveManager] Failed to serialize save data")
		return false

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("[SaveManager] Failed to open file for writing: %s" % path)
		return false

	file.store_string(json_string)
	file.close()

	print("[SaveManager] Game saved to: %s (tick %d, year %d)" % [
		path, ColonyData.current_tick, ColonyData.current_year
	])
	EventBus.game_saved.emit(path)
	return true


func load_game(path: String = DEFAULT_SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		printerr("[SaveManager] Save file not found: %s" % path)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("[SaveManager] Failed to open file for reading: %s" % path)
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		printerr("[SaveManager] Failed to parse save file: %s" % json.get_error_message())
		return false

	var save_dict: Dictionary = json.data
	if save_dict.is_empty():
		printerr("[SaveManager] Save data is empty")
		return false

	if save_dict.get("version", 0) != SAVE_VERSION:
		printerr("[SaveManager] Save version mismatch: expected %d, got %d" % [SAVE_VERSION, save_dict.get("version", 0)])
		return false

	_restore_save_dict(save_dict)

	print("[SaveManager] Game loaded from: %s (tick %d, year %d)" % [
		path, ColonyData.current_tick, ColonyData.current_year
	])
	EventBus.game_loaded.emit(path)
	return true

# =============================================================================
# SERIALIZATION
# =============================================================================

func _build_save_dict() -> Dictionary:
	var colony = _serialize_colony_data()
	var tech = _serialize_tech_manager()
	var deity = _serialize_deity_manager()

	return {
		"version": SAVE_VERSION,
		"colony": colony,
		"tech": tech,
		"deity": deity,
	}


func _serialize_colony_data() -> Dictionary:
	return {
		"player_nation_id": ColonyData.player_nation_id,
		"deity_name": ColonyData.deity_name,
		"deity_domain": ColonyData.deity_domain,

		# Time
		"current_tick": ColonyData.current_tick,
		"current_day": ColonyData.current_day,
		"current_season": ColonyData.current_season,
		"current_year": ColonyData.current_year,

		# World
		"world_width": ColonyData.world_width,
		"world_height": ColonyData.world_height,
		"world_tiles": ColonyData.world_tiles,
		"underground_tiles": ColonyData.underground_tiles,

		# Nations & diplomacy
		"nations": ColonyData.nations,
		"diplomacy_matrix": _serialize_diplomacy_matrix(),
		"trade_leagues": ColonyData.trade_leagues,

		# Belief
		"belief_by_nation": ColonyData.belief_by_nation,

		# Characters
		"characters": ColonyData.characters,
		"_next_character_id": ColonyData._next_character_id,

		# Factions
		"active_factions": ColonyData.active_factions,
		"independence_movements": ColonyData.independence_movements,

		# Culture & genetics
		"nation_culture": ColonyData.nation_culture,
		"population_genetics": ColonyData.population_genetics,
		"hybrid_demographics": ColonyData.hybrid_demographics,

		# Prophets
		"prophets": ColonyData.prophets,

		# Tutorial seen flag (persists across sessions)
		"has_seen_tutorial": ColonyData.has_seen_tutorial,

		# Notification log
		"notification_log": ColonyData.notification_log,

		# Fog of war
		"visibility_grid": ColonyData.visibility_grid,
	}


func _serialize_diplomacy_matrix() -> Array:
	var result: Array = []
	for row in ColonyData.diplomacy_matrix:
		result.append(row.duplicate())
	return result


func _serialize_tech_manager() -> Dictionary:
	var tm = _find_tech_manager()
	if tm == null:
		return {"research_points": {}, "unlocked_techs": {}, "current_era": {}}

	return {
		"research_points": tm.research_points.duplicate(),
		"unlocked_techs": _serialize_unlocked_techs(tm),
		"current_era": tm.current_era.duplicate(),
	}


func _serialize_unlocked_techs(tm: Node) -> Dictionary:
	var result = {}
	for nation_id in tm.unlocked_techs:
		result[nation_id] = tm.unlocked_techs[nation_id].duplicate()
	return result


func _serialize_deity_manager() -> Dictionary:
	var dm = _find_deity_manager()
	if dm == null:
		return {}

	return {
		"deity_class": dm.deity_class,
		"unlocked_skills": dm.unlocked_skills.duplicate(),
		"active_aspects": dm.active_aspects.duplicate(),
		"aspect_power_allocation": dm.aspect_power_allocation.duplicate(),
		"skill_points": dm.skill_points,
		"divine_power": dm.divine_power,
		"max_divine_power": dm.max_divine_power,
		"rank": dm.rank,
		"max_aspects": dm.max_aspects,
	}

# =============================================================================
# DESERIALIZATION
# =============================================================================

func _restore_save_dict(data: Dictionary) -> void:
	_restore_colony_data(data.get("colony", {}))
	_restore_tech_manager(data.get("tech", {}))
	_restore_deity_manager(data.get("deity", {}))


func _restore_colony_data(c: Dictionary) -> void:
	ColonyData.player_nation_id = c.get("player_nation_id", -1)
	ColonyData.deity_name = c.get("deity_name", "The Unnamed")
	ColonyData.deity_domain = c.get("deity_domain", "Forge")

	ColonyData.current_tick = c.get("current_tick", 0)
	ColonyData.current_day = c.get("current_day", 1)
	ColonyData.current_season = c.get("current_season", "Spring")
	ColonyData.current_year = c.get("current_year", 1)

	ColonyData.world_width = c.get("world_width", 80)
	ColonyData.world_height = c.get("world_height", 60)
	ColonyData.world_tiles = c.get("world_tiles", [])
	ColonyData.underground_tiles = c.get("underground_tiles", [])

	ColonyData.nations = c.get("nations", [])

	# Diplomacy matrix — convert inner arrays back from generic Array
	var raw_matrix: Array = c.get("diplomacy_matrix", [])
	ColonyData.diplomacy_matrix.clear()
	for row in raw_matrix:
		ColonyData.diplomacy_matrix.append(row)

	ColonyData.trade_leagues = c.get("trade_leagues", [])
	ColonyData.belief_by_nation = c.get("belief_by_nation", {})

	ColonyData.characters = c.get("characters", [])
	ColonyData._next_character_id = c.get("_next_character_id", 0)

	ColonyData.active_factions = c.get("active_factions", [])
	ColonyData.independence_movements = c.get("independence_movements", [])

	ColonyData.nation_culture = c.get("nation_culture", {})
	ColonyData.population_genetics = c.get("population_genetics", {})
	ColonyData.hybrid_demographics = c.get("hybrid_demographics", {})

	ColonyData.prophets = c.get("prophets", [])

	ColonyData.notification_log = c.get("notification_log", [])

	ColonyData.has_seen_tutorial = c.get("has_seen_tutorial", false)

	ColonyData.visibility_grid = c.get("visibility_grid", [])

	# Rebuild O(1) caches from restored data
	ColonyData._nation_by_id.clear()
	ColonyData._leader_by_nation.clear()
	for n in ColonyData.nations:
		ColonyData._nation_by_id[n["id"]] = n
	for ch in ColonyData.characters:
		if ch.get("role", "") == "leader" and ch.get("alive", true):
			ColonyData._leader_by_nation[ch["nation_id"]] = ch


func _restore_tech_manager(t: Dictionary) -> void:
	var tm = _find_tech_manager()
	if tm == null:
		return

	tm.research_points = t.get("research_points", {})
	tm.unlocked_techs = t.get("unlocked_techs", {})
	tm.current_era = t.get("current_era", {})


func _restore_deity_manager(d: Dictionary) -> void:
	if d.is_empty():
		return

	var dm = _find_deity_manager()
	if dm == null:
		return

	dm.deity_class = d.get("deity_class", "")
	dm.unlocked_skills = d.get("unlocked_skills", [])
	dm.active_aspects = d.get("active_aspects", [])
	dm.aspect_power_allocation = d.get("aspect_power_allocation", {})
	dm.skill_points = d.get("skill_points", 0)
	dm.divine_power = d.get("divine_power", 10.0)
	dm.max_divine_power = d.get("max_divine_power", 50.0)
	dm.rank = d.get("rank", 1)
	dm.max_aspects = d.get("max_aspects", 1)

# =============================================================================
# NODE LOOKUP HELPERS
# =============================================================================

func _find_tech_manager() -> Node:
	var systems = _get_systems_node()
	if systems:
		return systems.get_node_or_null("TechManager")
	return null


func _find_deity_manager() -> Node:
	var systems = _get_systems_node()
	if systems:
		return systems.get_node_or_null("DeityManager")
	return null


func _get_systems_node() -> Node:
	var root = get_tree().current_scene
	if not root:
		return null
	return root.get_node_or_null("Systems")

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_save_requested(path: String) -> void:
	save_game(path if not path.is_empty() else DEFAULT_SAVE_PATH)


func _on_load_requested(path: String) -> void:
	load_game(path if not path.is_empty() else DEFAULT_SAVE_PATH)
