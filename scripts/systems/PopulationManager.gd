class_name PopulationManager
extends Node

const INTERBREEDING_CHECK_INTERVAL: int = 60

var _subrace_tick_counter: int = 0
var _nation_terrain_history: Dictionary = {}  # {nation_id: {terrain: consecutive_ticks}}

func _ready() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)

func _on_tick_advanced(tick: int, _day: int, _season: String, _year: int) -> void:
	for nation in ColonyData.nations:
		_process_nation_population(nation, tick)
	if tick % INTERBREEDING_CHECK_INTERVAL == 0:
		for nation in ColonyData.nations:
			_process_genetics(nation)

	_subrace_tick_counter += 1
	if _subrace_tick_counter % 30 == 0:
		for nation in ColonyData.nations:
			_check_subrace_emergence(nation)

func _process_nation_population(nation: Dictionary, tick: int) -> void:
	var race_id = nation["primary_race"]
	var race = ColonyData.RACES.get(race_id, ColonyData.RACES["human"])
	var fertility = race["traits"]["fertility"]

	# Food-based growth
	var food_mod = 1.0
	if nation["resources"]["food"] < nation["population"] * 0.3:
		food_mod = 0.1
	elif nation["resources"]["food"] > nation["population"] * 1.5:
		food_mod = 1.5

	# Population growth (every 60 ticks ~ 1 season)
	if tick % 60 == 0 and nation["id"] >= 0:
		var growth_chance = 0.15 * fertility * food_mod

		# Apply difficulty growth_rate modifier
		var diff_settings: Dictionary = ColonyData.DIFFICULTY_SETTINGS.get(ColonyData.difficulty, ColonyData.DIFFICULTY_SETTINGS["normal"])
		growth_chance *= diff_settings.get("growth_rate", 1.0)

		# Apply genetic fertility modifier if available
		var genetic_fertility: float = 1.0
		if nation.has("genetic_modifiers") and nation["genetic_modifiers"].has("fertility"):
			genetic_fertility = nation["genetic_modifiers"]["fertility"]
		growth_chance *= genetic_fertility

		# Apply seasonal growth modifier
		var rm = _get_resource_manager()
		if rm:
			var sm: Dictionary = rm.seasonal_modifier(ColonyData.current_season)
			growth_chance *= sm.get("growth", 1.0)

		if randf() < growth_chance:
			nation["population"] += 1
			EventBus.population_changed.emit(nation["id"], nation["population"])
			EventBus.colonist_arrived.emit(nation["id"], 1)

	# Starvation check (population loss, victory/loss handled by VictoryManager)
	if nation["resources"]["food"] <= 0 and nation["population"] > 0:
		var mortality_mod: float = 1.0
		var rm = _get_resource_manager()
		if rm:
			var sm: Dictionary = rm.seasonal_modifier(ColonyData.current_season)
			mortality_mod = sm.get("mortality", 1.0)
		if randf() < 0.15 * mortality_mod:
			nation["population"] -= 1
			EventBus.population_changed.emit(nation["id"], nation["population"])
			EventBus.colonist_died.emit(nation["id"], "starvation")

func _process_genetics(nation: Dictionary) -> void:
	var nation_id: int = nation["id"]
	if nation_id < 0:
		return

	var demographics: Dictionary = nation.get("race_demographics", {})
	var significant_races = 0
	for prop in demographics.values():
		if prop > 0.05:
			significant_races += 1
	if significant_races < 2:
		return

	_init_population_genetics(nation_id)

	# Interbreeding: check each pair of distinct races with proportion > 0.05
	var races = demographics.keys()
	for i in range(races.size()):
		for j in range(i + 1, races.size()):
			var race_a: String = races[i]
			var race_b: String = races[j]
			var prop_a: float = demographics[race_a]
			var prop_b: float = demographics[race_b]
			if prop_a <= 0.05 or prop_b <= 0.05:
				continue

			var tendency = ColonyData.get_interbreeding_tendency(race_a, race_b)

			# Cultural modifiers from policies
			if "open_borders" in nation.get("policies", []):
				tendency *= 1.3

			# Cultural trait modifiers (xenophobic reduces, cosmopolitan increases)
			var culture = ColonyData.nation_culture.get(nation_id, {})
			for trait_id in culture:
				var trait_data: Dictionary = ColonyData.CULTURAL_TRAITS.get(trait_id, {})
				var effects: Dictionary = trait_data.get("effects", {})
				if effects.has("interbreeding"):
					tendency *= effects["interbreeding"]

			# Roll for interbreeding event
			if randf() < tendency * 0.15:
				var sorted_pair = [race_a, race_b]
				sorted_pair.sort()
				var hybrid_key: String = sorted_pair[0] + "_" + sorted_pair[1]

				var hybrid_proportion: float = min(prop_a, prop_b) * 0.1

				if not ColonyData.hybrid_demographics.has(nation_id):
					ColonyData.hybrid_demographics[nation_id] = {}
				var hd = ColonyData.hybrid_demographics[nation_id]
				hd[hybrid_key] = hd.get(hybrid_key, 0.0) + hybrid_proportion

				demographics[race_a] = max(0.0, prop_a - hybrid_proportion * 0.5)
				demographics[race_b] = max(0.0, prop_b - hybrid_proportion * 0.5)

				var hybrid_traits = ColonyData.create_hybrid_traits(race_a, race_b)
				if not nation.has("hybrid_traits"):
					nation["hybrid_traits"] = {}
				nation["hybrid_traits"][hybrid_key] = hybrid_traits

				EventBus.event_triggered.emit(nation_id, "hybrid_population_emerged",
					{"hybrid": hybrid_key, "proportion": hybrid_proportion})

	# Genetic drift (every check, not just on interbreeding)
	var genetics: Dictionary = ColonyData.population_genetics.get(nation_id, {})
	if genetics.is_empty():
		return

	var pop: int = max(nation.get("population", 1), 1)
	var drift_modifier: float = max(0.5, 500.0 / float(pop))

	var primary_race: String = nation.get("primary_race", "")
	var race_genetics: Dictionary = ColonyData.get_race_genetics(primary_race)

	for gene_id in genetics.keys():
		var gene_data: Dictionary = race_genetics.get(gene_id, {})
		var dominance: String = gene_data.get("dominance", "recessive")
		var freq: float = genetics[gene_id]
		if dominance == "dominant":
			freq = min(1.0, freq + 0.01 * drift_modifier)
		else:
			freq = max(0.0, freq - 0.005 * drift_modifier)
		genetics[gene_id] = freq

	# Update nation genetic modifiers from gene frequencies
	if not nation.has("genetic_modifiers"):
		nation["genetic_modifiers"] = {}

	var fertility_freq: float = genetics.get("fertility_gene", 0.0)
	var strength_freq: float = genetics.get("strength_gene", 0.0)

	if fertility_freq > 0.7:
		nation["genetic_modifiers"]["fertility"] = 1.0 + (fertility_freq - 0.7) * 0.33
	else:
		nation["genetic_modifiers"].erase("fertility")

	if strength_freq > 0.7:
		nation["genetic_modifiers"]["military"] = 1.0 + (strength_freq - 0.7) * 0.33
	else:
		nation["genetic_modifiers"].erase("military")

func _check_subrace_emergence(nation: Dictionary) -> void:
	var race_id = nation["primary_race"]
	var nid: int = nation["id"]

	# Track terrain dominance
	if not _nation_terrain_history.has(nid):
		_nation_terrain_history[nid] = {}

	var capital_terrain = ColonyData.get_tile(nation["capital_x"], nation["capital_y"])["terrain"]
	var history: Dictionary = _nation_terrain_history[nid]
	history[capital_terrain] = history.get(capital_terrain, 0) + 30

	# Check each subrace variant
	for variant_id in ColonyData.RACE_VARIANTS:
		var variant = ColonyData.RACE_VARIANTS[variant_id]
		if variant["parent_race"] != race_id:
			continue
		if nation.get("has_subrace", false):
			continue

		# Check terrain triggers
		var triggered = false
		for trigger_terrain in variant["terrain_triggers"]:
			if history.get(trigger_terrain, 0) >= variant["emergence_generations"]:
				triggered = true
				break

		if not triggered:
			continue

		# Emergence!
		var old_race = nation["primary_race"]
		nation["primary_race"] = variant_id
		nation["has_subrace"] = true
		if not nation.has("race_history"):
			nation["race_history"] = []
		nation["race_history"].append({"tick": ColonyData.current_tick, "from": old_race, "to": variant_id})
		EventBus.subrace_emerged.emit(nid, old_race, variant_id)
		print("[Subrace] %s developed into %s at tick %d" % [nation["name"], variant["name"], ColonyData.current_tick])
		break

func _init_population_genetics(nation_id: int) -> void:
	if ColonyData.population_genetics.has(nation_id):
		return

	var nation = ColonyData.get_nation(nation_id)
	if nation.is_empty():
		return

	var primary_race: String = nation.get("primary_race", "")
	var race_genetics: Dictionary = ColonyData.get_race_genetics(primary_race)

	var genetics = {}
	for gene_id in race_genetics:
		genetics[gene_id] = 1.0

	ColonyData.population_genetics[nation_id] = genetics

func _get_deity_manager() -> Node:
	var root = get_tree().current_scene
	if root:
		var sys = root.get_node_or_null("Systems")
		if sys:
			return sys.get_node_or_null("DeityManager")
	return null

func _get_resource_manager() -> Node:
	var root = get_tree().current_scene
	if root:
		var sys = root.get_node_or_null("Systems")
		if sys:
			return sys.get_node_or_null("ResourceManager")
	return null


func _nation_has_belief(nation_id: int) -> bool:
	for race_id in ColonyData.RACES:
		if ColonyData.get_belief(nation_id, race_id) > 0.05:
			return true
	return false
