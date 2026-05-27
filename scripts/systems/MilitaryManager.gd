class_name MilitaryManager
extends Node

var _military_cache_dirty: bool = true
var _nations_at_war: Dictionary = {}  # "a_b" -> true
var _battles_fired_this_tick: Dictionary = {}
var _scene_cache: Node

func _ready() -> void:
	_scene_cache = get_tree().current_scene
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.population_changed.connect(func(_n, _c): _military_cache_dirty = true)
	EventBus.leader_changed.connect(func(_n, _o, _new): _military_cache_dirty = true)
	EventBus.policy_enacted.connect(func(_n, _p): _military_cache_dirty = true)
	EventBus.policy_revoked.connect(func(_n, _p): _military_cache_dirty = true)
	EventBus.cultural_trait_emerged.connect(func(_n, _t): _military_cache_dirty = true)
	EventBus.cultural_trait_faded.connect(func(_n, _t): _military_cache_dirty = true)
	EventBus.subrace_emerged.connect(func(_n, _o, _new): _military_cache_dirty = true)
	EventBus.war_declared.connect(_on_war_declared)
	EventBus.peace_signed.connect(_on_peace_signed)

func _on_war_declared(a: int, b: int) -> void:
	_nations_at_war[_war_key(a, b)] = true
	_military_cache_dirty = true

func _on_peace_signed(a: int, b: int) -> void:
	_nations_at_war.erase(_war_key(a, b))
	_military_cache_dirty = true

static func _war_key(a: int, b: int) -> String:
	return "%d_%d" % [min(a, b), max(a, b)]

func _on_tick_advanced(_tick: int, _day: int, _season: String, _year: int) -> void:
	_battles_fired_this_tick.clear()
	if _military_cache_dirty:
		for nation in ColonyData.nations:
			recalculate_military(nation)
		_military_cache_dirty = false
		_process_war_battles()

func recalculate_military(nation: Dictionary) -> float:
	var pop: float = float(nation["population"])
	var race_id: String = nation["primary_race"]
	var race_data = ColonyData.RACES.get(race_id, {})
	if race_data.is_empty() and ColonyData.RACE_VARIANTS.has(race_id):
		var variant = ColonyData.RACE_VARIANTS[race_id]
		race_data = ColonyData.RACES.get(variant["parent_race"], {})

	var result: float = pop

	# Race military base: strength * 0.15 for normalization
	var strength: float = race_data.get("traits", {}).get("strength", 1.0)
	result *= strength * 0.15

	# Race military_bonus (orc=1.5, troll=1.8, ogre=2.0, gnome=0.4) and swarm_bonus (goblin=2.0)
	result *= race_data.get("military_bonus", 1.0)
	result *= race_data.get("swarm_bonus", 1.0)

	# Tech weapon multiplier (defaults 1.0 until TechManager exists)
	result *= _get_tech_weapon_multiplier(nation["id"])

	# Doctrine multiplier (defaults 1.0 until DoctrineData exists)
	result *= _get_doctrine_multiplier(race_id)

	# Leader military
	result *= _get_leader_military(nation)

	# Policy military
	result *= _get_policy_military(nation["id"])

	# Genetic military
	result *= nation.get("genetic_modifiers", {}).get("military", 1.0)

	# Government military
	result *= _get_government_military(nation)

	# Cultural military
	result *= _get_cultural_military(nation["id"])

	result = max(result, 1.0)
	nation["military_strength"] = int(result)
	return result

func _get_tech_weapon_multiplier(nation_id: int) -> float:
	var sys = _find_systems_node()
	if sys:
		var tm = sys.get_node_or_null("TechManager")
		if tm and tm.has_method("get_effective_bonus"):
			return tm.get_effective_bonus(nation_id, "weapon")
	return 1.0

func _get_doctrine_multiplier(race_id: String) -> float:
	var sys = _find_systems_node()
	if sys:
		var dd = sys.get_node_or_null("DoctrineData")
		if dd and dd.has_method("get_doctrine_multiplier"):
			return dd.get_doctrine_multiplier(race_id)
	return 1.0

func _get_leader_military(nation: Dictionary) -> float:
	var leader = ColonyData.get_leader_cached(nation["id"])
	if leader.is_empty():
		return 1.0
	var arch_data = ColonyData.LEADER_ARCHETYPES.get(leader["archetype"], {})
	return arch_data.get("nation_effects", {}).get("military_strength", 1.0)

func _get_policy_military(nation_id: int) -> float:
	var pm = _get_policy_manager()
	if not pm:
		return 1.0
	var effects = pm.get_aggregate_policy_effects(nation_id)
	return effects.get("multipliers", {}).get("military_strength", 1.0)

func _get_government_military(nation: Dictionary) -> float:
	var gov: String = nation.get("government", "kingdom")
	return ColonyData.GOVERNMENT_TYPES.get(gov, {}).get("bonuses", {}).get("military", 1.0)

func _get_cultural_military(nation_id: int) -> float:
	var sys = _find_systems_node()
	if not sys:
		return 1.0
	var cm = sys.get_node_or_null("CultureManager")
	if cm and cm.has_method("get_cultural_effects"):
		var cultural = cm.get_cultural_effects(nation_id, "warfare")
		return cultural.get("military_strength", 1.0)
	return 1.0

func _get_doctrine_combat_modifier(race_id: String) -> float:
	var doc = DoctrineData.get_doctrine(race_id)
	var avg = (doc["aggression"] + doc["precision"] + doc["discipline"] + doc["resilience"] + doc["evasion"] + doc["cunning"]) / 6.0
	return avg


func _get_terrain_defense_modifier(nation_id: int) -> float:
	var total_defense: float = 0.0
	var count: int = 0
	for y in range(ColonyData.world_height):
		for x in range(ColonyData.world_width):
			var tile = ColonyData.get_tile(x, y)
			if tile.get("owner", -1) == nation_id:
				var terrain_type: String = tile.get("terrain", "plains")
				var terrain_data: Dictionary = ColonyData.TERRAINS.get(terrain_type, {})
				total_defense += terrain_data.get("defense_bonus", 0)
				count += 1
	if count == 0:
		return 1.0
	var avg = total_defense / count
	return 1.0 + avg * 0.1


func _get_policy_manager() -> Node:
	var sys = _find_systems_node()
	if sys:
		return sys.get_node_or_null("PolicyManager")
	return null


func _find_systems_node() -> Node:
	var root = _scene_cache
	if root:
		return root.get_node_or_null("Systems")
	return null

func _process_war_battles() -> void:
	for war_key in _nations_at_war:
		if _battles_fired_this_tick.has(war_key):
			continue
		var parts = war_key.split("_")
		var a: int = int(parts[0]); var b: int = int(parts[1])
		var nat_a = ColonyData.get_nation_cached(a); var nat_b = ColonyData.get_nation_cached(b)
		if nat_a.is_empty() or nat_b.is_empty(): continue

		var mil_a: float = float(nat_a["military_strength"])
		var mil_b: float = float(nat_b["military_strength"])
		var pop_a: float = float(nat_a["population"])
		var pop_b: float = float(nat_b["population"])

		# Base: population mobilization + standing military
		var base_a = pop_a * 0.1 + mil_a
		var base_b = pop_b * 0.1 + mil_b

		# Doctrine modifier from DoctrineData.get_doctrine()
		var race_a: String = nat_a["primary_race"]
		var race_b: String = nat_b["primary_race"]
		var doctrine_a = _get_doctrine_combat_modifier(race_a)
		var doctrine_b = _get_doctrine_combat_modifier(race_b)

		# Tech modifier
		var tech_a = _get_tech_weapon_multiplier(a)
		var tech_b = _get_tech_weapon_multiplier(b)

		# Terrain modifier (average defense bonus of owned tiles)
		var terrain_a = _get_terrain_defense_modifier(a)
		var terrain_b = _get_terrain_defense_modifier(b)

		# Effective power before luck
		var eff_a = base_a * doctrine_a * tech_a * terrain_a
		var eff_b = base_b * doctrine_b * tech_b * terrain_b

		# Luck with narrower range
		var luck_a = randf_range(0.8, 1.2)
		var luck_b = randf_range(0.8, 1.2)
		eff_a *= luck_a
		eff_b *= luck_b

		var victor = "tie"
		if eff_a > eff_b * 1.3: victor = str(a)
		elif eff_b > eff_a * 1.3: victor = str(b)

		# Losses (same formula as before)
		var total_losses = int(min(mil_a, mil_b) * 0.2)
		var a_losses = int(total_losses * (eff_b / (eff_a + eff_b)))
		var b_losses = total_losses - a_losses

		nat_a["military_strength"] = max(1, nat_a["military_strength"] - a_losses)
		nat_b["military_strength"] = max(1, nat_b["military_strength"] - b_losses)

		_battles_fired_this_tick[war_key] = true
		EventBus.battle_fought.emit(a, b, {"attacker_losses": a_losses, "defender_losses": b_losses, "victor": victor})
		if victor != "tie":
			var winner: int = int(victor)
			var loser: int = a if winner != a else b
			_capture_territory(winner, loser)

func _capture_territory(winner_id: int, loser_id: int) -> void:
	var tiles_to_capture = randi_range(1, 3)
	var captured = 0
	for y in range(ColonyData.world_height):
		for x in range(ColonyData.world_width):
			var tile = ColonyData.get_tile(x, y)
			if tile["owner"] != loser_id:
				continue
			# Check adjacency to winner
			var adjacent = false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx = x + dx
					var ny = y + dy
					if nx < 0 or nx >= ColonyData.world_width or ny < 0 or ny >= ColonyData.world_height:
						continue
					if ColonyData.get_tile(nx, ny)["owner"] == winner_id:
						adjacent = true
						break
				if adjacent:
					break
			if not adjacent:
				continue
			tile["owner"] = winner_id
			ColonyData.set_tile(x, y, tile)
			EventBus.territory_captured.emit(winner_id, x, y)
			captured += 1
			if captured >= tiles_to_capture:
				return

static func get_race_weapon_preference(race_id: String) -> Dictionary:
	var prefs = {
		"orc": {"primary": "stone_weapons", "secondary": "throwing_spears", "style": "raiding"},
		"elf": {"primary": "bows", "secondary": "ambush", "style": "skirmish"},
		"human": {"primary": "balanced_arms", "secondary": "formations", "style": "structured"},
		"dwarf": {"primary": "heavy_armor", "secondary": "axes", "style": "individual"},
		"halfling": {"primary": "slings", "secondary": "skirmish", "style": "defensive"},
		"goblin": {"primary": "traps", "secondary": "swarm", "style": "cunning"},
		"troll": {"primary": "clubs", "secondary": "brutality", "style": "rampage"},
		"ogre": {"primary": "clubs", "secondary": "devastation", "style": "destruction"},
		"gnome": {"primary": "crossbows", "secondary": "engineering", "style": "tactical"},
	}
	return prefs.get(race_id, prefs["human"])
