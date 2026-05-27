class_name DiplomacyManager
extends Node

enum Relation { HOSTILE = 0, UNFRIENDLY = 25, NEUTRAL = 50, FRIENDLY = 75, ALLIED = 100 }
enum Treaty { NONE, TRADE_AGREEMENT, DEFENSIVE_PACT, MILITARY_ALLIANCE, VASSALAGE }

const DRIFT_INTERVAL: int = 30

var _treaties: Dictionary = {}  # "nationA_nationB" -> Treaty type
var _drift_counter: int = 0
var _independence_tick_counter: int = 0
var _league_tick_counter: int = 0
var _peace_tick_counter: int = 0
var _war_start_ticks: Dictionary = {}  # "a_b" -> tick when war started
var _aggressive_expansion: Dictionary = {}  # nation_id -> AE float (0-100)
var _coalition_tick_counter: int = 0

func _ready() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.war_declared.connect(_on_war_declared)
	EventBus.territory_captured.connect(_on_territory_captured)

func get_relation(nation_a: int, nation_b: int) -> float:
	if nation_a == nation_b:
		return 100.0
	if nation_a >= ColonyData.diplomacy_matrix.size():
		return 50.0
	if nation_b >= ColonyData.diplomacy_matrix[nation_a].size():
		return 50.0
	return ColonyData.diplomacy_matrix[nation_a][nation_b]

func change_relation(nation_a: int, nation_b: int, delta: float) -> void:
	if nation_a == nation_b:
		return
	if nation_a >= ColonyData.diplomacy_matrix.size():
		return
	if nation_b >= ColonyData.diplomacy_matrix[nation_a].size():
		return

	delta *= _government_diplomacy_mod(nation_a, nation_b)
	var new_val = clamp(
		ColonyData.diplomacy_matrix[nation_a][nation_b] + delta,
		0.0, 100.0
	)
	ColonyData.diplomacy_matrix[nation_a][nation_b] = new_val
	ColonyData.diplomacy_matrix[nation_b][nation_a] = new_val
	EventBus.relation_changed.emit(nation_a, nation_b, new_val)

func get_treaty(nation_a: int, nation_b: int) -> int:
	var key = _treaty_key(nation_a, nation_b)
	return _treaties.get(key, Treaty.NONE)

func set_treaty(nation_a: int, nation_b: int, treaty: int) -> void:
	_treaties[_treaty_key(nation_a, nation_b)] = treaty
	match treaty:
		Treaty.MILITARY_ALLIANCE:
			EventBus.alliance_formed.emit(nation_a, nation_b)
			change_relation(nation_a, nation_b, 25)

func propose_vassalage_overlord_accept(suzerain_id: int, vassal_id: int) -> void:
	set_treaty(suzerain_id, vassal_id, Treaty.VASSALAGE)
	change_relation(suzerain_id, vassal_id, 30)
	EventBus.vassalage_established.emit(suzerain_id, vassal_id)

func declare_independence(vassal_id: int) -> void:
	for other_id in range(ColonyData.nations.size()):
		if get_treaty(vassal_id, other_id) == Treaty.VASSALAGE:
			set_treaty(vassal_id, other_id, Treaty.NONE)
			change_relation(vassal_id, other_id, -40)
			return

func _on_war_declared(attacker_id: int, defender_id: int) -> void:
	set_treaty(attacker_id, defender_id, Treaty.NONE)
	change_relation(attacker_id, defender_id, -80)
	EventBus.relation_changed.emit(defender_id, attacker_id, get_relation(attacker_id, defender_id))
	var key = _treaty_key(attacker_id, defender_id)
	if not _war_start_ticks.has(key):
		_war_start_ticks[key] = ColonyData.current_tick
	# Aggressive expansion from war declaration
	_add_aggressive_expansion(attacker_id, 30.0)

func _on_territory_captured(capturer_id: int, _tile_x: int, _tile_y: int) -> void:
	_add_aggressive_expansion(capturer_id, 10.0)


func _add_aggressive_expansion(nation_id: int, amount: float) -> void:
	var current: float = _aggressive_expansion.get(nation_id, 0.0)
	_aggressive_expansion[nation_id] = clamp(current + amount, 0.0, 100.0)


func _on_tick_advanced(_tick: int, _day: int, _season: String, _year: int) -> void:
	# Aggressive expansion decay every tick
	for nation_id in _aggressive_expansion.keys():
		var new_ae = _aggressive_expansion[nation_id] - 2.0
		if new_ae <= 0.0:
			_aggressive_expansion.erase(nation_id)
		else:
			_aggressive_expansion[nation_id] = new_ae

	# Decimate O(n²) drift — only run every DRIFT_INTERVAL ticks
	_drift_counter += 1
	if _drift_counter % DRIFT_INTERVAL == 0:
		# Natural relation drift
		for i in range(ColonyData.nations.size()):
			for j in range(i + 1, ColonyData.nations.size()):
				var rel = get_relation(i, j)
				# Drift toward neutral (50)
				if rel > 50:
					change_relation(i, j, -1.5)
				elif rel < 50:
					change_relation(i, j, 1.5)

		# Government-based drift
		for i in range(ColonyData.nations.size()):
			for j in range(i + 1, ColonyData.nations.size()):
				var gmod = _government_diplomacy_mod(i, j)
				if gmod > 1.0:
					change_relation(i, j, 0.6)
				elif gmod < 1.0:
					change_relation(i, j, -0.6)

	# Trade league evaluation every 120 ticks
	_league_tick_counter += 1
	if _league_tick_counter >= 120:
		_league_tick_counter = 0
		_evaluate_trade_leagues()
		_manage_trade_leagues()

	# Independence movements every 150 ticks
	_independence_tick_counter += 1
	if _independence_tick_counter >= 150:
		_independence_tick_counter = 0
		_evaluate_independence_movements()

	# Peace evaluation every 30 ticks
	_peace_tick_counter += 1
	if _peace_tick_counter >= 30:
		_peace_tick_counter = 0
		_evaluate_peace()

	# Coalition evaluation every 30 ticks
	_coalition_tick_counter += 1
	if _coalition_tick_counter >= 30:
		_coalition_tick_counter = 0
		_evaluate_coalitions()

func _evaluate_trade_leagues() -> void:
	for i in range(ColonyData.nations.size()):
		for j in range(i + 1, ColonyData.nations.size()):
			for k in range(j + 1, ColonyData.nations.size()):
				var rel_ij = get_relation(i, j)
				var rel_ik = get_relation(i, k)
				var rel_jk = get_relation(j, k)
				if rel_ij > 70 and rel_ik > 70 and rel_jk > 70:
					var nat_i = ColonyData.get_nation_cached(i)
					var nat_j = ColonyData.get_nation_cached(j)
					var nat_k = ColonyData.get_nation_cached(k)
					var trade_affinity = 0.0
					for nat in [nat_i, nat_j, nat_k]:
						var race_id: String = nat["primary_race"]
						var race_data = ColonyData.RACES.get(race_id, {})
						trade_affinity += race_data.get("strategy_affinity", {}).get("trade", 0.5)
					if trade_affinity / 3.0 > 0.6:
						var league_name = "Trade League of %s" % nat_i["name"]
						_form_trade_league([i, j, k], league_name)

func _form_trade_league(members: Array[int], name: String) -> void:
	var existing_ids: Array = []
	for league in ColonyData.trade_leagues:
		existing_ids.append_array(league["members"])

	for member_id in members:
		if member_id in existing_ids:
			return  # Already in a league

	var league = {"name": name, "members": members, "founded_tick": ColonyData.current_tick}
	ColonyData.trade_leagues.append(league)
	EventBus.trade_league_formed.emit(league)
	print("[Trade] %s formed!" % name)

func _manage_trade_leagues() -> void:
	for league in ColonyData.trade_leagues:
		for i in range(league["members"].size()):
			for j in range(i + 1, league["members"].size()):
				var a = league["members"][i]
				var b = league["members"][j]
				change_relation(a, b, 1.0)  # League members grow closer over time
				var nat_a = ColonyData.get_nation_cached(a)
				var nat_b = ColonyData.get_nation_cached(b)
				if not nat_a.is_empty() and not nat_b.is_empty():
					nat_a["resources"]["gold"] += 1  # Trade league bonus income

func _government_diplomacy_mod(nation_a: int, nation_b: int) -> float:
	var nat_a = ColonyData.get_nation_cached(nation_a)
	var nat_b = ColonyData.get_nation_cached(nation_b)
	if nat_a.is_empty() or nat_b.is_empty():
		return 1.0
	var gov_a: String = nat_a.get("government", "kingdom")
	var gov_b: String = nat_b.get("government", "kingdom")
	if gov_a == gov_b:
		return 1.2
	var gov_data = ColonyData.GOVERNMENT_TYPES.get(gov_a, {})
	var bias: Dictionary = gov_data.get("diplomatic_bias", {})
	var mod = bias.get(gov_b, 0.0) / 100.0
	return 1.0 + mod

func get_relation_label(value: float) -> String:
	if value < 10:
		return "Hostile"
	elif value < 30:
		return "Unfriendly"
	elif value < 70:
		return "Neutral"
	elif value < 90:
		return "Friendly"
	else:
		return "Allied"

func _treaty_key(a: int, b: int) -> String:
	return "%d_%d" % [min(a, b), max(a, b)]

func _find_systems_node() -> Node:
	var root = get_tree().current_scene
	if root:
		return root.get_node_or_null("Systems")
	return null

func _evaluate_peace() -> void:
	var mm = _find_systems_node()
	if not mm:
		return
	var mil_mgr = mm.get_node_or_null("MilitaryManager")
	if not mil_mgr:
		return

	var resolved_wars: Array = []
	var current_tick: int = ColonyData.current_tick
	for war_key in mil_mgr._nations_at_war:
		var parts = war_key.split("_")
		var a: int = int(parts[0])
		var b: int = int(parts[1])
		var nat_a = ColonyData.get_nation_cached(a)
		var nat_b = ColonyData.get_nation_cached(b)
		if nat_a.is_empty() or nat_b.is_empty():
			continue

		var mil_a: float = float(nat_a["military_strength"])
		var mil_b: float = float(nat_b["military_strength"])

		var should_end = false

		# Condition 1: One side is devastated (military_strength < 3)
		if mil_a < 3 or mil_b < 3:
			should_end = true

		# Condition 2: War has gone on too long (~100 ticks)
		var war_start: int = _war_start_ticks.get(war_key, current_tick)
		if current_tick - war_start >= 100:
			should_end = true

		if should_end:
			resolved_wars.append(war_key)
			EventBus.peace_signed.emit(a, b)
			print("[Peace] War ended between %s and %s" % [nat_a["name"], nat_b["name"]])

	for key in resolved_wars:
		mil_mgr._nations_at_war.erase(key)
		_war_start_ticks.erase(key)


func _evaluate_independence_movements() -> void:
	for vassal_id in range(ColonyData.nations.size()):
		for suzerain_id in range(ColonyData.nations.size()):
			if vassal_id == suzerain_id:
				continue
			if get_treaty(vassal_id, suzerain_id) == Treaty.VASSALAGE:
				var vassal = ColonyData.get_nation_cached(vassal_id)
				var suzerain = ColonyData.get_nation_cached(suzerain_id)
				var desire = _calculate_independence_desire(vassal, suzerain)

				var movement: Dictionary
				var existing = -1
				for mi in range(ColonyData.independence_movements.size()):
					if ColonyData.independence_movements[mi].get("vassal_id") == vassal_id:
						existing = mi
						movement = ColonyData.independence_movements[mi]
						break

				if existing < 0:
					movement = {"vassal_id": vassal_id, "suzerain_id": suzerain_id, "desire": 0.0, "started_tick": ColonyData.current_tick}
					ColonyData.independence_movements.append(movement)

				movement["desire"] = lerp(movement["desire"], desire, 0.1)

				if movement["desire"] > 0.8:
					var vassal_mil: float = float(vassal["military_strength"])
					var suzerain_mil: float = float(suzerain["military_strength"])
					if vassal_mil > suzerain_mil * 0.5 or randf() < 0.3:
						declare_independence(vassal_id)
						for mi2 in range(ColonyData.independence_movements.size() - 1, -1, -1):
							if ColonyData.independence_movements[mi2]["vassal_id"] == vassal_id:
								ColonyData.independence_movements.remove_at(mi2)
						EventBus.independence_declared.emit(vassal_id)
						print("[Vassal] %s declared independence from %s!" % [vassal["name"], suzerain["name"]])


func get_aggressive_expansion(nation_id: int) -> float:
	return _aggressive_expansion.get(nation_id, 0.0)


func is_seen_as_threat(nation_id: int) -> bool:
	return _aggressive_expansion.get(nation_id, 0.0) > 60.0


func _evaluate_coalitions() -> void:
	var mm = _find_systems_node()
	if not mm:
		return
	var mil_mgr = mm.get_node_or_null("MilitaryManager")
	if not mil_mgr:
		return

	for offender_id in range(ColonyData.nations.size()):
		var ae = _aggressive_expansion.get(offender_id, 0.0)
		if ae <= 80.0:
			continue

		var offender = ColonyData.get_nation_cached(offender_id)
		if offender.is_empty():
			continue

		# Find neighboring nations not already allied / vassalized with offender
		var neighbors: Array[int] = []
		for other_id in range(ColonyData.nations.size()):
			if other_id == offender_id:
				continue
			if get_treaty(offender_id, other_id) in [Treaty.MILITARY_ALLIANCE, Treaty.VASSALAGE]:
				continue
			if _are_nations_adjacent(offender_id, other_id):
				neighbors.append(other_id)

		if neighbors.size() < 2:
			continue

		# Form coalition: neighboring nations ally with each other against the offender
		for i in range(neighbors.size()):
			for j in range(i + 1, neighbors.size()):
				var a = neighbors[i]
				var b = neighbors[j]
				if get_treaty(a, b) == Treaty.NONE:
					set_treaty(a, b, Treaty.MILITARY_ALLIANCE)
					print("[Coalition] %s and %s formed a defensive alliance against %s" % [
						ColonyData.get_nation_cached(a)["name"],
						ColonyData.get_nation_cached(b)["name"],
						offender["name"]
					])


func _are_nations_adjacent(nation_a: int, nation_b: int) -> bool:
	var tiles = ColonyData.world_tiles
	var width = ColonyData.world_width
	var height = ColonyData.world_height

	# Scan for any tile owned by nation_a that borders a tile owned by nation_b
	for y in range(height):
		for x in range(width):
			var idx = y * width + x
			if idx >= tiles.size():
				continue
			var tile = tiles[idx]
			if tile.get("owner", -1) != nation_a:
				continue
			# Check four cardinal neighbors
			var neighbors = [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]]
			for n in neighbors:
				var nx = n[0]
				var ny = n[1]
				if nx < 0 or nx >= width or ny < 0 or ny >= height:
					continue
				var nidx = ny * width + nx
				if nidx >= tiles.size():
					continue
				if tiles[nidx].get("owner", -1) == nation_b:
					return true
	return false


func _calculate_independence_desire(vassal: Dictionary, suzerain: Dictionary) -> float:
	var desire = 0.3  # Base desire
	var pop_ratio = float(vassal["population"]) / max(1.0, float(suzerain["population"]))
	desire += (1.0 - pop_ratio) * 0.3
	var mil_ratio = float(vassal["military_strength"]) / max(1.0, float(suzerain["military_strength"]))
	desire += (mil_ratio - 0.5) * 0.4
	var gov_a: String = vassal.get("government", "kingdom")
	var gov_b: String = suzerain.get("government", "kingdom")
	if gov_a != gov_b:
		desire += 0.1
	return clamp(desire, 0.0, 1.0)
