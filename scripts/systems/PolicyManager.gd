class_name PolicyManager
extends Node

var all_policies: Dictionary = {
	"tavern_open": {
		"name": "Open Taverns",
		"description": "Allow brewing and serving of ale. Improves morale, consumes food.",
		"cost": {"gold": 5},
		"category": "social",
		"unlocked": true,
	},
	"mandatory_labor": {
		"name": "Mandatory Labor",
		"description": "All able-bodied work longer hours. More resources, less morale.",
		"cost": {},
		"category": "labor",
		"unlocked": true,
	},
	"sanitation_mandate": {
		"name": "Sanitation Mandate",
		"description": "Enforce cleanliness. Improves health, costs wood.",
		"cost": {"wood": 10},
		"category": "infrastructure",
		"unlocked": true,
	},
	"militia_training": {
		"name": "Militia Training",
		"description": "Train civilians in basic combat. Better defense, costs production.",
		"cost": {"metal": 5},
		"category": "military",
		"unlocked": false,
	},
	"open_borders": {
		"name": "Open Borders",
		"description": "Allow free movement of traders and travelers. More trade, more migration.",
		"cost": {},
		"category": "diplomacy",
		"unlocked": true,
	},
	"heavy_taxation": {
		"name": "Heavy Taxation",
		"description": "Increase taxes to fill the treasury. Angers the populace.",
		"cost": {},
		"category": "economy",
		"unlocked": true,
	},
}

func _ready() -> void:
	EventBus.policy_enacted.connect(_on_policy_enacted)

func enact_policy(nation_id: int, policy_id: String) -> bool:
	if not all_policies.has(policy_id):
		return false

	var policy = all_policies[policy_id]
	if not policy["unlocked"]:
		return false

	var nation = ColonyData.get_nation(nation_id)
	if nation.is_empty():
		return false

	if policy_id in nation["policies"]:
		return false

	# Check costs
	for resource in policy["cost"]:
		var required: float = float(policy["cost"][resource])
		if nation["resources"].get(resource, 0.0) < required:
			return false

	for resource in policy["cost"]:
		nation["resources"][resource] -= float(policy["cost"][resource])

	nation["policies"].append(policy_id)
	EventBus.policy_enacted.emit(nation_id, policy_id)
	return true

func revoke_policy(nation_id: int, policy_id: String) -> bool:
	var nation = ColonyData.get_nation(nation_id)
	if nation.is_empty():
		return false
	if policy_id not in nation["policies"]:
		return false
	nation["policies"].erase(policy_id)
	EventBus.policy_revoked.emit(nation_id, policy_id)
	return true

func get_available_policies(nation_id: int) -> Array[Dictionary]:
	var nation = ColonyData.get_nation(nation_id)
	if nation.is_empty():
		return []
	var result: Array[Dictionary] = []
	for id in all_policies:
		var p = all_policies[id]
		if p["unlocked"] and id not in nation["policies"]:
			result.append(p.duplicate())
	return result

func get_active_policies(nation_id: int) -> Array[Dictionary]:
	var nation = ColonyData.get_nation(nation_id)
	if nation.is_empty():
		return []
	var result: Array[Dictionary] = []
	for id in nation["policies"]:
		if all_policies.has(id):
			result.append(all_policies[id].duplicate())
	return result

func _on_policy_enacted(nation_id: int, policy_id: String) -> void:
	if nation_id != ColonyData.player_nation_id:
		return
	print("Policy enacted: %s" % all_policies.get(policy_id, {}).get("name", policy_id))


const POLICY_EFFECTS: Dictionary = {
	"tavern_open": {"morale": 10, "food_consumption": 1.1},
	"mandatory_labor": {"production": 1.15, "morale": -5},
	"sanitation_mandate": {"health": 10},
	"militia_training": {"military_strength": 1.1, "production": 0.95},
	"open_borders": {"trade_income": 1.15, "belief_spread": 1.1},
	"heavy_taxation": {"gold": 1.2, "morale": -10},
}


static func get_policy_effect(policy_id: String) -> Dictionary:
	return POLICY_EFFECTS.get(policy_id, {})


static func get_aggregate_policy_effects(nation_id: int) -> Dictionary:
	var multipliers = {}
	var additives = {}
	var nation = ColonyData.get_nation(nation_id)
	if nation.is_empty():
		return {"multipliers": {}, "additives": {}}

	for policy_id in nation["policies"]:
		var effects = POLICY_EFFECTS.get(policy_id, {})
		for key in effects:
			var val: float = effects[key]
			if abs(val) >= 2.0:
				additives[key] = additives.get(key, 0.0) + val
			else:
				multipliers[key] = multipliers.get(key, 1.0) * val

	return {"multipliers": multipliers, "additives": additives}
