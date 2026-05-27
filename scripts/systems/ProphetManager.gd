class_name ProphetManager
extends Node

# Players send prophets to nations to spread belief and influence

var _active_prophets: Array[Dictionary] = []
var _send_cooldown: int = 0
const SEND_COOLDOWN: int = 60

func _ready() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)

func send_prophet(target_nation_id: int) -> Dictionary:
	if _send_cooldown > 0:
		return {"success": false, "reason": "Cooldown: %d ticks remaining" % _send_cooldown}

	var dm = _get_deity_manager()
	if not dm or dm.divine_power < 25:
		return {"success": false, "reason": "Not enough divine power (need 25)"}

	# Pick a race from the target nation for the prophet
	var nation = ColonyData.get_nation(target_nation_id)
	if nation.is_empty():
		return {"success": false, "reason": "Nation not found"}

	# Prefer a race with existing belief, otherwise use nation's primary
	var prophet_race = nation["primary_race"]
	for race_id in nation.get("race_demographics", {}):
		if ColonyData.get_belief(target_nation_id, race_id) > 0.2:
			prophet_race = race_id
			break

	# Create the prophet character
	var cm: Node = _get_character_manager()
	var prophet: Dictionary
	if cm:
		prophet = cm.generate_prophet(dm.deity_class, prophet_race)
	else:
		return {"success": false, "reason": "Character system offline"}

	# Pay cost
	dm.divine_power -= 25
	_send_cooldown = SEND_COOLDOWN

	# Set prophet nation
	prophet["nation_id"] = target_nation_id

	# Add to prophets list
	var prophet_data = {
		"character_id": prophet["id"],
		"nation_id": target_nation_id,
		"ticks_active": 0,
		"conversions": 0,
		"alive": true,
		"effectiveness": prophet.get("effectiveness", 1.0),
	}
	_active_prophets.append(prophet_data)
	ColonyData.prophets.append(prophet_data)

	EventBus.prophet_sent.emit(target_nation_id, prophet["id"])
	print("[Prophet] %s sent to nation %d" % [prophet["name"], target_nation_id])
	return {"success": true, "prophet": prophet}

func recall_prophet(target_nation_id: int) -> bool:
	for i in range(_active_prophets.size()):
		if _active_prophets[i]["nation_id"] == target_nation_id and _active_prophets[i]["alive"]:
			_active_prophets.remove_at(i)
			for j in range(ColonyData.prophets.size()):
				if ColonyData.prophets[j]["nation_id"] == target_nation_id:
					ColonyData.prophets.remove_at(j)
					break
			EventBus.prophet_recalled.emit(target_nation_id)
			return true
	return false

func _on_tick_advanced(_tick: int, _day: int, _season: String, _year: int) -> void:
	_send_cooldown -= 1

	for p in _active_prophets:
		if not p["alive"]:
			continue

		p["ticks_active"] += 1

		# Prophet spreads belief each tick
		var nat = ColonyData.get_nation(p["nation_id"])
		if nat.is_empty():
			continue

		for race_id in nat.get("race_demographics", {}):
			var current_belief = ColonyData.get_belief(p["nation_id"], race_id)
			var spread = p["effectiveness"] * 0.008
			# Match race of prophet for bonus
			var prophet_char = _get_character(p["character_id"])
			if not prophet_char.is_empty() and prophet_char["race"] == race_id:
				spread *= 1.5
			ColonyData.set_belief(p["nation_id"], race_id, current_belief + spread)
			EventBus.belief_changed.emit(p["nation_id"], race_id, ColonyData.get_belief(p["nation_id"], race_id))

		# Chance to convert someone (step change in belief)
		if p["ticks_active"] % 20 == 0 and randf() < 0.3:
			p["conversions"] += 1
			for race_id in nat.get("race_demographics", {}):
				ColonyData.set_belief(p["nation_id"], race_id,
					ColonyData.get_belief(p["nation_id"], race_id) + 0.05)
			EventBus.prophet_conversion.emit(p["nation_id"], p["character_id"], p["conversions"])

		# Risk of martyrdom (small chance of death with boost)
		if randf() < 0.002:
			p["alive"] = false
			# Martyr bonus: big belief spike
			for race_id in nat.get("race_demographics", {}):
				ColonyData.set_belief(p["nation_id"], race_id,
					ColonyData.get_belief(p["nation_id"], race_id) + 0.15)
			EventBus.prophet_died.emit(p["nation_id"], p["character_id"], "martyr")
			print("[Prophet] Prophet martyred in nation %d! Belief surged." % p["nation_id"])

	# Clean up dead prophets
	_active_prophets = _active_prophets.filter(func(p): return p["alive"])

func get_active_prophets() -> Array[Dictionary]:
	return _active_prophets.duplicate()

func _get_character(char_id: int) -> Dictionary:
	for c in ColonyData.characters:
		if c["id"] == char_id:
			return c
	return {}

func _get_deity_manager() -> Node:
	var root = get_tree().current_scene
	if root:
		var sys = root.get_node_or_null("Systems")
		if sys:
			return sys.get_node_or_null("DeityManager")
	return null

func _get_character_manager() -> Node:
	var root = get_tree().current_scene
	if root:
		var sys = root.get_node_or_null("Systems")
		if sys:
			return sys.get_node_or_null("CharacterManager")
	return null
