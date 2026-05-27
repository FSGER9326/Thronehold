class_name CultureManager
extends Node

const STARTING_TRAITS: Dictionary = {
	"human": ["cosmopolitan", "innovative"],
	"dwarf": ["industrious", "traditional"],
	"elf": ["devout", "scholarly"],
	"orc": ["warlike", "nomadic"],
	"halfling": ["agrarian", "communal"],
	"goblin": ["nomadic", "hedonistic"],
	"troll": ["warlike", "nomadic"],
	"ogre": ["warlike", "hedonistic"],
	"gnome": ["scholarly", "mercantile"],
}

const MAX_ACTIVE_TRAITS: int = 3

var _tick_counter: int = 0
var _scene_cache: Node

func _ready() -> void:
	_scene_cache = get_tree().current_scene
	EventBus.tick_advanced.connect(_on_tick_advanced)


func _on_tick_advanced(tick: int, _day: int, _season: String, _year: int) -> void:
	_tick_counter += 1
	if _tick_counter % 4 != 0:
		return

	for nation in ColonyData.nations:
		_process_nation_culture(nation)
	_spread_culture_between_nations()


# ── Initialization ───────────────────────────────────────────────────────────

func _init_nation_culture(nation: Dictionary) -> void:
	var nid: int = nation["id"]
	if ColonyData.nation_culture.has(nid) and not ColonyData.nation_culture[nid].is_empty():
		return

	var race_id: String = nation["primary_race"]
	var starting: Array = STARTING_TRAITS.get(race_id, ["traditional"])
	var culture: Dictionary = {}

	for trait_id in starting:
		if ColonyData.CULTURAL_TRAITS.has(trait_id):
			culture[trait_id] = 0.5

	ColonyData.nation_culture[nid] = culture


# ── Per-nation processing ────────────────────────────────────────────────────

func _process_nation_culture(nation: Dictionary) -> void:
	var nid: int = nation["id"]
	_init_nation_culture(nation)

	var culture: Dictionary = ColonyData.nation_culture.get(nid, {})
	if culture.is_empty():
		return

	var race: Dictionary = ColonyData.RACES.get(nation["primary_race"], ColonyData.RACES["human"])
	var base_drift: float = race["traits"].get("drift_rate", 0.03)
	var race_tendencies: Array = race.get("cultural_tendencies", [])
	var leader = ColonyData.get_leader(nid)

	var to_remove: Array[String] = []
	for trait_id in culture.keys():
		var dominance: float = culture[trait_id]
		var favored = _is_trait_favored(trait_id, race_tendencies, leader, nation)

		var drift_amount: float = base_drift * randf_range(0.5, 1.5)
		if favored:
			dominance = min(1.0, dominance + drift_amount)
		else:
			dominance = max(0.0, dominance - drift_amount * 0.5)

		culture[trait_id] = dominance

		if dominance < 0.05:
			to_remove.append(trait_id)

	for trait_id in to_remove:
		culture.erase(trait_id)
		EventBus.cultural_trait_faded.emit(nid, trait_id)

	if culture.size() < MAX_ACTIVE_TRAITS and randf() < 0.12:
		_attempt_trait_emergence(nation, culture, race_tendencies, leader)

	ColonyData.nation_culture[nid] = culture


func _is_trait_favored(trait_id: String, race_tendencies: Array, leader: Dictionary, nation: Dictionary) -> bool:
	if trait_id in race_tendencies:
		return true

	if not leader.is_empty():
		var trait_data: Dictionary = ColonyData.CULTURAL_TRAITS.get(trait_id, {})
		var emergence: Dictionary = trait_data.get("emergence", {})
		if leader["archetype"] in emergence.get("leader_archetypes", []):
			return true

	var ai_type: String = nation.get("ai_type", "")
	match ai_type:
		"aggressive":
			return trait_id in ["warlike", "honor_bound"]
		"trader":
			return trait_id in ["mercantile", "cosmopolitan"]
		"isolationist":
			return trait_id in ["xenophobic", "traditional"]
		"passive":
			return trait_id in ["pacifist", "communal"]

	return false


# ── Trait emergence ──────────────────────────────────────────────────────────

func _attempt_trait_emergence(nation: Dictionary, culture: Dictionary, race_tendencies: Array, leader: Dictionary) -> void:
	var active_ids: Array = culture.keys()
	var candidates: Array[Dictionary] = []

	for trait_id in ColonyData.CULTURAL_TRAITS:
		if trait_id in active_ids:
			continue
		var trait_data: Dictionary = ColonyData.CULTURAL_TRAITS[trait_id]

		var conflicts: Array = trait_data.get("conflicts", [])
		var blocked = false
		for conflict_id in conflicts:
			if conflict_id in active_ids:
				blocked = true
				break
		if blocked:
			continue

		var emergence: Dictionary = trait_data.get("emergence", {})
		if emergence.has("min_military_strength"):
			if nation.get("military_strength", 0) < emergence["min_military_strength"]:
				continue
		if emergence.has("leader_archetypes"):
			if not leader.is_empty() and leader["archetype"] not in emergence["leader_archetypes"]:
				continue

		var weight: float = 4.0 if trait_id in race_tendencies else 1.0
		candidates.append({"id": trait_id, "weight": weight})

	if candidates.is_empty():
		return

	var total_weight: float = 0.0
	for c in candidates:
		total_weight += c["weight"]

	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for c in candidates:
		cumulative += c["weight"]
		if roll <= cumulative:
			culture[c["id"]] = 0.2
			EventBus.cultural_trait_emerged.emit(nation["id"], c["id"])
			return


# ── Cultural spread between nations ──────────────────────────────────────────

func _spread_culture_between_nations() -> void:
	var nations = ColonyData.nations
	for i in range(nations.size()):
		for j in range(i + 1, nations.size()):
			_spread_between_pair(nations[i]["id"], nations[j]["id"])


func _spread_between_pair(a_id: int, b_id: int) -> void:
	var relation: float = _get_relation(a_id, b_id)
	var has_trade = _has_trade_treaty(a_id, b_id)

	if relation <= 50 and not has_trade:
		return

	if randf() > 0.10:
		return

	# Pick direction: A → B or B → A
	var from_id = a_id
	var to_id = b_id
	if randf() < 0.5:
		from_id = b_id
		to_id = a_id

	var source_culture: Dictionary = ColonyData.nation_culture.get(from_id, {})
	if source_culture.is_empty():
		return

	var keys: Array = source_culture.keys()
	var trait_id: String = keys[randi() % keys.size()]
	var dominance: float = source_culture[trait_id]

	# Lower-dominance traits spread less effectively
	if randf() > dominance:
		return

	if not ColonyData.nation_culture.has(to_id):
		ColonyData.nation_culture[to_id] = {}
	var target_culture: Dictionary = ColonyData.nation_culture[to_id]

	if not target_culture.has(trait_id):
		target_culture[trait_id] = 0.15
		EventBus.culture_spread.emit(from_id, to_id, trait_id)


# ── Public API ───────────────────────────────────────────────────────────────

func get_cultural_effects(nation_id: int, category: String) -> Dictionary:
	var culture: Dictionary = ColonyData.nation_culture.get(nation_id, {})
	var aggregated: Dictionary = {}

	for trait_id in culture:
		var trait_data: Dictionary = ColonyData.CULTURAL_TRAITS.get(trait_id, {})
		if trait_data.get("category", "") != category:
			continue

		var effects: Dictionary = trait_data.get("effects", {})
		for key in effects:
			var val: float = effects[key]
			if aggregated.has(key):
				aggregated[key] *= val
			else:
				aggregated[key] = val

	return aggregated


# ── Helpers ──────────────────────────────────────────────────────────────────

func _get_relation(nation_a: int, nation_b: int) -> float:
	if nation_a >= ColonyData.diplomacy_matrix.size():
		return 50.0
	if nation_b >= ColonyData.diplomacy_matrix[nation_a].size():
		return 50.0
	return ColonyData.diplomacy_matrix[nation_a][nation_b]


func _has_trade_treaty(a_id: int, b_id: int) -> bool:
	var dm = _get_diplomacy_manager()
	if not dm:
		return false
	return dm.get_treaty(a_id, b_id) == dm.Treaty.TRADE_AGREEMENT


func _get_diplomacy_manager() -> Node:
	var root = _scene_cache
	if root:
		var sys = root.get_node_or_null("Systems")
		if sys:
			return sys.get_node_or_null("DiplomacyManager")
	return null
