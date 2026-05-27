class_name BuildingManager
extends Node

var _ai_build_tick_counter: int = 0
const AI_BUILD_INTERVAL: int = 120
var _scene_cache: Node
var _building_counts: Dictionary = {}
var _territory_counts: Dictionary = {}

func _ready() -> void:
	_scene_cache = get_tree().current_scene
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.world_generated.connect(_rebuild_all_caches)
	EventBus.building_placed.connect(_rebuild_all_caches)
	EventBus.building_destroyed.connect(_rebuild_all_caches)
	EventBus.territory_captured.connect(_rebuild_all_caches)

func _on_tick_advanced(_tick: int, _day: int, _season: String, _year: int) -> void:
	_ai_build_tick_counter += 1
	if _ai_build_tick_counter >= AI_BUILD_INTERVAL:
		_ai_build_tick_counter = 0
		for nation in ColonyData.nations:
			if nation["id"] == ColonyData.player_nation_id:
				continue
			_ai_place_buildings(nation)

func place_building(tile_x: int, tile_y: int, building_id: String, nation_id: int) -> bool:
	var tile = ColonyData.get_tile(tile_x, tile_y)
	if tile["owner"] != nation_id:
		return false

	var building_data = ColonyData.BUILDINGS.get(building_id, {})
	if building_data.is_empty():
		return false

	var nation = ColonyData.get_nation(nation_id)
	if nation.is_empty():
		return false

	# Check if this is an upgrade to an existing building
	if building_data.has("upgrades_from"):
		var old_id: String = building_data["upgrades_from"]
		var tile_buildings: Array = tile.get("buildings", [])
		if tile_buildings.has(old_id):
			# Calculate cost difference
			var old_cost: Dictionary = ColonyData.BUILDINGS.get(old_id, {}).get("cost", {})
			var upgrade_cost: Dictionary = {}
			for r in building_data.get("cost", {}):
				var old_r: float = old_cost.get(r, 0.0)
				upgrade_cost[r] = max(0.0, building_data["cost"][r] - old_r)
			# Charge upgrade cost instead of full cost
			for r in upgrade_cost:
				if nation["resources"].get(r, 0.0) < upgrade_cost[r]:
					return false
				nation["resources"][r] -= upgrade_cost[r]
			tile_buildings.erase(old_id)
			tile_buildings.append(building_id)
			tile["buildings"] = tile_buildings
			ColonyData.set_tile(tile_x, tile_y, tile)
			EventBus.building_placed.emit(tile_x, tile_y, building_id, nation_id)
			return true

	# Check terrain
	if tile["terrain"] not in building_data.get("placement_terrain", []):
		return false

	# Check cost
	var cost: Dictionary = building_data.get("cost", {})
	for r in cost:
		if nation["resources"].get(r, 0.0) < cost[r]:
			return false

	# Deduct cost
	for r in cost:
		nation["resources"][r] -= cost[r]

	# Place building
	if not tile.has("buildings"):
		tile["buildings"] = []
	tile["buildings"].append(building_id)
	ColonyData.set_tile(tile_x, tile_y, tile)
	EventBus.building_placed.emit(tile_x, tile_y, building_id, nation_id)
	return true

func remove_building(tile_x: int, tile_y: int, building_id: String) -> bool:
	var tile = ColonyData.get_tile(tile_x, tile_y)
	var buildings: Array = tile.get("buildings", [])
	if building_id not in buildings:
		return false
	buildings.erase(building_id)
	tile["buildings"] = buildings
	ColonyData.set_tile(tile_x, tile_y, tile)
	EventBus.building_destroyed.emit(tile_x, tile_y, building_id)
	return true

func get_tile_buildings(tile_x: int, tile_y: int) -> Array:
	return ColonyData.get_tile(tile_x, tile_y).get("buildings", [])

func _rebuild_all_caches(_a = null, _b = null, _c = null, _d = null) -> void:
	_building_counts.clear()
	_territory_counts.clear()
	for y in range(ColonyData.world_height):
		for x in range(ColonyData.world_width):
			var tile = ColonyData.get_tile(x, y)
			var owner: int = tile.get("owner", -1)
			if owner < 0:
				continue
			# Territory counts
			if not _territory_counts.has(owner):
				_territory_counts[owner] = {}
			var terrain: String = tile.get("terrain", "")
			if terrain != "":
				_territory_counts[owner][terrain] = _territory_counts[owner].get(terrain, 0) + 1
			# Building counts
			if not _building_counts.has(owner):
				_building_counts[owner] = {}
			for b in tile.get("buildings", []):
				_building_counts[owner][b] = _building_counts[owner].get(b, 0) + 1

func get_nation_building_counts(nation_id: int) -> Dictionary:
	return _building_counts.get(nation_id, {})

func get_territory_counts(nation_id: int) -> Dictionary:
	return _territory_counts.get(nation_id, {})

func _ai_place_buildings(nation: Dictionary) -> void:
	var race_key = nation["primary_race"]
	
	# Score each building type
	var best_score = 0.0
	var best_building = ""
	var best_tx = -1; var best_ty = -1
	var deficits: Dictionary = nation.get("resource_deficits", {})
	
	for building_id in ColonyData.BUILDINGS:
		var bdata = ColonyData.BUILDINGS[building_id]
		if bdata.get("tier", 1) > 1:
			var sys = _find_systems_node()
			var allowed = false
			if sys:
				var tm = sys.get_node_or_null("TechManager")
				if tm and tm.has_method("can_unlock_tech"):
					if bdata.get("tier", 1) == 2 and (tm.can_unlock_tech(nation["id"], "masonry") or "masonry" in tm.unlocked_techs.get(nation["id"], [])):
						allowed = true
			if not allowed:
				continue
		var score = _score_building_for_nation(nation, building_id, bdata, deficits)
		if score <= 0:
			continue
		
		# Find best tile for this building
		for y in range(ColonyData.world_height):
			for x in range(ColonyData.world_width):
				var tile = ColonyData.get_tile(x, y)
				if tile["owner"] != nation["id"]:
					continue
				if tile["terrain"] not in bdata.get("placement_terrain", []):
					continue
				if tile.get("buildings", []).size() >= 2:
					continue  # Max 2 buildings per tile
				var tile_score = score
				# Bonus for race-terrain synergy
				var race_data = ColonyData.RACES.get(race_key, {})
				var tb: Dictionary = race_data.get("terrain_bonuses", {})
				if tb.get(tile["terrain"], 1.0) > 1.0:
					tile_score *= 1.5
				if tile_score > best_score:
					best_score = tile_score
					best_building = building_id
					best_tx = x; best_ty = y
	
	if best_building != "" and best_score > 5.0:
		place_building(best_tx, best_ty, best_building, nation["id"])

func _score_building_for_nation(nation: Dictionary, building_id: String, bdata: Dictionary, deficits: Dictionary) -> float:
	var score = 5.0  # base
	var effects: Dictionary = bdata.get("effects", {})
	var cost: Dictionary = bdata.get("cost", {})
	var res = nation["resources"]
	
	# Check affordability
	for r in cost:
		if res.get(r, 0.0) < cost[r] * 1.5:  # Need 1.5x buffer
			return 0.0
	
	# Score based on deficits: if building produces what we need
	if effects.has("food") and deficits.get("food", {}).get("deficit", 0.0) > 0:
		score += 20.0
	if effects.has("wood") and deficits.get("wood", {}).get("deficit", 0.0) > 0:
		score += 15.0
	if effects.has("stone") and deficits.get("stone", {}).get("deficit", 0.0) > 0:
		score += 15.0
	if effects.has("metal") and deficits.get("metal", {}).get("deficit", 0.0) > 0:
		score += 18.0
	
	# Race-specific bonuses
	var race_key = nation["primary_race"]
	match building_id:
		"mine", "quarry":
			if race_key in ["dwarf", "orc"]: score *= 1.5
		"farm", "granary":
			if race_key in ["halfling", "human"]: score *= 1.5
		"lumber_camp":
			if race_key in ["elf"]: score *= 1.5
		"barracks", "fort":
			if race_key in ["orc", "goblin"]: score *= 1.5
		"harbor":
			if race_key in ["human"]: score *= 1.5
		"market":
			if race_key in ["halfling", "human"]: score *= 1.5
	
	# Cost penalty
	var total_cost = 0.0
	for r in cost:
		total_cost += cost[r] / max(1.0, res[r])
	score /= max(0.1, total_cost)
	
	return score

func _find_systems_node() -> Node:
	var root = _scene_cache
	if root:
		return root.get_node_or_null("Systems")
	return null
