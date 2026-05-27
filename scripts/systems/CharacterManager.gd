class_name CharacterManager
extends Node

var _rng: RandomNumberGenerator

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = randi()

func generate_leader(nation_id: int, race_id: String) -> Dictionary:
	var race = ColonyData.RACES.get(race_id, ColonyData.RACES["human"])
	var char_id = ColonyData.next_character_id()

	# Pick archetype weighted by race tendencies
	var archetypes = _filter_archetypes_by_race(race_id)
	var archetype = archetypes[randi() % archetypes.size()]
	var arch_data = ColonyData.LEADER_ARCHETYPES[archetype]

	# Generate traits
	var traits: Array[String] = []
	traits.append(_pick_random_trait(arch_data["preferred_traits"]))
	var extra_count: int = randi_range(1, 2)
	for _i in range(extra_count):
		var t = ColonyData.CHARACTER_TRAITS.keys()[randi() % ColonyData.CHARACTER_TRAITS.size()]
		if t not in traits:
			traits.append(t)

	# Gender
	var gender = "male" if randf() < 0.5 else "female"

	# Name from race pool
	var name = _generate_name(race_id, gender)

	# Age based on race longevity
	var longevity = race["traits"]["longevity"]
	var min_age = int(longevity * 0.1)
	var max_age = int(longevity * 0.5)
	var age = randi_range(min_age, max_age)

	var character: Dictionary = {
		"id": char_id,
		"name": name,
		"race": race_id,
		"gender": gender,
		"age": age,
		"archetype": archetype,
		"traits": traits,
		"role": "leader",
		"nation_id": nation_id,
		"alive": true,
		"piety": _roll_trait_multiplier(traits, "piety"),
		"stubbornness": _roll_trait_multiplier(traits, "stubbornness") * race["traits"]["stubbornness"],
		"influence_resistance": _calculate_influence_resistance(traits, arch_data),
	}

	ColonyData.characters.append(character)

	# Update nation with leader
	var nation = ColonyData.get_nation(nation_id)
	if not nation.is_empty():
		nation["leader_id"] = char_id
		# Override AI type based on archetype
		nation["ai_type"] = arch_data["ai_behavior"] if arch_data.has("ai_behavior") else nation["ai_type"]

	EventBus.leader_generated.emit(char_id, character)
	print("[Character] Generated: %s (%s %s, %s, age %d)" % [name, race_id, gender, archetype, age])
	return character

func generate_prophet(deity_class: String, race_id: String, gender: String = "") -> Dictionary:
	var char_id = ColonyData.next_character_id()
	var race = ColonyData.RACES.get(race_id, ColonyData.RACES["human"])
	if gender.is_empty():
		gender = "male" if randf() < 0.5 else "female"

	var name = _generate_name(race_id, gender)
	var age = randi_range(int(race["traits"]["longevity"] * 0.15), int(race["traits"]["longevity"] * 0.4))
	var piety = randf_range(1.3, 2.0)

	var traits: Array[String] = ["pious"]
	traits.append(ColonyData.CHARACTER_TRAITS.keys()[randi() % ColonyData.CHARACTER_TRAITS.size()])

	var character: Dictionary = {
		"id": char_id,
		"name": name,
		"race": race_id,
		"gender": gender,
		"age": age,
		"archetype": "prophet",
		"traits": traits,
		"role": "prophet",
		"nation_id": -1,
		"alive": true,
		"piety": piety,
		"effectiveness": piety * race.get("faith_per_pop", 1.0),
		"miracles_can_cast": [],
	}

	ColonyData.characters.append(character)
	EventBus.prophet_created.emit(char_id, character)
	print("[Character] Prophet born: %s (%s)" % [name, race_id])
	return character

func replace_leader(nation_id: int) -> Dictionary:
	# Kill old leader
	var old_leader = ColonyData.get_leader(nation_id)
	if not old_leader.is_empty():
		old_leader["alive"] = false
		EventBus.leader_died.emit(old_leader["id"], "natural")

	# Pick successor race from demographics
	var nation = ColonyData.get_nation(nation_id)
	var demos: Dictionary = nation.get("race_demographics", {})
	var successor_race = ""
	var best_weight = 0.0
	for race_id in demos.keys():
		if demos[race_id] > best_weight:
			best_weight = demos[race_id]
			successor_race = race_id

	return generate_leader(nation_id, successor_race)

func _filter_archetypes_by_race(race_id: String) -> Array[String]:
	var cultural: Array = ColonyData.RACES[race_id].get("cultural_tendencies", []) as Array
	var matches: Array[String] = []

	for arch_id in ColonyData.LEADER_ARCHETYPES:
		for tendency in cultural:
			var arch: Dictionary = ColonyData.LEADER_ARCHETYPES[arch_id]
			var traits: Array = arch["preferred_traits"] as Array
			for i in range(traits.size()):
				if _trait_matches_tendency(str(traits[i]), tendency):
					matches.append(arch_id)
					break

	if matches.is_empty():
		matches = ColonyData.LEADER_ARCHETYPES.keys()
	return matches

func _trait_matches_tendency(t, td):
	var mapping: Dictionary = {
		"warlike": "aggressive",
		"diplomatic": "charismatic",
		"traditional": "traditional",
		"mystical": "pious",
		"clever": "cunning",
		"opportunistic": "cunning",
		"industrious": "calculating",
		"might_makes_right": "ruthless",
	}
	return mapping.get(td, td) == t

func _generate_name(race_id: String, gender: String) -> String:
	var race = ColonyData.RACES.get(race_id, ColonyData.RACES["human"])
	var pool = race["name_pool"].get(gender, ["Unknown"])
	return pool[randi() % pool.size()]

func _pick_random_trait(pool: Array) -> String:
	return pool[randi() % pool.size()]

func _roll_trait_multiplier(traits: Array, stat: String) -> float:
	var val = 1.0
	for t in traits:
		val += ColonyData.CHARACTER_TRAITS.get(t, {}).get("influence_mod", 0.0) if stat == "piety" else 0.0
	return clamp(val, 0.3, 2.5)

func _calculate_influence_resistance(traits: Array, arch_data: Dictionary) -> float:
	var base = 1.0
	for t in traits:
		base += ColonyData.CHARACTER_TRAITS.get(t, {}).get("influence_mod", 0.0) * -1  # positive mod = easier = lower resistance
	base *= arch_data.get("influence_resistance_mod", 1.0)
	return clamp(base, 0.2, 2.5)
