class_name TechManager
extends Node

# =============================================================================
# RUNTIME STATE
# =============================================================================

var research_points: Dictionary = {}
var unlocked_techs: Dictionary = {}
var current_era: Dictionary = {}

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)

func _on_tick_advanced(_tick: int, _day: int, _season: String, _year: int) -> void:
	for nation in ColonyData.nations:
		var nid: int = nation["id"]
		if not research_points.has(nid):
			research_points[nid] = 0.0
			unlocked_techs[nid] = []
			current_era[nid] = "stone"

		# Research accumulation: population * intelligence * race affinity
		var race_id: String = nation["primary_race"]
		var race_data = ColonyData.RACES.get(race_id, {})
		var intelligence: float = race_data.get("traits", {}).get("intelligence", 1.0)
		var affinity = TechData.RACE_TECH_AFFINITY.get(race_id, 1.0)
		research_points[nid] += float(nation["population"]) * intelligence * affinity * 0.01

# =============================================================================
# TECH UNLOCKING
# =============================================================================

func can_unlock_tech(nation_id: int, tech_id: String) -> bool:
	var tech = TechData.get_tech(tech_id)
	if tech.is_empty():
		return false
	if tech_id in unlocked_techs.get(nation_id, []):
		return false
	if research_points.get(nation_id, 0.0) < tech["cost"]:
		return false
	for req in tech.get("requires", []):
		if req not in unlocked_techs.get(nation_id, []):
			return false
	return true

func unlock_tech(nation_id: int, tech_id: String) -> bool:
	if not can_unlock_tech(nation_id, tech_id):
		return false

	var tech = TechData.get_tech(tech_id)
	research_points[nation_id] -= tech["cost"]
	unlocked_techs[nation_id].append(tech_id)

	# Check era advancement
	var count = unlocked_techs[nation_id].size()
	for era in TechData.ERAS:
		if count >= TechData.ERA_THRESHOLDS.get(era, 999):
			var prev_era = current_era[nation_id]
			current_era[nation_id] = era
			if prev_era != era:
				EventBus.era_advanced.emit(nation_id, era)

	EventBus.tech_unlocked.emit(nation_id, tech_id)

	# Side effect: basic_weapons unlocks militia_training policy
	if tech_id == "basic_weapons":
		var pm = _get_policy_manager()
		if pm:
			pm.all_policies["militia_training"]["unlocked"] = true

	return true

# =============================================================================
# QUERIES
# =============================================================================

func get_available_techs(nation_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for era in TechData.TECH_TREES:
		for tech in TechData.TECH_TREES[era]:
			var t = tech.duplicate()
			t["era"] = era
			t["unlockable"] = can_unlock_tech(nation_id, tech["id"])
			t["unlocked"] = tech["id"] in unlocked_techs.get(nation_id, [])
			result.append(t)
	return result

func get_effective_bonus(nation_id: int, key: String) -> float:
	var bonus = 1.0
	var prefix = "unlocks_" + key
	for tech_id in unlocked_techs.get(nation_id, []):
		var tech = TechData.get_tech(tech_id)
		if tech.has(prefix):
			bonus += tech[prefix]
	return bonus

func _get_policy_manager() -> Node:
	var root = get_tree().current_scene
	if root:
		var sys = root.get_node_or_null("Systems")
		if sys:
			return sys.get_node_or_null("PolicyManager")
	return null
