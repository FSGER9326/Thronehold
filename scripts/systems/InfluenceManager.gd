class_name InfluenceManager
extends Node

# Player deity influences nations through various channels
# Success depends on leader traits, race tendencies, and influence method

var _cooldowns: Dictionary = {}  # {action_id: ticks_remaining}
var _scene_cache: Node

func _ready() -> void:
	_scene_cache = get_tree().current_scene
	EventBus.tick_advanced.connect(_on_tick_advanced)

func _on_tick_advanced(_tick: int, _day: int, _season: String, _year: int) -> void:
	for action_id in _cooldowns:
		_cooldowns[action_id] -= 1

func attempt_influence(nation_id: int, action_id: String, desired_direction: String = "") -> Dictionary:
	if not ColonyData.INFLUENCE_ACTIONS.has(action_id):
		return {"success": false, "reason": "Unknown action"}

	var action = ColonyData.INFLUENCE_ACTIONS[action_id]
	var dm = _get_deity_manager()
	if not dm:
		return {"success": false, "reason": "Deity system offline"}

	# Check cooldown
	if _cooldowns.get(action_id, 0) > 0:
		return {"success": false, "reason": "On cooldown for %d ticks" % _cooldowns[action_id]}

	# Check power cost
	if dm.divine_power < action["cost"]:
		return {"success": false, "reason": "Not enough divine power"}

	# Pay cost
	dm.divine_power -= action["cost"]

	# Calculate success chance
	var leader = ColonyData.get_leader(nation_id)
	var base_chance = action["base_success"]
	var resistance = 1.0

	if not leader.is_empty():
		resistance = leader.get("influence_resistance", 1.0)
		var race = ColonyData.RACES.get(leader["race"], {})
		resistance *= race.get("influence_difficulty", 1.0)

		# Leader archetype matters
		var arch = ColonyData.LEADER_ARCHETYPES.get(leader["archetype"], {})
		resistance *= arch.get("influence_resistance_mod", 1.0)

		# Direct leader targeting is harder
		if action.get("targets_leader", false):
			resistance *= 1.3

	# Aspect attraction: matching aspects reduce resistance (up to 20%)
	if not dm.active_aspects.is_empty():
		var aspect_attraction_mod: float = 0.0
		for aspect_id in dm.active_aspects:
			aspect_attraction_mod += ColonyData.get_aspect_attraction(nation_id, aspect_id)
		aspect_attraction_mod = min(aspect_attraction_mod, 0.2)
		resistance *= max(1.0 - aspect_attraction_mod, 0.3)

	# Check for active prophets in nation
	var prophet_bonus = 0.0
	for p in ColonyData.prophets:
		if p["nation_id"] == nation_id and p.get("alive", true):
			prophet_bonus = p.get("effectiveness", 0.0) * 0.3

	var final_chance = clamp(base_chance / resistance + prophet_bonus, 0.05, 1.0)

	# Roll
	var success = randf() < final_chance
	var effect_strength = action["effect_strength"] if success else action["effect_strength"] * 0.2

	# Apply cooldown
	_cooldowns[action_id] = action["cooldown_ticks"]

	# Log
	print("[Influence] %s on nation %d: %s (chance %.0f%%)" % [
		action["name"], nation_id, "SUCCESS" if success else "FAILURE", final_chance * 100
	])

	EventBus.influence_attempted.emit(nation_id, action_id, success, effect_strength)

	# Apply belief change on success
	if success:
		var nation = ColonyData.get_nation(nation_id)
		if not nation.is_empty():
			_apply_belief_change(nation_id, nation, effect_strength)

	return {
		"success": success,
		"effect_strength": effect_strength,
		"chance": final_chance,
		"cost": action["cost"],
	}


func _apply_belief_change(nation_id: int, nation: Dictionary, effect_strength: float) -> void:
	var demographics: Dictionary = nation.get("race_demographics", {})
	if demographics.is_empty():
		return

	# Find the most receptive race (lowest influence_difficulty)
	var best_race = ""
	var best_difficulty = 999.0
	for race_id in demographics:
		var race_data = ColonyData.RACES.get(race_id, {})
		var diff: float = race_data.get("influence_difficulty", 1.0)
		if diff < best_difficulty:
			best_difficulty = diff
			best_race = race_id

	if best_race.is_empty():
		return

	var belief_delta = effect_strength * 0.1
	var current_belief = ColonyData.get_belief(nation_id, best_race)
	ColonyData.set_belief(nation_id, best_race, current_belief + belief_delta)
	EventBus.belief_changed.emit(nation_id, best_race, current_belief + belief_delta)

func get_cooldowns() -> Dictionary:
	return _cooldowns.duplicate()

func _get_deity_manager() -> Node:
	var root = _scene_cache
	if root:
		var sys = root.get_node_or_null("Systems")
		if sys:
			return sys.get_node_or_null("DeityManager")
	return null
