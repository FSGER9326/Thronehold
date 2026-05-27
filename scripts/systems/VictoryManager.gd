class_name VictoryManager
extends Node

# =============================================================================
# VICTORY MANAGER - Checks 5 victory conditions each tick for the player
# =============================================================================

var _victory_achieved: bool = false
var _defeat_triggered: bool = false
var _heresy_ticks: int = 0

func _ready() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)

func _on_tick_advanced(_tick: int, _day: int, _season: String, _year: int) -> void:
	if _victory_achieved or _defeat_triggered:
		return

	var pid = ColonyData.player_nation_id
	if pid < 0:
		return

	var player = ColonyData.get_nation(pid)
	if player.is_empty():
		return

	# =========================================================================
	# DEFEAT CHECKS (checked first — loss takes priority)
	# =========================================================================

	# 1. EXTINCTION — player nation population == 0
	if _check_extinction_defeat(player):
		_trigger_defeat("Extinction", "Your people have been wiped from the face of the world.")
		return

	# 2. CONQUEST — all player nation tiles captured by other nations
	if _check_conquest_defeat(pid):
		_trigger_defeat("Conquest", "Every tile of your realm has fallen to foreign powers.")
		return

	# 3. HERESY COLLAPSE — 0 believers globally for 100+ consecutive ticks
	if _check_heresy_collapse():
		_trigger_defeat("Heresy Collapse", "Your faith has been utterly forgotten. No mortal soul believes in you.")
		return

	# 4. DIVINE ABANDONMENT — divine power < 0, no prophets, belief < 5% globally
	if _check_divine_abandonment():
		_trigger_defeat("Divine Abandonment", "Your divine power is spent, your prophets are gone, and your faith has dwindled to nothing.")
		return

	# =========================================================================
	# VICTORY CHECKS
	# =========================================================================

	# 1. EXTERMINATION — all rival nations wiped out (pop = 0)
	if _check_extermination(pid):
		_trigger_victory("Extermination", "Every rival nation lies in ruin. Only your people remain.")

	# 2. DIPLOMATIC SUPREMACY — all other nations are your vassals
	elif _check_diplo_vassal(pid):
		_trigger_victory("Diplomatic Supremacy", "All nations bow before your throne as eternal vassals.")

	# 3. DIVINE UNITY — 80% global belief in your deity
	elif _check_faith():
		_trigger_victory("Divine Unity", "Your faith embraces over 80% of all mortal souls.")

	# 4. TECHNOLOGICAL MASTERY — unlocked all 15 technologies
	elif _check_tech(pid):
		_trigger_victory("Technological Mastery", "All 15 technologies have been unlocked. Your knowledge is complete.")

	# 5. AGE OF PROSPERITY — pop > 500, 2+ colonies, 5k+ gold
	elif _check_prosperity(player):
		_trigger_victory("Age of Prosperity", "Your nation thrives — 500 souls, 2 colonies, and 5,000 gold.")

# =============================================================================
# CONDITION CHECKS
# =============================================================================

func _check_extermination(player_id: int) -> bool:
	var has_others = false
	for nation in ColonyData.nations:
		if nation["id"] == player_id:
			continue
		has_others = true
		if nation["population"] > 0:
			return false
	return has_others


func _check_diplo_vassal(player_id: int) -> bool:
	var dip_mgr = _get_manager("DiplomacyManager")
	if not dip_mgr:
		return false

	var has_others = false
	for nation in ColonyData.nations:
		if nation["id"] == player_id:
			continue
		has_others = true
		if dip_mgr.get_treaty(nation["id"], player_id) != DiplomacyManager.Treaty.VASSALAGE:
			return false
	return has_others


func _check_faith() -> bool:
	var pid = ColonyData.player_nation_id
	if pid < 0:
		return false
	var player = ColonyData.get_nation(pid)
	if player.is_empty():
		return false

	var total_pop = 0
	var total_believers = 0
	for race_id in player.get("race_demographics", {}):
		var pop_share: float = player["race_demographics"][race_id]
		var pop_of_race = int(float(player["population"]) * pop_share)
		var belief = ColonyData.get_belief(pid, race_id)
		total_believers += int(float(pop_of_race) * belief)
		total_pop += pop_of_race

	if total_pop == 0:
		return false
	return float(total_believers) / float(total_pop) >= 0.8


func _check_tech(player_id: int) -> bool:
	var tech_mgr = _get_manager("TechManager")
	if not tech_mgr:
		return false
	var unlocked: Array = tech_mgr.unlocked_techs.get(player_id, [])
	return unlocked.size() >= 15


func _check_prosperity(player: Dictionary) -> bool:
	if player["population"] <= 500:
		return false
	if player["resources"].get("gold", 0.0) < 5000.0:
		return false
	var colonies: Array = player.get("colonies", [])
	if colonies.size() < 2:
		return false
	return true

# =============================================================================
# VICTORY TRIGGER
# =============================================================================

func _trigger_victory(victory_type: String, description: String) -> void:
	_victory_achieved = true
	print("[VictoryManager] VICTORY! %s — %s" % [victory_type, description])
	EventBus.victory_achieved.emit(victory_type, description)
	GameManager.change_state(GameManager.GameState.PAUSED)

# =============================================================================
# DEFEAT CONDITION CHECKS
# =============================================================================

func _check_extinction_defeat(player: Dictionary) -> bool:
	return player.get("population", 1) <= 0


func _check_conquest_defeat(player_id: int) -> bool:
	# Check if the player still owns any tiles on the surface or underground
	for tile in ColonyData.world_tiles:
		if tile.get("owner", -1) == player_id:
			return false
	for tile in ColonyData.underground_tiles:
		if tile.get("owner", -1) == player_id:
			return false
	# Player owns no tiles — conquest defeat
	return ColonyData.world_tiles.size() > 0 or ColonyData.underground_tiles.size() > 0


func _check_heresy_collapse() -> bool:
	var total_believers = _count_global_believers()
	if total_believers <= 0:
		_heresy_ticks += 1
	else:
		_heresy_ticks = 0
	return _heresy_ticks >= 100


func _check_divine_abandonment() -> bool:
	# Get divine power from DeityManager
	var dm = _get_manager("DeityManager")
	var divine_power: float = dm.divine_power if dm else 0.0

	if divine_power >= 0.0:
		return false

	# Check for active prophets
	var prophet_mgr = _get_manager("ProphetManager")
	var has_prophets = false
	if prophet_mgr:
		var actives: Array = prophet_mgr.get_active_prophets()
		has_prophets = not actives.is_empty()

	if has_prophets:
		return false

	# Check global belief < 5%
	var total_pop = 0
	var total_believers = 0
	for nation in ColonyData.nations:
		var nat_pop: int = nation.get("population", 0)
		total_pop += nat_pop
		for race_id in nation.get("race_demographics", {}):
			var pop_share: float = nation["race_demographics"][race_id]
			var pop_of_race = int(float(nat_pop) * pop_share)
			var belief = ColonyData.get_belief(nation["id"], race_id)
			total_believers += int(float(pop_of_race) * belief)

	if total_pop <= 0:
		return false
	var global_belief = float(total_believers) / float(total_pop)
	return global_belief < 0.05

# =============================================================================
# DEFEAT TRIGGER
# =============================================================================

func _trigger_defeat(reason: String, description: String) -> void:
	_defeat_triggered = true
	print("[VictoryManager] DEFEAT! %s — %s" % [reason, description])
	EventBus.defeat_triggered.emit(reason, description)
	GameManager.change_state(GameManager.GameState.DEFEATED)

# =============================================================================
# HELPERS
# =============================================================================

func _count_global_believers() -> int:
	var total = 0
	for nation in ColonyData.nations:
		var nat_pop: int = nation.get("population", 0)
		for race_id in nation.get("race_demographics", {}):
			var pop_share: float = nation["race_demographics"][race_id]
			var pop_of_race = int(float(nat_pop) * pop_share)
			var belief = ColonyData.get_belief(nation["id"], race_id)
			total += int(float(pop_of_race) * belief)
	return total


func _get_manager(name: String) -> Node:
	var root = get_tree().current_scene
	if root:
		var sys = root.get_node_or_null("Systems")
		if sys:
			return sys.get_node_or_null(name)
	return null
