class_name EventManager
extends Node

var event_pool: Array[Dictionary] = [
	{
		"id": "goblin_raid",
		"name": "Goblin Raid!",
		"description": "A band of goblins has been spotted approaching!",
		"type": "threat",
		"min_year": 1,
		"weight": 10,
		"min_threat": 0.0,
		"max_threat": 1.5,
		"outcomes": {
			"fight": {
				"label": "Fight them off",
				"description": "Our warriors will meet them at the gates.",
				"success_chance": 0.6,
				"success": {"population_change": -1, "metal": 10},
				"failure": {"population_change": -3, "food": -20},
			},
			"hide": {
				"label": "Hide and wait",
				"description": "Close the gates and hope they pass.",
				"success_chance": 0.8,
				"success": {"food": -5},
				"failure": {"food": -15, "wood": -10},
			},
		},
	},
	{
		"id": "merchant_caravan",
		"name": "Merchant Caravan",
		"description": "A traveling merchant caravan has arrived, offering to trade.",
		"type": "opportunity",
		"min_year": 0,
		"weight": 15,
		"outcomes": {
			"trade_food": {
				"label": "Trade for food",
				"description": "Spend gold to buy food supplies.",
				"success_chance": 1.0,
				"success": {"gold": -10, "food": 30},
				"failure": {},
			},
			"trade_metal": {
				"label": "Trade for metal",
				"description": "Exchange surplus food for metal tools.",
				"success_chance": 1.0,
				"success": {"food": -15, "metal": 10},
				"failure": {},
			},
			"ignore": {
				"label": "Ignore them",
				"description": "Let them pass through without trade.",
				"success_chance": 1.0,
				"success": {},
				"failure": {},
			},
		},
	},
	{
		"id": "disease_outbreak",
		"name": "Mysterious Illness",
		"description": "Several people have fallen ill with a strange sickness.",
		"type": "crisis",
		"min_year": 2,
		"weight": 8,
		"min_threat": 0.5,
		"max_threat": 2.5,
		"outcomes": {
			"quarantine": {
				"label": "Quarantine the sick",
				"description": "Isolate affected. Reduces spread but hurts production.",
				"success_chance": 0.7,
				"success": {"population_change": 0},
				"failure": {"population_change": -2},
			},
			"spend_resources": {
				"label": "Spend resources on medicine",
				"description": "Use herbs and supplies to treat the illness.",
				"success_chance": 0.9,
				"success": {"food": -20, "wood": -10},
				"failure": {"food": -20, "wood": -10, "population_change": -1},
			},
		},
	},
	{
		"id": "migrant_wave",
		"name": "Travelers Arrive",
		"description": "A group of travelers wishes to join your nation.",
		"type": "neutral",
		"min_year": 0,
		"weight": 12,
		"outcomes": {
			"accept": {
				"label": "Welcome them",
				"description": "Accept the newcomers. More hands, more mouths to feed.",
				"success_chance": 1.0,
				"success": {"population_change": 3, "food": -15},
				"failure": {},
			},
			"reject": {
				"label": "Turn them away",
				"description": "The nation cannot support more people right now.",
				"success_chance": 1.0,
				"success": {},
				"failure": {},
			},
		},
	},
	{
		"id": "rich_vein",
		"name": "Rich Mineral Vein",
		"description": "Miners have discovered a rich vein of valuable ore!",
		"type": "opportunity",
		"min_year": 0,
		"weight": 8,
		"outcomes": {
			"exploit": {
				"label": "Exploit it fully",
				"description": "Double mining efforts while it lasts.",
				"success_chance": 0.8,
				"success": {"metal": 25, "gold": 15},
				"failure": {"metal": 5},
			},
			"caution": {
				"label": "Careful extraction",
				"description": "Mine cautiously to avoid cave-ins.",
				"success_chance": 1.0,
				"success": {"metal": 10, "gold": 5},
				"failure": {},
			},
		},
	},
	{
		"id": "diplomatic_incident",
		"name": "Border Incident",
		"description": "A scouting party from a neighbor was caught on your territory.",
		"type": "diplomacy",
		"min_year": 1,
		"weight": 7,
		"min_threat": 1.0,
		"max_threat": 3.5,
		"outcomes": {
			"protest": {
				"label": "Send a formal protest",
				"description": "Demand an explanation. May hurt relations.",
				"success_chance": 0.6,
				"success": {},
				"failure": {"relation_penalty": -15},
			},
			"ignore": {
				"label": "Let it slide",
				"description": "Pretend it didn't happen.",
				"success_chance": 1.0,
				"success": {},
				"failure": {},
			},
			"retaliate": {
				"label": "Send warriors!",
				"description": "This is an act of war!",
				"success_chance": 0.5,
				"success": {"relation_penalty": -40, "enemy_casualties": 5},
				"failure": {"relation_penalty": -60, "population_change": -2},
			},
		},
	},
	{
		"id": "demon_invasion",
		"name": "Demon Invasion!",
		"description": "A rift has torn open and demonic forces pour through!",
		"type": "threat",
		"min_year": 3,
		"weight": 5,
		"min_threat": 2.0,
		"max_threat": 5.0,
		"outcomes": {
			"fight": {
				"label": "Rally the defenders",
				"description": "Every warrior must stand against this evil.",
				"success_chance": 0.4,
				"success": {"population_change": -5, "metal": 20, "gold": 30},
				"failure": {"population_change": -15, "food": -50, "metal": -20},
			},
			"ritual": {
				"label": "Perform a binding ritual",
				"description": "Ancient magic may seal the portal.",
				"success_chance": 0.5,
				"success": {"food": -30, "gold": -20},
				"failure": {"population_change": -10, "food": -40},
			},
		},
	},
]

var _event_cooldown: int = 0
const EVENT_MIN_TICKS: int = 30
var _scene_cache: Node

# --- Diegetic Threat Scaling (DF-style) ---
# The world IS the difficulty curve. Biome, wealth, and proximity determine threat.
# Difficulty slider only scales how MUCH the diegetic systems affect you.
var _adaptation_score: float = 1.0
var _last_loss_tick: int = 0

func _ready() -> void:
	_scene_cache = get_tree().current_scene
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.battle_fought.connect(_on_battle_fought)

func _on_tick_advanced(tick: int, _day: int, _season: String, _year: int) -> void:
	_event_cooldown -= 1
	if _event_cooldown > 0:
		return

	# Escalate threat over time when no recent losses
	if tick % 30 == 0:
		_update_adaptation(tick)

	var threat_mult = _calculate_threat_multiplier()
	if randf() > 0.15 * threat_mult:
		return

	_trigger_random_event(threat_mult)

func _trigger_random_event(threat_mult: float = 1.0) -> void:
	var data = ColonyData
	var eligible: Array[Dictionary] = []

	for ev in event_pool:
		if data.current_year >= ev["min_year"]:
			var min_t: float = ev.get("min_threat", 0.0)
			var max_t: float = ev.get("max_threat", 99.0)
			if threat_mult >= min_t and threat_mult <= max_t:
				eligible.append(ev)

	if eligible.is_empty():
		return

	# Bad events reduce adaptation (player struggles → threat dials back)
	var selected: Dictionary = _pick_weighted_event(eligible)
	if selected.get("type", "") in ["threat", "crisis"]:
		_adaptation_score = max(_adaptation_score - 0.1, 0.5)

	_event_cooldown = EVENT_MIN_TICKS
	EventBus.event_triggered.emit(ColonyData.player_nation_id, selected["id"], selected)

func _pick_weighted_event(eligible: Array[Dictionary]) -> Dictionary:
	var total_weight = 0
	for ev in eligible:
		total_weight += ev["weight"]

	var roll = randi() % total_weight
	var cumulative = 0

	for ev in eligible:
		cumulative += ev["weight"]
		if roll < cumulative:
			return ev
	return {}

func _calculate_threat_multiplier() -> float:
	var nat = ColonyData.get_player_nation()
	if nat.is_empty():
		return 1.0

	# Diegetic threat: the world IS the difficulty curve
	var biome_t = _calculate_biome_threat(nat)
	var wealth_t = _calculate_wealth_attraction(nat)
	var proximity_t = _calculate_proximity_threat(nat)
	var diff_scale = _get_difficulty_threat_scale()

	return clamp(biome_t * wealth_t * proximity_t * _adaptation_score * diff_scale, 0.4, 5.0)

# --- Diegetic Threat Components ---

func _calculate_biome_threat(nation: Dictionary) -> float:
	var capital = ColonyData.get_tile(nation["capital_x"], nation["capital_y"])
	var terrain = capital["terrain"]
	var threat_map = {
		"plains": 0.8, "forest": 1.0, "hills": 1.2, "mountain": 1.5,
		"swamp": 1.3, "desert": 1.0, "caves": 1.8, "coast": 0.9,
	}
	return threat_map.get(terrain, 1.0)

func _calculate_wealth_attraction(nation: Dictionary) -> float:
	var total_wealth = 0.0
	for r in nation["resources"]:
		total_wealth += nation["resources"][r] * 0.01
	return clamp(total_wealth / 500.0, 0.5, 3.0)

func _calculate_proximity_threat(nation: Dictionary) -> float:
	var closest_hostile = 9999.0
	for target in ColonyData.nations:
		if target["id"] == nation["id"]:
			continue
		if _get_relation_to(nation["id"], target["id"]) < 30:
			var dist = abs(nation["capital_x"] - target["capital_x"]) + abs(nation["capital_y"] - target["capital_y"])
			if dist < closest_hostile:
				closest_hostile = dist
	return clamp(1.0 + (1.0 - closest_hostile / 100.0), 0.5, 2.5)

func _get_difficulty_threat_scale() -> float:
	var diff_settings: Dictionary = ColonyData.DIFFICULTY_SETTINGS.get(ColonyData.difficulty, ColonyData.DIFFICULTY_SETTINGS["normal"])
	return diff_settings.get("threat_scale", 1.0)

func _get_relation_to(nation_a: int, nation_b: int) -> float:
	if nation_a >= ColonyData.diplomacy_matrix.size():
		return 50.0
	if nation_b >= ColonyData.diplomacy_matrix[nation_a].size():
		return 50.0
	return ColonyData.diplomacy_matrix[nation_a][nation_b]

func _update_adaptation(tick: int) -> void:
	# If no losses in the last 60 ticks, threat creeps up
	if tick - _last_loss_tick > 60:
		_adaptation_score += 0.02
	_adaptation_score = clamp(_adaptation_score, 0.5, 3.0)

func _on_battle_fought(attacker_id: int, defender_id: int, result: Dictionary) -> void:
	var pid = ColonyData.player_nation_id
	var player_losses = false
	if attacker_id == pid:
		player_losses = result.get("attacker_losses", 0) > 0
	elif defender_id == pid:
		player_losses = result.get("defender_losses", 0) > 0

	if player_losses:
		_adaptation_score = max(_adaptation_score - 0.1, 0.5)
		_last_loss_tick = ColonyData.current_tick

func resolve_event(event_id: String, outcome_key: String) -> Dictionary:
	for ev in event_pool:
		if ev["id"] == event_id:
			var outcome = ev["outcomes"].get(outcome_key, {})
			var success = randf() < outcome.get("success_chance", 1.0)
			var effects = outcome["success"] if success else outcome["failure"]
			_apply_event_effects(effects)
			EventBus.event_resolved.emit(ColonyData.player_nation_id, event_id, "success" if success else "failure")
			return {"success": success, "effects": effects}
	return {"success": false, "effects": {}}

func _get_diplomacy_manager() -> Node:
	var root = _scene_cache
	if root:
		var sys = root.get_node_or_null("Systems")
		if sys:
			return sys.get_node_or_null("DiplomacyManager")
	return null

func _apply_event_effects(effects: Dictionary) -> void:
	var nat = ColonyData.get_player_nation()
	if nat.is_empty():
		return

	if effects.has("population_change"):
		nat["population"] += effects["population_change"]
		EventBus.population_changed.emit(nat["id"], nat["population"])

	for res in ["food", "wood", "stone", "metal", "gold"]:
		if effects.has(res):
			nat["resources"][res] += effects[res]

	if effects.has("relation_penalty"):
		var dm = _get_diplomacy_manager()
		if dm:
			for n in ColonyData.nations:
				if n["id"] != nat["id"]:
					dm.change_relation(nat["id"], n["id"], effects["relation_penalty"])
					break

	EventBus.resources_updated.emit(nat["id"], nat["resources"].duplicate())
