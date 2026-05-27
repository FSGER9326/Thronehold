class_name ColonyManager
extends Node

const COLONY_THRESHOLDS: Dictionary = {
	"human": 80, "dwarf": 50, "elf": 60, "orc": 100, "halfling": 70, "goblin": 120,
	"troll": 90, "ogre": 60, "gnome": 80,
}

var _colony_tick_counter: int = 0
const COLONY_CHECK_INTERVAL: int = 240
var _scene_cache: Node

func _ready() -> void:
	_scene_cache = get_tree().current_scene
	EventBus.tick_advanced.connect(_on_tick_advanced)

func _on_tick_advanced(_tick: int, _day: int, _season: String, _year: int) -> void:
	_colony_tick_counter += 1
	if _colony_tick_counter >= COLONY_CHECK_INTERVAL:
		_colony_tick_counter = 0
		for nation in ColonyData.nations:
			_ai_colony_check(nation)

func _ai_colony_check(nation: Dictionary) -> void:
	var race_key = nation["primary_race"]
	var threshold = COLONY_THRESHOLDS.get(race_key, 100)
	if ColonyData.RACE_VARIANTS.has(race_key):
		threshold = COLONY_THRESHOLDS.get(ColonyData.RACE_VARIANTS[race_key]["parent_race"], 100)
	if nation["population"] < threshold:
		return
	var existing_colonies = _count_colonies(nation["id"])
	if existing_colonies >= 3:
		return

	var best_tx = -1; var best_ty = -1; var best_score = 0.0
	for y in range(max(0, nation["capital_y"]-5), min(ColonyData.world_height, nation["capital_y"]+6)):
		for x in range(max(0, nation["capital_x"]-5), min(ColonyData.world_width, nation["capital_x"]+6)):
			var tile = ColonyData.get_tile(x, y)
			if tile["owner"] != nation["id"]:
				continue
			if tile["terrain"] == "water":
				continue
			if tile.get("buildings", []).size() > 0:
				continue
			var d = abs(x - nation["capital_x"]) + abs(y - nation["capital_y"])
			if d < 3:
				continue
			var score = float(d) * 2.0
			var race_data = ColonyData.RACES.get(race_key, {})
			var tb: Dictionary = race_data.get("terrain_bonuses", {})
			if tb.get(tile["terrain"], 1.0) > 1.1:
				score *= 2.0
			if score > best_score:
				best_score = score
				best_tx = x; best_ty = y

	if best_tx >= 0:
		found_colony(nation, best_tx, best_ty)

func found_colony(nation: Dictionary, tile_x: int, tile_y: int) -> void:
	var split_pop = int(nation["population"] * 0.3)
	nation["population"] -= split_pop

	var tile = ColonyData.get_tile(tile_x, tile_y)
	tile["owner"] = nation["id"]
	tile["buildings"] = []
	ColonyData.set_tile(tile_x, tile_y, tile)

	var bm = _get_building_manager()
	if bm:
		bm.place_building(tile_x, tile_y, "farm", nation["id"])
		if randi() % 2 == 0:
			bm.place_building(tile_x, tile_y, "granary", nation["id"])
		else:
			bm.place_building(tile_x, tile_y, "workshop", nation["id"])

	if not nation.has("colonies"):
		nation["colonies"] = []
	nation["colonies"].append({"tile_x": tile_x, "tile_y": tile_y, "founded_tick": ColonyData.current_tick})
	EventBus.colony_founded.emit(nation["id"], tile_x, tile_y)
	print("[Colony] %s founded colony at (%d,%d)" % [nation["name"], tile_x, tile_y])

func _count_colonies(nation_id: int) -> int:
	var nation = ColonyData.get_nation(nation_id)
	return (nation.get("colonies", []) as Array).size()

func _get_building_manager() -> Node:
	var root = _scene_cache
	if root:
		var sys = root.get_node_or_null("Systems")
		if sys: return sys.get_node_or_null("BuildingManager")
	return null
