class_name ResourceManager
extends Node

# Tracks production/consumption per nation based on territory

func _ready() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)

func _on_tick_advanced(_tick: int, _day: int, _season: String, _year: int) -> void:
	for nation in ColonyData.nations:
		_process_nation_resources(nation)
		_clamp_resources(nation)
	EventBus.resources_updated.emit(ColonyData.player_nation_id, _player_resources())

func _process_nation_resources(nation: Dictionary) -> void:
	var data = ColonyData
	var bm = _get_building_manager()
	var tiles: Dictionary = bm.get_territory_counts(nation["id"]) if bm else {}
	var pop = nation["population"]
	var race_id: String = nation["primary_race"]
	var race_data = ColonyData.RACES.get(race_id, {})
	var terrain_bonuses: Dictionary = race_data.get("terrain_bonuses", {})
	var econ_bonuses: Dictionary = race_data.get("economic_bonuses", {})
	
	# Subrace variant bonus modifiers merge into econ_bonuses
	if ColonyData.RACE_VARIANTS.has(race_id):
		var variant = ColonyData.RACE_VARIANTS[race_id]
		var mods: Dictionary = variant.get("bonus_modifiers", {})
		for key in ["food", "wood", "stone", "metal", "gold", "trade", "production"]:
			if mods.has(key):
				econ_bonuses[key] = econ_bonuses.get(key, 1.0) * mods[key]
	
	var seasonal_mod = seasonal_modifier(data.current_season)
	var nid: int = nation["id"]

	# Production from territory (race-aware terrain bonuses applied per tile)
	var food_prod = tiles.get("plains", 0) * 0.75 * terrain_bonuses.get("plains", 1.0) + tiles.get("forest", 0) * 0.3 * terrain_bonuses.get("forest", 1.0) + tiles.get("swamp", 0) * 0.225 * terrain_bonuses.get("swamp", 1.0)
	var wood_prod = tiles.get("forest", 0) * 0.6 * terrain_bonuses.get("forest", 1.0)
	var stone_prod = tiles.get("hills", 0) * 0.45 * terrain_bonuses.get("hills", 1.0) + tiles.get("mountain", 0) * 0.75 * terrain_bonuses.get("mountain", 1.0)
	var metal_prod = tiles.get("mountain", 0) * 0.25 * terrain_bonuses.get("mountain", 1.0) + tiles.get("caves", 0) * 0.35 * terrain_bonuses.get("caves", 1.0)
	var gold_prod = tiles.get("desert", 0) * 0.075 + tiles.get("mountain", 0) * 0.075 * terrain_bonuses.get("mountain", 1.0)

	# --- Race economic bonuses (applied before deity/policy/cultural multipliers) ---
	if econ_bonuses.has("food"):
		food_prod *= econ_bonuses["food"]
	if econ_bonuses.has("metal"):
		metal_prod *= econ_bonuses["metal"]
	if econ_bonuses.has("stone"):
		stone_prod *= econ_bonuses["stone"]
	if econ_bonuses.has("trade"):
		gold_prod *= econ_bonuses["trade"]
	if econ_bonuses.has("wood"):
		wood_prod *= econ_bonuses["wood"]
	if econ_bonuses.has("gold"):
		gold_prod *= econ_bonuses["gold"]
	if econ_bonuses.has("production"):
		var prod_pm: float = econ_bonuses["production"]
		food_prod *= prod_pm
		wood_prod *= prod_pm
		stone_prod *= prod_pm
		metal_prod *= prod_pm
		gold_prod *= prod_pm

	# --- Building effects ---
	var bfx: Dictionary = _get_building_effects(nid)
	if bfx.has("food"): food_prod *= bfx["food"]
	if bfx.has("wood"): wood_prod *= bfx["wood"]
	if bfx.has("stone"): stone_prod *= bfx["stone"]
	if bfx.has("metal"): metal_prod *= bfx["metal"]
	if bfx.has("trade"): gold_prod *= bfx["trade"]
	if bfx.has("production"): 
		food_prod *= bfx["production"]
		wood_prod *= bfx["production"]
		stone_prod *= bfx["production"]
		metal_prod *= bfx["production"]

	# --- Deity passive bonus (only if nation has belief) ---
	var dm = _get_deity_manager()
	if dm and _nation_has_belief(nid):
		var passive = dm.get_class_passive_bonus()
		if passive.has("production"):
			var prod_mult: float = passive["production"]
			food_prod *= prod_mult
			wood_prod *= prod_mult
			stone_prod *= prod_mult
			metal_prod *= prod_mult
			gold_prod *= prod_mult
		if passive.has("food_production"):
			food_prod *= passive["food_production"]
		if passive.has("trade_income"):
			gold_prod *= passive["trade_income"]
		if passive.has("crafting_speed"):
			wood_prod *= passive["crafting_speed"]
			stone_prod *= passive["crafting_speed"]
			metal_prod *= passive["crafting_speed"]
		if passive.has("undead_labor"):
			var ul: float = passive["undead_labor"]
			wood_prod *= (1.0 + ul)
			stone_prod *= (1.0 + ul)
			metal_prod *= (1.0 + ul)

	# --- Skill tree bonuses ---
	if dm:
		food_prod *= dm.get_effective_bonus("food_production")
		metal_prod *= dm.get_effective_bonus("metal")
		stone_prod *= dm.get_effective_bonus("stone")
		gold_prod *= dm.get_effective_bonus("trade_income")

	# --- Policy effects ---
	var pol_pm = _get_policy_manager()
	var policy_effects = pol_pm.get_aggregate_policy_effects(nid) if pol_pm else {"multipliers": {}, "additives": {}}
	var pol_mult: Dictionary = policy_effects.get("multipliers", {})
	if pol_mult.has("production"):
		var pm: float = pol_mult["production"]
		wood_prod *= pm
		stone_prod *= pm
		metal_prod *= pm
	if pol_mult.has("gold"):
		gold_prod *= pol_mult["gold"]
	if pol_mult.has("trade_income"):
		gold_prod *= pol_mult["trade_income"]

	# Food consumption multiplier from policies
	var food_consumption_mult = pol_mult.get("food_consumption", 1.0)

	# --- Cultural economy effects ---
	var cm = _get_culture_manager()
	if cm:
		var cultural = cm.get_cultural_effects(nid, "economy")
		if cultural.has("production"):
			var cp: float = cultural["production"]
			food_prod *= cp
			wood_prod *= cp
			stone_prod *= cp
			metal_prod *= cp
		if cultural.has("food"):
			food_prod *= cultural["food"]
		if cultural.has("stone"):
			stone_prod *= cultural["stone"]
		if cultural.has("metal"):
			metal_prod *= cultural["metal"]
		if cultural.has("gold"):
			gold_prod *= cultural["gold"]
		if cultural.has("trade_income"):
			gold_prod *= cultural["trade_income"]

	# Apply seasonal modifiers
	food_prod *= seasonal_mod["food"]
	gold_prod *= seasonal_mod["trade"]

	# Apply difficulty resource_rate modifier (final production multiplier before clamping)
	var diff_settings: Dictionary = ColonyData.DIFFICULTY_SETTINGS.get(ColonyData.difficulty, ColonyData.DIFFICULTY_SETTINGS["normal"])
	var resource_rate: float = diff_settings.get("resource_rate", 1.0)
	food_prod *= resource_rate
	wood_prod *= resource_rate
	stone_prod *= resource_rate
	metal_prod *= resource_rate
	gold_prod *= resource_rate

	# Add to nation resources
	nation["resources"]["food"] += food_prod
	nation["resources"]["wood"] += wood_prod
	nation["resources"]["stone"] += stone_prod
	nation["resources"]["metal"] += metal_prod
	nation["resources"]["gold"] += gold_prod

	# Calculate and store deficits before consumption hits the stockpile
	_calculate_and_store_deficits(nation, food_prod, wood_prod, stone_prod, metal_prod, gold_prod)

	# Consumption (with policy-modified food consumption)
	nation["resources"]["food"] -= pop * 0.12 * food_consumption_mult

	# Military maintenance (modified by seasonal military_speed)
	var effective_mil: float = nation["military_strength"] * seasonal_mod["military_speed"]
	if nation["military_strength"] > 0:
		nation["resources"]["food"] -= effective_mil * 0.005
		nation["resources"]["metal"] -= effective_mil * 0.002

	# Building maintenance
	_apply_building_maintenance(nation)

	if nation["resources"]["food"] <= 0:
		nation["resources"]["food"] = 0.0
		EventBus.resource_critical.emit(nation["id"], "food", 0.0)


func _nation_has_belief(nation_id: int) -> bool:
	for race_id in ColonyData.RACES:
		if ColonyData.get_belief(nation_id, race_id) > 0.05:
			return true
	return false


func _resource_capacity(nation: Dictionary) -> float:
	return float(nation["population"]) * 8.0


func _calculate_and_store_deficits(nation: Dictionary, food_prod: float, wood_prod: float, stone_prod: float, metal_prod: float, gold_prod: float) -> void:
	var res = nation["resources"]
	var pop: float = float(nation["population"])
	var mil: float = float(nation["military_strength"])
	var cap: float = _resource_capacity(nation)

	# Calculate consumption per tick (with seasonal military_speed)
	var season = ColonyData.current_season
	var sm = seasonal_modifier(season)
	var effective_mil_def: float = mil * sm["military_speed"]
	var food_cons = pop * 0.12 + effective_mil_def * 0.005
	var metal_cons = effective_mil_def * 0.002
	var wood_cons = 0.0  # only via policy costs, not passive
	var stone_cons = 0.0
	var gold_cons = 0.0

	# Calculate deficits (consumption - production, positive = shortage)
	var deficits = {}

	var food_def = food_cons - food_prod
	deficits["food"] = {"deficit": food_def, "urgency": max(0.0, food_def) / max(1.0, res.get("food", 0.0)), "decline_rate": food_def}

	var wood_def = wood_cons - wood_prod
	deficits["wood"] = {"deficit": wood_def, "urgency": max(0.0, wood_def) / max(1.0, res.get("wood", 0.0)), "decline_rate": wood_def}

	var stone_def = stone_cons - stone_prod
	deficits["stone"] = {"deficit": stone_def, "urgency": max(0.0, stone_def) / max(1.0, res.get("stone", 0.0)), "decline_rate": stone_def}

	var metal_def = metal_cons - metal_prod
	deficits["metal"] = {"deficit": metal_def, "urgency": max(0.0, metal_def) / max(1.0, res.get("metal", 0.0)), "decline_rate": metal_def}

	var gold_def = gold_cons - gold_prod
	deficits["gold"] = {"deficit": gold_def, "urgency": max(0.0, gold_def) / max(1.0, res.get("gold", 0.0)), "decline_rate": gold_def}

	nation["resource_deficits"] = deficits

	# Emit critical alerts
	for rname in deficits:
		var d: Dictionary = deficits[rname]
		var stockpile: float = res.get(rname, 0.0)
		if stockpile < 0.2 * cap and d["deficit"] > 0.0:
			EventBus.resource_deficit_alert.emit(nation["id"], rname, d["deficit"], d["urgency"])
			if rname == "food":
				EventBus.resource_critical.emit(nation["id"], rname, stockpile)


func _get_deity_manager() -> Node:
	var root = get_tree().current_scene
	if root:
		var sys = root.get_node_or_null("Systems")
		if sys:
			return sys.get_node_or_null("DeityManager")
	return null


func _get_culture_manager() -> Node:
	var root = get_tree().current_scene
	if root:
		var sys = root.get_node_or_null("Systems")
		if sys:
			return sys.get_node_or_null("CultureManager")
	return null

func seasonal_modifier(season: String) -> Dictionary:
	match season:
		"Spring": return {"food": 1.1, "growth": 1.2, "trade": 1.0, "military_speed": 1.0, "mortality": 1.0}
		"Summer": return {"food": 1.0, "growth": 1.1, "trade": 1.15, "military_speed": 1.1, "mortality": 0.9}
		"Autumn": return {"food": 1.3, "growth": 0.9, "trade": 1.0, "military_speed": 1.0, "mortality": 1.0}
		"Winter": return {"food": 0.4, "growth": 0.5, "trade": 0.7, "military_speed": 0.8, "mortality": 1.2}
	return {"food": 1.0, "growth": 1.0, "trade": 1.0, "military_speed": 1.0, "mortality": 1.0}

func _clamp_resources(nation: Dictionary) -> void:
	var cap = nation["population"] * 8
	for res in nation["resources"]:
		nation["resources"][res] = clamp(nation["resources"][res], 0.0, float(cap))

func _player_resources() -> Dictionary:
	var nat = ColonyData.get_player_nation()
	if nat.is_empty():
		return {}
	return nat["resources"].duplicate()


func _get_government_bonus(nation: Dictionary, resource_name: String) -> float:
	var gov: String = nation.get("government", "kingdom")
	var gov_data = ColonyData.GOVERNMENT_TYPES.get(gov, {})
	var bonuses: Dictionary = gov_data.get("bonuses", {})
	return bonuses.get(resource_name, 1.0)


func _get_building_effects(nation_id: int) -> Dictionary:
	var effects = {}
	var bm = _get_building_manager()
	if not bm:
		return effects
	var counts: Dictionary = bm.get_nation_building_counts(nation_id)
	for building_id in counts:
		var bdata = ColonyData.BUILDINGS.get(building_id, {})
		var bfx: Dictionary = bdata.get("effects", {})
		for key in bfx:
			effects[key] = effects.get(key, 0.0) + bfx[key] * counts[building_id]
	return effects


func _apply_building_maintenance(nation: Dictionary) -> void:
	var counts: Dictionary = _get_building_manager().get_nation_building_counts(nation["id"])
	for building_id in counts:
		var bdata = ColonyData.BUILDINGS.get(building_id, {})
		var maint: Dictionary = bdata.get("maintenance", {})
		for res in maint:
			nation["resources"][res] -= maint[res] * counts[building_id]


func _get_building_manager() -> Node:
	var sys = _find_systems_node()
	if sys:
		return sys.get_node_or_null("BuildingManager")
	return null


func _get_policy_manager() -> Node:
	var sys = _find_systems_node()
	if sys:
		return sys.get_node_or_null("PolicyManager")
	return null


func _find_systems_node() -> Node:
	var root = get_tree().current_scene
	if root:
		return root.get_node_or_null("Systems")
	return null
