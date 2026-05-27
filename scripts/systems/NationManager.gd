class_name NationManager
extends Node

var _ai_tick_counter: int = 0
const AI_TICK_INTERVAL: int = 30

var _ai_research_counter: int = 0
const AI_RESEARCH_INTERVAL: int = 60

var _policy_tick_counter: int = 0
const POLICY_TICK_INTERVAL: int = 60

# Track leader ages for death checks
var _leader_age_check_counter: int = 0

# Diplomatic assessment every 6 AI cycles (120 ticks)
var _diplo_cycle_counter: int = 0
const DIPLO_CYCLE_INTERVAL: int = 6

var _war_cooldown: Dictionary = {}  # {nation_id: ticks_remaining}

func _ready() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.leader_died.connect(_on_leader_died)
	EventBus.peace_signed.connect(_on_peace_signed)

func _on_peace_signed(a: int, b: int) -> void:
	_war_cooldown[a] = 60
	_war_cooldown[b] = 60

func _on_tick_advanced(_tick: int, _day: int, _season: String, _year: int) -> void:
	# Decrement war cooldowns
	for nid in _war_cooldown.keys():
		_war_cooldown[nid] -= 1
		if _war_cooldown[nid] <= 0:
			_war_cooldown.erase(nid)

	_ai_tick_counter += 1
	_leader_age_check_counter += 1

	if _ai_tick_counter >= AI_TICK_INTERVAL:
		_ai_tick_counter = 0
		_diplo_cycle_counter += 1
		var do_diplomacy: bool = (_diplo_cycle_counter % DIPLO_CYCLE_INTERVAL == 0)
		for nation in ColonyData.nations:
			if nation["id"] == ColonyData.player_nation_id:
				continue
			_run_ai_tick(nation, do_diplomacy)

	# AI Policy consideration
	_policy_tick_counter += 1
	if _policy_tick_counter >= POLICY_TICK_INTERVAL:
		_policy_tick_counter = 0
		for nation in ColonyData.nations:
			if nation["id"] == ColonyData.player_nation_id:
				continue
			_ai_consider_policies(nation)

	# Check leader ages every 60 ticks (~seasonal)
	if _leader_age_check_counter >= 60:
		_leader_age_check_counter = 0
		_check_leader_ages()

	# AI Tech Research every 60 ticks
	_ai_research_counter += 1
	if _ai_research_counter >= AI_RESEARCH_INTERVAL:
		_ai_research_counter = 0
		for nation in ColonyData.nations:
			if nation["id"] == ColonyData.player_nation_id:
				continue
			_ai_research(nation)

func _run_ai_tick(nation: Dictionary, do_diplomacy: bool = false) -> void:
	var leader = ColonyData.get_leader_cached(nation["id"])
	var ai_type: String = nation["ai_type"]

	# Leader personality modifies behavior weight
	var personality_mod = _get_leader_personality_mod(leader)

	# Apply difficulty ai_aggression modifier to personality
	var diff_settings: Dictionary = ColonyData.DIFFICULTY_SETTINGS.get(ColonyData.difficulty, ColonyData.DIFFICULTY_SETTINGS["normal"])
	var aggression_mult: float = diff_settings.get("ai_aggression", 1.0)
	personality_mod["aggression"] = personality_mod.get("aggression", 1.0) * aggression_mult

	# Diegetic proximity threat: nations near hostiles become more aggressive
	var prox_threat = _calculate_proximity_threat(nation)
	personality_mod["aggression"] *= prox_threat

	_evaluate_needs_and_act(nation, personality_mod)

	# Diplomatic assessment every 6 AI cycles (6 * 20 = 120 ticks)
	if do_diplomacy:
		_evaluate_alliances(nation)
		_evaluate_enemies(nation)

	# Population growth affected by leader traits
	if nation["resources"]["food"] > 20:
		var growth_chance: float = 0.2 * personality_mod.get("growth", 1.0)
		if randf() < growth_chance * 0.1:
			nation["population"] += 1

	# Leader affects resource priorities
	# Subsistence baseline — real production from race-aware terrain bonuses
	nation["resources"]["food"] += nation["population"] * 0.02
	nation["resources"]["wood"] += 0.5
	nation["resources"]["stone"] += 0.25

func _evaluate_needs_and_act(nation: Dictionary, mod: Dictionary) -> void:
	var race_id: String = nation["primary_race"]
	var race_data = ColonyData.RACES.get(race_id, {})
	var affinity: Dictionary = race_data.get("strategy_affinity", {"mine": 0.5, "trade": 0.5, "raid": 0.5, "expand": 0.5})
	
	# Subrace variant strategy_affinity override
	if ColonyData.RACE_VARIANTS.has(race_id):
		var variant: Dictionary = ColonyData.RACE_VARIANTS[race_id]
		var override_affinity: Dictionary = variant.get("strategy_affinity", {})
		if not override_affinity.is_empty():
			affinity = override_affinity
	
	var deficits: Dictionary = nation.get("resource_deficits", {})
	
	# Threshold: deficit must exceed this to trigger action
	var threshold = 0.05  # 5% of a typical deficit
	
	# Evaluate needs per resource
	var best_score = 10.0  # minimum score required to act
	var best_action = "wait"
	var best_target: int = -1
	var best_resource = ""
	
	for resource in deficits:
		var d: Dictionary = deficits[resource]
		var urgency: float = d.get("urgency", 0.0)
		var deficit: float = d.get("deficit", 0.0)
		
		if urgency < threshold and deficit <= 0.0:
			continue  # no deficit for this resource
		
		# Score each action for this resource
		for target in ColonyData.nations:
			if target["id"] == nation["id"]:
				continue
			
			# Score raid
			var raid_score = _score_raid(nation, target, resource, urgency, affinity, mod)
			if raid_score > best_score:
				best_score = raid_score
				best_action = "raid"
				best_target = target["id"]
				best_resource = resource
			
			# Score trade
			var trade_score = _score_trade(nation, target, resource, urgency, affinity, mod)
			if trade_score > best_score:
				best_score = trade_score
				best_action = "trade"
				best_target = target["id"]
				best_resource = resource
		
		# Score mine/expand (doesn't need a target nation)
		var mine_score = _score_mine_expand(nation, resource, urgency, affinity)
		if mine_score > best_score:
			best_score = mine_score
			best_action = "mine"
			best_target = -1
			best_resource = resource
	
	# Execute best action
	if best_action != "wait" and best_score >= 10.0:
		_ai_resource_action(nation, best_action, best_target, best_resource)
	else:
		# Fallback: personality-driven default
		if mod.get("aggression", 1.0) > 1.5:
			_ai_aggressive(nation, mod)
		elif mod.get("trade", 1.0) > 1.5:
			_ai_trader(nation, mod)

func _ai_aggressive(nation: Dictionary, mod: Dictionary) -> void:
	var aggression_mod = mod.get("aggression", 1.0)
	if aggression_mod < 0.5:
		return  # Leader won't start wars

	# Check war cooldown
	var nid: int = nation["id"]
	if _war_cooldown.get(nid, 0) > 0:
		return

	for target in ColonyData.nations:
		if target["id"] == nation["id"]:
			continue
		var threshold: float = 0.85 / aggression_mod
		if target["military_strength"] < nation["military_strength"] * threshold:
			if _get_relation(nation["id"], target["id"]) < 30 * aggression_mod:
				if randi() % 20 < int(aggression_mod * 10):
					continue  # Some restraint
				EventBus.war_declared.emit(nation["id"], target["id"])
				return

func _ai_trader(nation: Dictionary, mod: Dictionary) -> void:
	var trade_mod = mod.get("trade", 1.0)
	if randi() % max(1, int(10 / trade_mod)) == 0:
		for target in ColonyData.nations:
			if target["id"] != nation["id"] and _get_relation(nation["id"], target["id"]) > 40:
				var goods = ["food", "wood", "metal"]
				var pick = goods[randi() % goods.size()]
				EventBus.trade_route_established.emit(nation["id"], target["id"], pick)
				return

func _ai_passive(_nation: Dictionary) -> void:
	pass

func _ai_isolationist(_nation: Dictionary) -> void:
	pass

func _score_raid(nation: Dictionary, target: Dictionary, resource: String, urgency: float, affinity: Dictionary, mod: Dictionary) -> float:
	var mil_self: float = float(nation["military_strength"])
	var mil_target: float = float(target["military_strength"])
	var feasibility = clamp(mil_self / max(1.0, mil_target), 0.1, 1.0)
	
	var relation_penalty = 1.0 - _get_relation(nation["id"], target["id"]) / 200.0
	
	var base = 50.0 * urgency
	var race_bonus = affinity.get("raid", 0.5)
	var personality = mod.get("aggression", 1.0)
	
	return base * race_bonus * personality * feasibility * relation_penalty

func _score_trade(nation: Dictionary, target: Dictionary, resource: String, urgency: float, affinity: Dictionary, mod: Dictionary) -> float:
	var relation = _get_relation(nation["id"], target["id"])
	if relation < 40.0:
		return 0.0  # can't trade with unfriendly nations
	
	var feasibility = relation / 100.0
	
	var base = 40.0 * urgency
	var race_bonus = affinity.get("trade", 0.5)
	var personality = mod.get("trade", 1.0)
	
	return base * race_bonus * personality * feasibility

func _score_mine_expand(nation: Dictionary, resource: String, urgency: float, affinity: Dictionary) -> float:
	var race_id: String = nation["primary_race"]
	var race_data = ColonyData.RACES.get(race_id, {})
	var terrain_bonuses: Dictionary = race_data.get("terrain_bonuses", {})
	
	# Check if nation's terrain can produce this resource
	var can_produce = false
	var terrain_mod = 1.0
	
	match resource:
		"food":
			can_produce = terrain_bonuses.get("plains", 0.0) > 1.0 or terrain_bonuses.get("forest", 0.0) > 1.0
			terrain_mod = max(terrain_bonuses.get("plains", 1.0), terrain_bonuses.get("forest", 1.0))
		"wood":
			can_produce = terrain_bonuses.get("forest", 0.0) > 1.0
			terrain_mod = terrain_bonuses.get("forest", 1.0)
		"stone", "metal", "gold":
			can_produce = terrain_bonuses.get("mountain", 0.0) > 1.0 or terrain_bonuses.get("hills", 0.0) > 1.0 or terrain_bonuses.get("caves", 0.0) > 1.0
			terrain_mod = max(terrain_bonuses.get("mountain", 1.0), max(terrain_bonuses.get("hills", 1.0), terrain_bonuses.get("caves", 1.0)))
	
	if not can_produce:
		return 0.0  # Can't produce this resource from terrain
	
	var base = 30.0 * urgency
	var race_bonus = affinity.get("mine", 0.5) + affinity.get("expand", 0.5)
	
	return base * race_bonus * terrain_mod

func _ai_resource_action(nation: Dictionary, action: String, target_id: int, resource: String) -> void:
	match action:
		"raid":
			if target_id >= 0:
				EventBus.war_declared.emit(nation["id"], target_id)
				print("[AI] %s raids %s for %s" % [nation["name"], ColonyData.get_nation_cached(target_id).get("name", "?"), resource])
		
		"trade":
			if target_id >= 0:
				var trade_good = resource
				if resource in ["metal", "stone", "gold", "wood"]:
					trade_good = resource
				else:
					trade_good = "food"
				EventBus.trade_route_established.emit(nation["id"], target_id, trade_good)
				print("[AI] %s trades with %s for %s" % [nation["name"], ColonyData.get_nation_cached(target_id).get("name", "?"), resource])
		
		"mine":
			nation["ai_strategy"] = "mine_" + resource
		
		"expand":
			nation["ai_strategy"] = "expand"

# Diegetic proximity threat: nations closer to hostile neighbors gain tension
func _calculate_proximity_threat(nation: Dictionary) -> float:
	var closest_hostile = 9999.0
	for target in ColonyData.nations:
		if target["id"] == nation["id"]:
			continue
		if _get_relation(nation["id"], target["id"]) < 30:
			var dist = abs(nation["capital_x"] - target["capital_x"]) + abs(nation["capital_y"] - target["capital_y"])
			if dist < closest_hostile:
				closest_hostile = dist
	return clamp(1.0 + (1.0 - closest_hostile / 100.0), 0.5, 2.5)

func _get_leader_personality_mod(leader: Dictionary) -> Dictionary:
	var mod = {"aggression": 1.0, "growth": 1.0, "trade": 1.0, "diplomacy": 1.0}
	if leader.is_empty():
		return mod

	var traits: Array = leader.get("traits", [])

	if "aggressive" in traits:
		mod["aggression"] += 0.4
		mod["diplomacy"] -= 0.2
	if "ruthless" in traits:
		mod["aggression"] += 0.3
	if "cautious" in traits:
		mod["aggression"] -= 0.4
	if "ambitious" in traits:
		mod["aggression"] += 0.2
		mod["trade"] += 0.1
	if "generous" in traits:
		mod["trade"] += 0.2
	if "cunning" in traits:
		mod["trade"] += 0.3
	if "lazy" in traits:
		mod["aggression"] -= 0.3
		mod["growth"] -= 0.2
	if "mad" in traits:
		mod["aggression"] += randf_range(-0.5, 1.0)
		mod["diplomacy"] += randf_range(-0.5, 0.5)

	var arch = ColonyData.LEADER_ARCHETYPES.get(leader["archetype"], {})
	if arch.get("ai_behavior", "") == "aggressive":
		mod["aggression"] += 0.3
	elif arch.get("ai_behavior", "") == "trader":
		mod["trade"] += 0.3

	return mod

func _on_leader_died(character_id: int, _cause: String) -> void:
	for nation in ColonyData.nations:
		if nation.get("leader_id", -1) == character_id:
			print("[Nation] Leader of %s died. Succession triggered." % nation["name"])
			var cm = _get_character_manager()
			if cm:
				var new_leader = cm.replace_leader(nation["id"])
				nation["leader_id"] = new_leader["id"]
				EventBus.leader_changed.emit(nation["id"], character_id, new_leader["id"])

func _check_leader_ages() -> void:
	# Check if leaders die of old age
	for nation in ColonyData.nations:
		var leader = ColonyData.get_leader_cached(nation["id"])
		if leader.is_empty():
			continue

		var race = ColonyData.RACES.get(leader["race"], {})
		var max_age = race.get("traits", {}).get("longevity", 60)
		var age_ratio = float(leader["age"]) / float(max_age)

		# Age increment per check (~seasonal)
		leader["age"] = leader.get("age", 0) + 1

		# Death chance increases with age beyond 70% of lifespan
		if age_ratio > 0.7:
			var death_chance = (age_ratio - 0.7) * 0.05
			if randf() < death_chance:
				leader["alive"] = false
				EventBus.leader_died.emit(leader["id"], "old_age")
				print("[Nation] %s of %s died of old age at %d." % [
					leader["name"], nation["name"], leader["age"]
				])

func _get_relation(nation_a: int, nation_b: int) -> float:
	if nation_a >= ColonyData.diplomacy_matrix.size():
		return 50.0
	if nation_b >= ColonyData.diplomacy_matrix[nation_a].size():
		return 50.0
	return ColonyData.diplomacy_matrix[nation_a][nation_b]

func _get_character_manager() -> Node:
	var root = get_tree().current_scene
	if root:
		var sys = root.get_node_or_null("Systems")
		if sys:
			return sys.get_node_or_null("CharacterManager")
	return null


func _get_tech_manager() -> Node:
	var root = get_tree().current_scene
	if root:
		var sys = root.get_node_or_null("Systems")
		if sys:
			return sys.get_node_or_null("TechManager")
	return null


func _ai_research(nation: Dictionary) -> void:
	var nid: int = nation["id"]
	var tm = _get_tech_manager()
	if not tm:
		return

	var available: Array = tm.get_available_techs(nid)
	if available.is_empty():
		return

	var best_tech_id = ""
	var best_score = -1.0

	for tech_data in available:
		if tech_data.get("unlocked", false):
			continue
		if not tech_data.get("unlockable", false):
			continue
		var score = _score_tech(nation, tech_data)
		if score > best_score:
			best_score = score
			best_tech_id = tech_data["id"]

	if best_tech_id != "" and best_score > 0:
		if tm.unlock_tech(nid, best_tech_id):
			print("[AI] %s researched %s (score: %.1f)" % [nation["name"], best_tech_id, best_score])


func _score_tech(nation: Dictionary, tech: Dictionary) -> float:
	var score = 10.0  # Base desire to research
	var tech_id: String = tech["id"]
	var era: String = tech.get("era", "stone")
	var cost: float = float(tech.get("cost", 10.0))
	var deficits: Dictionary = nation.get("resource_deficits", {})

	# Prefer techs the nation can afford soon
	var rp = 0.0
	var tm = _get_tech_manager()
	if tm:
		rp = tm.research_points.get(nation["id"], 0.0)
	if cost > 0:
		score += clamp(rp / cost, 0.0, 20.0) * 10.0

	# Prefer cheaper techs (faster to unlock)
	if cost > 0:
		score += max(0.0, 15.0 - cost * 0.5)

	# Race-specific tech affinity bonus
	var race_id: String = nation["primary_race"]
	var affinity: float = TechData.RACE_TECH_AFFINITY.get(race_id, 1.0)
	score *= affinity

	# Prioritize military techs for aggressive AI
	var ai_type: String = nation["ai_type"]
	if ai_type in ["aggressive", "expansionist"]:
		if tech_id in ["basic_weapons", "advanced_weapons", "fortifications", "siege_engines", "military_tactics"]:
			score += 20.0
		if tech_id in ["hunting", "animal_taming", "war_beasts"]:
			score += 10.0

	# Prioritize economic techs for trader/builder AI
	if ai_type in ["trader", "builder", "passive", "isolationist"]:
		if tech_id in ["farming", "irrigation", "crop_rotation", "currency", "trade_routes"]:
			score += 20.0
		if tech_id in ["mining", "masonry", "metalworking"]:
			score += 10.0

	# Address resource deficits
	if not deficits.is_empty():
		if deficits.get("food", {}).get("deficit", 0.0) > 0.0:
			if tech_id in ["farming", "irrigation", "hunting", "animal_taming", "crop_rotation"]:
				score += 25.0
		if deficits.get("metal", {}).get("deficit", 0.0) > 0.0:
			if tech_id in ["mining", "metalworking", "basic_weapons"]:
				score += 20.0
		if deficits.get("wood", {}).get("deficit", 0.0) > 0.0:
			if tech_id in ["woodworking", "carpentry", "shipbuilding"]:
				score += 15.0

	# Era progression — prefer to advance
	var era_order = ["stone", "bronze", "iron", "classical", "medieval"]
	var era_idx = era_order.find(era)
	if era_idx >= 0:
		score += era_idx * 5.0  # Higher eras are more valuable

	return score


func _get_policy_manager() -> Node:
	var root = get_tree().current_scene
	if root:
		var sys = root.get_node_or_null("Systems")
		if sys:
			return sys.get_node_or_null("PolicyManager")
	return null


func _ai_consider_policies(nation: Dictionary) -> void:
	var nid: int = nation["id"]
	var deficits: Dictionary = nation.get("resource_deficits", {})
	var res = nation["resources"]
	var pm = _get_policy_manager()
	if not pm: return

	# Score available policies
	for policy_id in pm.all_policies:
		var policy = pm.all_policies[policy_id]

		# Skip if already active (will check for revoke later)
		if policy_id in nation["policies"]:
			continue

		# Skip if not unlocked
		if not policy.get("unlocked", true):
			continue

		# Check affordability
		var can_afford = true
		for cost_res in policy.get("cost", {}):
			var required = float(policy["cost"][cost_res])
			if res.get(cost_res, 0.0) < required:
				can_afford = false
				break
		if not can_afford:
			continue

		# Score policy benefit vs current situation
		var score = _score_policy_benefit(policy_id, deficits, res)

		# Enact if score is high enough
		if score > 15.0:
			pm.enact_policy(nid, policy_id)
			print("[AI] %s enacted %s (score: %.1f)" % [nation["name"], policy["name"], score])

	# Check active policies for revocation
	for policy_id in nation["policies"].duplicate():
		var harm_score = _score_policy_harm(policy_id, deficits)
		if harm_score > 20.0:
			pm.revoke_policy(nid, policy_id)
			print("[AI] %s revoked %s (harm: %.1f)" % [nation["name"], pm.all_policies.get(policy_id, {}).get("name", policy_id), harm_score])


func _score_policy_benefit(policy_id: String, deficits: Dictionary, _res: Dictionary) -> float:
	var score = 0.0

	match policy_id:
		"tavern_open":
			# Helps morale, but costs food consumption
			if deficits.get("food", {}).get("deficit", 0.0) > 0.0:
				score -= 30.0  # Don't enact when food is tight
			else:
				score += 15.0  # Free morale boost when food is abundant

		"mandatory_labor":
			# Boosts production — always useful, especially with deficits
			var has_deficit = false
			for r in deficits:
				if deficits[r].get("deficit", 0.0) > 0.0:
					has_deficit = true
					break
			score += 10.0 if has_deficit else 5.0

		"sanitation_mandate":
			# Costs wood, helps health
			if deficits.get("wood", {}).get("deficit", 0.0) > 0.0:
				score -= 10.0  # Don't spend scarce wood
			else:
				score += 8.0  # Health is good

		"militia_training":
			# Costs metal, boosts military
			if deficits.get("metal", {}).get("deficit", 0.0) > 0.0:
				score -= 20.0  # Don't spend scarce metal
			else:
				score += 12.0  # Military is useful

		"open_borders":
			# Helps trade
			var trade_needed = deficits.get("food", {}).get("deficit", 0.0) > 0.0 or deficits.get("metal", {}).get("deficit", 0.0) > 0.0
			score += 15.0 if trade_needed else 3.0

		"heavy_taxation":
			# More gold, costs morale
			if deficits.get("gold", {}).get("deficit", 0.0) > 0.0:
				score += 18.0  # Enact when gold is needed
			else:
				score += 5.0  # Free gold when gold is fine

	return score


func _score_policy_harm(policy_id: String, deficits: Dictionary) -> float:
	var harm = 0.0

	match policy_id:
		"tavern_open":
			if deficits.get("food", {}).get("deficit", 0.0) > 1.0:
				harm += 25.0  # Food crisis — revoke tavern

		"militia_training":
			if deficits.get("metal", {}).get("deficit", 0.0) > 2.0:
				harm += 22.0  # Metal crisis — revoke militia

		"sanitation_mandate":
			if deficits.get("wood", {}).get("deficit", 0.0) > 1.0:
				harm += 18.0  # Wood shortage — revoke sanitation

	return harm


func _diplomatic_assessment(nation: Dictionary, target: Dictionary) -> Dictionary:
	var assessment = {
		"threat_score": 0.0,
		"alliance_value": 0.0,
		"stance": "neutral",
		"government_affinity": 0.0,
	}
	
	# Threat: military comparison + proximity
	var self_mil: float = float(nation["military_strength"])
	var target_mil: float = float(target["military_strength"])
	if self_mil > 0:
		assessment["threat_score"] = clamp(target_mil / self_mil, 0.0, 3.0)
	
	# Proximity bonus
	var dx = abs(nation["capital_x"] - target["capital_x"])
	var dy = abs(nation["capital_y"] - target["capital_y"])
	if dx + dy < 30:
		assessment["threat_score"] *= 1.5
	
	# Alliance value: trade complementarity + shared enemies
	var rel = _get_relation(nation["id"], target["id"])
	assessment["alliance_value"] = rel / 100.0
	
	# Government affinity
	assessment["government_affinity"] = _government_affinity(nation, target)
	assessment["alliance_value"] *= (1.0 + assessment["government_affinity"] * 0.5)
	
	# Determine stance
	if assessment["threat_score"] > 2.0:
		assessment["stance"] = "enemy"
	elif assessment["threat_score"] > 1.2:
		assessment["stance"] = "rival"
	elif assessment["alliance_value"] > 0.6:
		assessment["stance"] = "ally"
	else:
		assessment["stance"] = "neutral"
	
	return assessment


func _government_affinity(nation: Dictionary, target: Dictionary) -> float:
	var gov_a: String = nation.get("government", "kingdom")
	var gov_b: String = target.get("government", "kingdom")
	if gov_a == gov_b:
		return 0.3
	var gov_data = ColonyData.GOVERNMENT_TYPES.get(gov_a, {})
	var bias: Dictionary = gov_data.get("diplomatic_bias", {})
	return bias.get(gov_b, 0.0) / 100.0


func _evaluate_alliances(nation: Dictionary) -> void:
	var best_ally_score = 0.3
	var best_ally_id = -1
	for target in ColonyData.nations:
		if target["id"] == nation["id"]:
			continue
		if target["id"] == ColonyData.player_nation_id:
			continue
		var assessment = _diplomatic_assessment(nation, target)
		if assessment["alliance_value"] > best_ally_score and assessment["stance"] == "ally":
			best_ally_score = assessment["alliance_value"]
			best_ally_id = target["id"]
	if best_ally_id >= 0:
		EventBus.alliance_formed.emit(nation["id"], best_ally_id)
		print("[AI] %s formed alliance with %s" % [nation["name"], ColonyData.get_nation_cached(best_ally_id).get("name", "?")])


func _evaluate_enemies(nation: Dictionary) -> void:
	var worst_threat = 1.0
	var enemy_id = -1
	for target in ColonyData.nations:
		if target["id"] == nation["id"]:
			continue
		if target["id"] == ColonyData.player_nation_id:
			continue
		var assessment = _diplomatic_assessment(nation, target)
		if assessment["threat_score"] > worst_threat and assessment["stance"] in ["enemy", "rival"]:
			worst_threat = assessment["threat_score"]
			enemy_id = target["id"]
	if enemy_id >= 0 and randf() < 0.1:
		if _war_cooldown.get(nation["id"], 0) > 0:
			return
		EventBus.war_declared.emit(nation["id"], enemy_id)
		print("[AI] %s declared war on %s (threat: %.1f)" % [nation["name"], ColonyData.get_nation_cached(enemy_id).get("name", "?"), worst_threat])
