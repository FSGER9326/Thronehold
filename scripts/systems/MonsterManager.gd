class_name MonsterManager
extends Node

var _attack_cooldown: int = 0
var _tick_counter: int = 0

const MONSTER_PREFIXES: Array[String] = [
	"Grimfang", "Ashwing", "Thunderclaw", "Shadowmaw", "Ironhide",
	"Bloodscale", "Stormrage", "Doomhorn", "Nightflare", "Frostbite",
	"Venomspine", "Dreadmaw", "Bonecrush", "Voidtalon", "Magmawrath"
]

const SPECIES: Array[String] = ["dragon", "hydra", "giant", "behemoth"]

const SPECIES_TITLES: Dictionary = {
	"dragon": ["the World-Eater", "the Flame Tyrant", "the Sky Scourge", "the Dread Wyrm", "the Ember King"],
	"hydra": ["the Many-Headed", "the Venom Lord", "the Regenerator", "the Serpent Queen", "the Poison Tide"],
	"giant": ["the Mountain Breaker", "the Earth Shaker", "the Colossus", "the Sky Render", "the Titan"],
	"behemoth": ["the Beast of Ruin", "the Walking Cataclysm", "the Unstoppable", "the Land Scourge", "the Rampager"],
}

const ATTACK_TICK_INTERVAL: int = 150


func _ready() -> void:
	EventBus.world_generated.connect(_spawn_monsters)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.monster_defeated.connect(_monster_defeated)


func _spawn_monsters(_w: int, _h: int) -> void:
	ColonyData.world_monsters.clear()
	var count = randi_range(16, 24)
	var used_names: Array[String] = []

	for i in range(count):
		var species = SPECIES[randi() % SPECIES.size()]
		var monster_name = _generate_name(species, used_names)
		used_names.append(monster_name)

		# Place on unowned, non-water tile
		var attempts = 0
		var tx = -1
		var ty = -1
		while attempts < 200:
			attempts += 1
			tx = randi() % ColonyData.world_width
			ty = randi() % ColonyData.world_height
			var tile = ColonyData.get_tile(tx, ty)
			if tile["terrain"] != "water" and tile["owner"] == -1:
				# Check no other monster occupies this tile
				var occupied = false
				for m in ColonyData.world_monsters:
					if m["lair_x"] == tx and m["lair_y"] == ty:
						occupied = true
						break
				if not occupied:
					break
			tx = -1

		if tx < 0:
			continue

		var monster: Dictionary = {
			"id": ColonyData.world_monsters.size(),
			"name": monster_name,
			"species": species,
			"lair_x": tx,
			"lair_y": ty,
			"threat_rating": randi_range(1, 10),
			"alive": true,
		}
		ColonyData.world_monsters.append(monster)
		EventBus.monster_spawned.emit(monster)
		print("[Monster] %s (%s, threat %d) lairs at (%d, %d)" % [monster_name, species, monster["threat_rating"], tx, ty])


func _generate_name(species: String, used_names: Array[String]) -> String:
	var prefix: String
	var title: String
	var titles: Array = SPECIES_TITLES.get(species, ["the Unknown"])
	var attempts = 0
	var name: String

	while attempts < 50:
		attempts += 1
		prefix = MONSTER_PREFIXES[randi() % MONSTER_PREFIXES.size()]
		title = titles[randi() % titles.size()]
		name = prefix + " " + title
		if name not in used_names:
			return name

	# Fallback: append a roman numeral
	name = prefix + " " + title + " " + String.chr(64 + attempts)  # A, B, C...
	return name


func _on_tick_advanced(_tick: int, _day: int, _season: String, _year: int) -> void:
	_attack_cooldown += 1
	_tick_counter += 1

	# Monster attack checks every 4 ticks
	if _tick_counter % 4 != 0:
		return

	if _attack_cooldown < ATTACK_TICK_INTERVAL:
		return
	_attack_cooldown = 0

	# Pick a random alive monster
	var alive: Array[Dictionary] = []
	for m in ColonyData.world_monsters:
		if m.get("alive", false):
			alive.append(m)

	if alive.is_empty():
		return

	var monster = alive[randi() % alive.size()]
	var lair_x: int = monster["lair_x"]
	var lair_y: int = monster["lair_y"]

	# Check if any nation is within 10 tiles
	for nation in ColonyData.nations:
		var nx: int = nation["capital_x"]
		var ny: int = nation["capital_y"]
		var dist = abs(lair_x - nx) + abs(lair_y - ny)  # Manhattan distance

		if dist <= 10:
			# Emit monster attack event targeting this nation
			var event_data = {
				"event_id": "monster_attack",
				"monster_id": monster["id"],
				"monster_name": monster["name"],
				"species": monster["species"],
				"threat_rating": monster["threat_rating"],
				"lair_x": lair_x,
				"lair_y": lair_y,
				"target_nation_id": nation["id"],
				"distance": dist,
			}
			EventBus.event_triggered.emit(nation["id"], "monster_attack", event_data)
			print("[Monster] %s attacks %s! (distance %d)" % [monster["name"], nation["name"], dist])
			break  # One attack per cycle


func _monster_defeated(monster_id: int, slayer_nation_id: int, monster_name: String) -> void:
	if monster_id < 0 or monster_id >= ColonyData.world_monsters.size():
		return

	ColonyData.world_monsters[monster_id]["alive"] = false

	var nation = ColonyData.get_nation(slayer_nation_id)
	if nation.is_empty():
		return

	# Award resources based on threat rating
	var threat: int = ColonyData.world_monsters[monster_id].get("threat_rating", 5)
	if "resources" in nation:
		nation["resources"]["gold"] = nation["resources"].get("gold", 0) + threat * 15
		nation["resources"]["gems"] = nation["resources"].get("gems", 0) + threat * 5

	# Record in world history
	if not ColonyData.world_history.has("monster_slayings"):
		ColonyData.world_history["monster_slayings"] = []
	ColonyData.world_history["monster_slayings"].append({
		"monster_id": monster_id,
		"monster_name": monster_name,
		"slayer_nation_id": slayer_nation_id,
		"slayer_nation_name": nation["name"],
		"threat_rating": threat,
		"tick": ColonyData.current_tick,
	})

	print("[Monster] %s defeated by %s! +%d gold, +%d gems" % [monster_name, nation["name"], threat * 15, threat * 5])


func get_monsters_on_tile(tile_x: int, tile_y: int) -> Array:
	var result: Array[Dictionary] = []
	for m in ColonyData.world_monsters:
		if m.get("alive", false) and m["lair_x"] == tile_x and m["lair_y"] == tile_y:
			result.append(m)
	return result


func get_nearest_monster(x: int, y: int) -> Dictionary:
	var nearest: Dictionary = {}
	var min_dist: int = 9999
	for m in ColonyData.world_monsters:
		if not m.get("alive", false):
			continue
		var dist = abs(x - m["lair_x"]) + abs(y - m["lair_y"])
		if dist < min_dist:
			min_dist = dist
			nearest = m
	return nearest
