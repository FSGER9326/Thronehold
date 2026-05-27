class_name FactionManager
extends Node

var _evolution_counter = 0

func _ready() -> void:
	EventBus.world_generated.connect(_spawn_factions)
	EventBus.tick_advanced.connect(_on_tick_advanced)

func _spawn_factions(_w: int, _h: int) -> void:
	ColonyData.active_factions.clear()
	var count = randi_range(8, 12)
	var faction_types = ColonyData.FACTIONS.keys()
	for i in range(count):
		var type_id = faction_types[randi() % faction_types.size()]
		var faction_data = ColonyData.FACTIONS[type_id]
		# Place on unowned, non-water tiles
		var attempts = 0
		var tx = -1; var ty = -1
		while attempts < 100:
			attempts += 1
			tx = randi() % ColonyData.world_width
			ty = randi() % ColonyData.world_height
			var tile = ColonyData.get_tile(tx, ty)
			if tile["terrain"] != "water" and tile["owner"] == -1:
				break
		if tx < 0: continue

		var faction = {
			"id": ColonyData.active_factions.size(),
			"type": type_id,
			"tile_x": tx, "tile_y": ty,
			"strength": faction_data["threat_level"] * randi_range(5, 15),
		}
		ColonyData.active_factions.append(faction)

func _on_tick_advanced(_tick: int, _day: int, _season: String, _year: int) -> void:
	_evolution_counter += 1
	if _evolution_counter >= 200:
		_evolution_counter = 0
		_evolve_factions()

func _evolve_factions() -> void:
	var factions = ColonyData.active_factions.duplicate()
	var max_factions = 15

	for faction in factions:
		var idx = ColonyData.active_factions.find(faction)
		if idx < 0:
			continue

		# (1) Grow — strength +1..3, capped at 50
		faction["strength"] = min(faction["strength"] + randi_range(1, 3), 50)

		# (2) Move — 30% chance to adjacent unowned tile
		if randf() < 0.30:
			var adjacent = _get_adjacent_unowned_tiles(faction["tile_x"], faction["tile_y"])
			if not adjacent.is_empty():
				var new_tile = adjacent[randi() % adjacent.size()]
				faction["tile_x"] = new_tile[0]
				faction["tile_y"] = new_tile[1]

		# (3) Multiply — if strength > 20, split at half strength
		if faction["strength"] > 20 and ColonyData.active_factions.size() < max_factions:
			var adjacent = _get_adjacent_unowned_tiles(faction["tile_x"], faction["tile_y"])
			if not adjacent.is_empty():
				var new_tile = adjacent[randi() % adjacent.size()]
				var half_strength = int(floor(float(faction["strength"]) / 2.0))
				faction["strength"] -= half_strength
				var new_faction = faction.duplicate()
				new_faction["id"] = ColonyData.active_factions.size()
				new_faction["tile_x"] = new_tile[0]
				new_faction["tile_y"] = new_tile[1]
				new_faction["strength"] = half_strength
				ColonyData.active_factions.append(new_faction)

	# (4) New spawns — 10% chance to spawn wild_tribe
	if randf() < 0.10 and ColonyData.active_factions.size() < max_factions:
		var attempts = 0
		var tx = -1
		var ty = -1
		while attempts < 50:
			attempts += 1
			tx = randi() % ColonyData.world_width
			ty = randi() % ColonyData.world_height
			var tile = ColonyData.get_tile(tx, ty)
			if tile["terrain"] != "water" and tile["owner"] == -1:
				# Check no faction already occupies this tile
				var occupied = false
				for f in ColonyData.active_factions:
					if f["tile_x"] == tx and f["tile_y"] == ty:
						occupied = true
						break
				if not occupied:
					break
				tx = -1

		if tx >= 0:
			var faction = {
				"id": ColonyData.active_factions.size(),
				"type": "wild_tribe",
				"tile_x": tx,
				"tile_y": ty,
				"strength": randi_range(3, 8),
			}
			ColonyData.active_factions.append(faction)
			print("[Faction] New wild_tribe spawned at (%d, %d)" % [tx, ty])

func _get_adjacent_unowned_tiles(x: int, y: int) -> Array:
	var dirs = [[0, -1], [0, 1], [-1, 0], [1, 0]]
	var result: Array = []
	for d in dirs:
		var nx = x + d[0]
		var ny = y + d[1]
		if nx < 0 or nx >= ColonyData.world_width or ny < 0 or ny >= ColonyData.world_height:
			continue
		var tile = ColonyData.get_tile(nx, ny)
		if tile["terrain"] != "water" and tile["owner"] == -1:
			var occupied = false
			for f in ColonyData.active_factions:
				if f["tile_x"] == nx and f["tile_y"] == ny:
					occupied = true
					break
			if not occupied:
				result.append([nx, ny])
	return result

func interact_with_faction(nation_id: int, faction_id: int, interaction: String) -> Dictionary:
	if faction_id < 0 or faction_id >= ColonyData.active_factions.size():
		return {"success": false, "reason": "Invalid faction"}
	var faction = ColonyData.active_factions[faction_id]
	var faction_data = ColonyData.FACTIONS[faction["type"]]
	var nation = ColonyData.get_nation(nation_id)
	if nation.is_empty():
		return {"success": false, "reason": "Invalid nation"}

	if interaction not in faction_data["interactions"]:
		return {"success": false, "reason": "Cannot %s this faction" % interaction}

	match interaction:
		"fight":
			var nat_power = float(nation["military_strength"])
			var fac_power = float(faction["strength"])
			if nat_power > fac_power * 0.5:
				# Victory — gain drops
				for res in faction_data["drops"]:
					nation["resources"][res] += faction_data["drops"][res]
				ColonyData.active_factions.remove_at(faction_id)
				EventBus.faction_defeated.emit(nation_id, faction["type"])
				return {"success": true, "outcome": "victory", "drops": faction_data["drops"]}
			return {"success": false, "reason": "Faction too strong"}

		"integrate":
			nation["population"] += 5
			ColonyData.active_factions.remove_at(faction_id)
			EventBus.faction_integrated.emit(nation_id, faction["type"])
			return {"success": true, "outcome": "integrated"}

		"bribe":
			var cost = faction_data["threat_level"] * 3
			if nation["resources"]["gold"] >= cost:
				nation["resources"]["gold"] -= cost
				ColonyData.active_factions.remove_at(faction_id)
				EventBus.faction_defeated.emit(nation_id, faction["type"])
				return {"success": true, "outcome": "bribed", "cost": cost}
			return {"success": false, "reason": "Not enough gold"}

		"enslave":
			if faction["type"] != "wild_tribe":
				return {"success": false, "reason": "Can only enslave wild tribes"}
			var nat_mil: float = float(nation["military_strength"])
			var fac_str: float = float(faction["strength"])
			if nat_mil < fac_str * 2:
				return {"success": false, "reason": "Military too weak to enslave (need 2x faction strength)"}
			# Determine enslaved race based on nation's primary race context
			var enslaved_race = "troll"
			if faction["tile_y"] < ColonyData.world_height / 2:
				enslaved_race = "ogre"
			# Add enslaved race to nation demographics
			var demos: Dictionary = nation.get("race_demographics", {})
			demos[enslaved_race] = demos.get(enslaved_race, 0.0) + 0.15
			# Normalize demographics
			var total = 0.0
			for v in demos.values():
				total += v
			for k in demos:
				demos[k] /= total
			nation["race_demographics"] = demos
			# Remove faction
			var fidx = ColonyData.active_factions.find(faction)
			if fidx >= 0:
				ColonyData.active_factions.remove_at(fidx)
			EventBus.faction_defeated.emit(nation_id, faction["type"])
			print("[Faction] %s enslaved wild_tribe (%s) — %s pop added" % [nation["name"], enslaved_race, enslaved_race])
			return {"success": true, "outcome": "enslaved", "enslaved_race": enslaved_race}

	return {"success": false, "reason": "Unknown interaction"}

func get_factions_on_tile(tile_x: int, tile_y: int) -> Array:
	var result: Array = []
	for f in ColonyData.active_factions:
		if f["tile_x"] == tile_x and f["tile_y"] == tile_y:
			result.append(f)
	return result
