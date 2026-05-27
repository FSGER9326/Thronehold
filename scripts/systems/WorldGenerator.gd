class_name WorldGenerator
extends Node

signal generation_complete

var _rng: RandomNumberGenerator

func generate_world(width: int, height: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = randi()

	ColonyData.world_tiles.clear()
	ColonyData.world_tiles.resize(width * height)
	ColonyData.underground_tiles.clear()
	ColonyData.underground_tiles.resize(width * height)
	ColonyData.visibility_grid.clear()
	ColonyData.visibility_grid.resize(width * height)
	for i in range(width * height):
		ColonyData.visibility_grid[i] = 0

	_generate_terrain(width, height)
	_generate_resources(width, height)
	_generate_underground_terrain(width, height)
	_generate_underground_resources(width, height)
	_place_nations(width, height)

	EventBus.world_generated.emit(width, height)
	generation_complete.emit()

func _generate_terrain(width: int, height: int) -> void:
	# Simple noise-based terrain generation
	var noise_values = _generate_noise(width, height)

	for y in range(height):
		for x in range(width):
			var noise: float = noise_values[y * width + x]
			var terrain: String
			if noise < 0.3:
				terrain = "water"
			elif noise < 0.35:
				terrain = "coast"
			elif noise < 0.45:
				terrain = "swamp"
			elif noise < 0.50:
				terrain = "desert"
			elif noise < 0.60:
				terrain = "plains"
			elif noise < 0.75:
				terrain = "forest"
			elif noise < 0.85:
				terrain = "hills"
			elif noise < 0.93:
				terrain = "caves"
			else:
				terrain = "mountain"

			ColonyData.set_tile(x, y, {"terrain": terrain, "resource": "", "owner": -1, "buildings": []})

func _generate_noise(width: int, height: int) -> Array[float]:
	# Simple value noise with octaves
	var values: Array[float] = []
	values.resize(width * height)

	var octaves = 4
	var persistence = 0.5
	var scale = 0.012  # 400×300 grand strategy map

	for y in range(height):
		for x in range(width):
			var value = 0.0
			var amplitude = 1.0
			var frequency = 1.0
			var max_val = 0.0

			for _o in range(octaves):
				var sx = float(x) * scale * frequency
				var sy = float(y) * scale * frequency
				value += _noise_2d(sx, sy) * amplitude
				max_val += amplitude
				amplitude *= persistence
				frequency *= 2.0

			values[y * width + x] = value / max_val

	return values

func _noise_2d(x: float, y: float) -> float:
	var ix = int(floor(x))
	var iy = int(floor(y))
	var fx: float = x - floor(x)
	var fy: float = y - floor(y)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)

	var n00: float
	if _rng:
		n00 = _rng.randf_range(-1.0, 1.0)
	else:
		n00 = 0.0
	# Use deterministic pseudo-random based on grid coords
	n00 = _hash(ix, iy)
	var n10: float = _hash(ix + 1, iy)
	var n01: float = _hash(ix, iy + 1)
	var n11: float = _hash(ix + 1, iy + 1)

	var nx0: float = lerp(n00, n10, fx)
	var nx1: float = lerp(n01, n11, fx)
	return lerp(nx0, nx1, fy)

func _hash(x: int, y: int) -> float:
	var h: int = x * 374761393 + y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0x7fffffff) / float(0x7fffffff) * 2.0 - 1.0

func _generate_resources(_width: int, _height: int) -> void:
	for y in range(_height):
		for x in range(_width):
			var tile = ColonyData.get_tile(x, y)
			var terrain: String = tile["terrain"]
			if terrain == "water":
				continue
			var pool: Array = ColonyData.TILE_RESOURCES.get(terrain, [])
			if pool.is_empty():
				continue
			if randi() % 100 < 40:  # 40% chance to have a resource
				tile["resource"] = pool[randi() % pool.size()]
				ColonyData.set_tile(x, y, tile)

func _generate_underground_terrain(width: int, height: int) -> void:
	# Underworld noise — predominantly cave terrain with interstitial features
	var noise_values = _generate_noise(width, height)
	var detail_noise = _generate_noise(width, height)  # Second noise layer for variety

	for y in range(height):
		for x in range(width):
			var noise: float = noise_values[y * width + x]
			var detail: float = detail_noise[y * width + x]
			var terrain: String

			if noise < 0.15:
				terrain = "underground_river"
			elif noise < 0.25 and detail > 0.5:
				terrain = "magma_vein"
			elif noise < 0.35:
				terrain = "fungal_grove"
			elif noise < 0.42:
				terrain = "crystal_cave"
			elif noise < 0.50:
				terrain = "buried_ruins"
			elif noise < 0.70:
				terrain = "deep_cavern"
			else:
				terrain = "caves"

			ColonyData.set_underground_tile(x, y, {"terrain": terrain, "resource": "", "owner": -1, "buildings": []})

func _generate_underground_resources(_width: int, _height: int) -> void:
	for y in range(_height):
		for x in range(_width):
			var tile = ColonyData.get_underground_tile(x, y)
			var terrain: String = tile["terrain"]
			var pool: Array = ColonyData.UNDERGROUND_TILE_RESOURCES.get(terrain, [])
			if pool.is_empty():
				continue
			if randi() % 100 < 45:  # 45% chance — underworld is richer
				tile["resource"] = pool[randi() % pool.size()]
				ColonyData.set_underground_tile(x, y, tile)

func _place_nations(width: int, height: int) -> void:
	ColonyData.nations.clear()

	var nation_defs = [
		{"name": "Ironhold", "race": "dwarf", "color": "#c49a3c"},
		{"name": "Ironpeak", "race": "dwarf", "color": "#b8892e"},
		{"name": "DeepIron", "race": "dwarf", "color": "#998866"},
		{"name": "Stonepeak", "race": "dwarf", "color": "#a0b070"},
		{"name": "Silverwood", "race": "elf", "color": "#7ec8a0"},
		{"name": "Darkwood", "race": "elf", "color": "#4a8c6e"},
		{"name": "Ancientwood", "race": "elf", "color": "#2d6b4f"},
		{"name": "Glenwood", "race": "elf", "color": "#5a9a6a"},
		{"name": "Northmark", "race": "human", "color": "#5577cc"},
		{"name": "Southmark", "race": "human", "color": "#4466aa"},
		{"name": "Westmark", "race": "human", "color": "#6688dd"},
		{"name": "Eastmark", "race": "human", "color": "#335599"},
		{"name": "Bloodfang", "race": "orc", "color": "#cc4444"},
		{"name": "Brokenfang", "race": "orc", "color": "#993333"},
		{"name": "Greenfields", "race": "halfling", "color": "#88cc44"},
		{"name": "Goldfields", "race": "halfling", "color": "#ccaa33"},
		{"name": "Deepgrot", "race": "goblin", "color": "#996644"},
		{"name": "Highgrot", "race": "goblin", "color": "#885533"},
		{"name": "Sparkgear", "race": "gnome", "color": "#cc88cc"},
		{"name": "Coggerton", "race": "gnome", "color": "#bb77bb"},
		{"name": "Bogmire", "race": "troll", "color": "#66aa44"},
		{"name": "Fenmire", "race": "troll", "color": "#559933"},
		{"name": "Highpeak", "race": "ogre", "color": "#886644"},
		{"name": "Stormpeak", "race": "ogre", "color": "#775533"},
	]

	var placed = 0
	for nd in nation_defs:
		var cx: int = -1
		var cy: int = -1
		var race_prefs: Array = ColonyData.RACES[nd["race"]]["preferred_biomes"]

		var attempts = 0
		while attempts < 200:
			attempts += 1
			var tx = randi() % width
			var ty = randi() % height
			var tile = ColonyData.get_tile(tx, ty)

			if tile["terrain"] == "water" or tile["owner"] != -1:
				continue
			if tile["terrain"] in race_prefs:
				cx = tx
				cy = ty
				break

		if cx < 0:
			continue

		var nation = ColonyData.create_nation(nd["name"], nd["race"], nd["color"], cx, cy)
		ColonyData.nations.append(nation)

		# Claim territory around capital
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var tx = cx + dx
				var ty = cy + dy
				if tx < 0 or tx >= width or ty < 0 or ty >= height:
					continue
				var t = ColonyData.get_tile(tx, ty)
				if t["terrain"] != "water" and t["owner"] == -1:
					if randf() < 0.7:
						ColonyData.set_tile(tx, ty, {"terrain": t["terrain"], "resource": t["resource"], "owner": nation["id"], "buildings": []})

		EventBus.nation_created.emit(nation["id"], nation)
		placed += 1

	# Player gets the first nation
	if placed > 0:
		ColonyData.player_nation_id = 0

	# Build diplomacy matrix
	ColonyData.diplomacy_matrix.clear()
	for _i in range(placed):
		var row: Array[float] = []
		row.resize(placed)
		row.fill(50.0)
		ColonyData.diplomacy_matrix.append(row)

	# Generate leaders for all nations
	_generate_leaders()

	# Assign governments based on capital terrain
	_assign_governments()

	# Initialize belief data
	_init_belief()

	# Generate world history
	var history_gen = get_parent().get_node_or_null("HistoryGenerator")
	if history_gen:
		history_gen.generate_history()

	# Apply historical events to starting diplomacy
	_apply_history_to_diplomacy()

func _generate_leaders() -> void:
	var cm = get_parent().get_node_or_null("CharacterManager")
	if not cm:
		return
	for nation in ColonyData.nations:
		var leader: Dictionary = cm.generate_leader(nation["id"], nation["primary_race"])
		nation["leader_id"] = leader["id"]

func _assign_governments() -> void:
	for nation in ColonyData.nations:
		var tile = ColonyData.get_tile(nation["capital_x"], nation["capital_y"])
		var terrain: String = tile["terrain"]
		var race: String = nation["primary_race"]
		var gov: String

		# Terrain-to-government mapping
		match terrain:
			"coast":
				gov = "merchant_republic"
			"mountain":
				gov = "mountain_hold"
			"caves":
				gov = "clan"
			"forest":
				gov = "druidic_council"
			"swamp":
				gov = "tyrant_state"
			"desert":
				gov = "warrior_society"
			"plains":
				gov = "kingdom" if _rng.randf() < 0.5 else "horde"
			"hills":
				var roll = _rng.randf()
				if roll < 0.5:
					gov = "kingdom"
				elif roll < 0.8:
					gov = "clan"
				else:
					gov = "republic"
			_:
				gov = "kingdom"

		# Race overrides (applied after terrain mapping)
		match race:
			"dwarf":
				if gov != "mountain_hold":
					gov = "mountain_hold"
			"orc":
				if terrain in ["plains", "hills"]:
					gov = "horde"
				elif gov != "horde" and gov != "clan":
					# If not already horde/clan, bias toward horde
					if _rng.randf() < 0.6:
						gov = "horde"
			"goblin":
				if gov != "tyrant_state" and _rng.randf() < 0.5:
					gov = "tyrant_state"
			"halfling":
				if terrain == "hills" and gov != "republic":
					gov = "republic"

		nation["government"] = gov

func _init_belief() -> void:
	for nation in ColonyData.nations:
		ColonyData.belief_by_nation[nation["id"]] = {}
		for race_id in nation.get("race_demographics", {}):
			# Player's chosen nation starts with some belief
			if nation["id"] == ColonyData.player_nation_id:
				ColonyData.belief_by_nation[nation["id"]][race_id] = 0.3
			else:
				ColonyData.belief_by_nation[nation["id"]][race_id] = 0.0

func _apply_history_to_diplomacy() -> void:
	# Build race → nation_id lookup
	var race_to_nation: Dictionary = {}
	for nation in ColonyData.nations:
		race_to_nation[nation["primary_race"]] = nation["id"]

	# --- Past wars: -30 between aggressor and defender nations ---
	for war in ColonyData.world_history.get("past_wars", []):
		var aggr_race: String = war.get("aggressor_race", "")
		var def_race: String = war.get("defender_race", "")
		var a_id = race_to_nation.get(aggr_race, -1)
		var d_id = race_to_nation.get(def_race, -1)
		if a_id >= 0 and d_id >= 0 and a_id != d_id:
			_adjust_relation(a_id, d_id, -30.0)

	# --- Trade leagues: boost between founding race nations ---
	var founder_nations: Array[int] = []
	for league in ColonyData.world_history.get("trade_leagues", []):
		var founder_race: String = league.get("founder_race", "")
		var n_id = race_to_nation.get(founder_race, -1)
		if n_id >= 0 and not n_id in founder_nations:
			founder_nations.append(n_id)
	for i in range(founder_nations.size()):
		for j in range(i + 1, founder_nations.size()):
			_adjust_relation(founder_nations[i], founder_nations[j], 15.0)

	# --- Migrations: slight boost between nations of migrating races ---
	var migration_nations: Array[int] = []
	for migration in ColonyData.world_history.get("migrations", []):
		var race: String = migration.get("race", "")
		var n_id = race_to_nation.get(race, -1)
		if n_id >= 0 and not n_id in migration_nations:
			migration_nations.append(n_id)
	for i in range(migration_nations.size()):
		for j in range(i + 1, migration_nations.size()):
			_adjust_relation(migration_nations[i], migration_nations[j], 5.0)

func _adjust_relation(a: int, b: int, delta: float) -> void:
	var new_val: float = clamp(
		ColonyData.diplomacy_matrix[a][b] + delta,
		0.0, 100.0
	)
	ColonyData.diplomacy_matrix[a][b] = new_val
	ColonyData.diplomacy_matrix[b][a] = new_val
	EventBus.relation_changed.emit(a, b, new_val)
