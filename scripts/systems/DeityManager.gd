class_name DeityManager
extends Node

# =============================================================================
# DEITY CLASSES - Selectable at game start
# =============================================================================

const DEITY_CLASSES: Dictionary = {
	"forge_lord": {
		"name": "Forge Lord",
		"description": "Master of industry and crafting. Your followers build wonders.",
		"synergy_races": ["dwarf", "human"],
		"starting_miracles": ["bless_harvest", "inspire_crafter"],
		"passive_bonus": {"production": 1.15, "crafting_speed": 1.2},
		"skill_tree": {
			"tier1": [
				{"id": "ore_sense", "name": "Ore Sense", "desc": "Reveal nearby mineral deposits on the map.", "cost": 2, "requires": []},
				{"id": "master_smiths", "name": "Master Smiths", "desc": "+20% metal production in believing nations.", "cost": 1, "requires": []},
				{"id": "stone_skin", "name": "Stone Skin", "desc": "Followers gain +1 defense per 10 believers.", "cost": 2, "requires": []},
			],
			"tier2": [
				{"id": "legendary_forge", "name": "Legendary Forge", "desc": "Unlock unique legendary items for heroes.", "cost": 3, "requires": ["master_smiths"]},
				{"id": "golem_crafting", "name": "Golem Crafting", "desc": "Create stone golem defenders for believer cities.", "cost": 4, "requires": ["stone_skin"]},
				{"id": "deep_mining", "name": "Deep Mining", "desc": "+40% mining yield. Tunnel through mountains.", "cost": 3, "requires": ["ore_sense"]},
			],
			"tier3": [
				{"id": "earthquake", "name": "Earthquake", "desc": "Shatter enemy fortifications. Miracle unlocked.", "cost": 5, "requires": ["legendary_forge", "deep_mining"]},
				{"id": "living_metal", "name": "Living Metal", "desc": "Weapons and armor repair themselves. +30% military power.", "cost": 5, "requires": ["golem_crafting"]},
			],
		},
	},
	"war_god": {
		"name": "War God",
		"description": "Lord of battle and conquest. Your followers crush all opposition.",
		"synergy_races": ["orc", "human"],
		"starting_miracles": ["bless_harvest", "fortify_defenses"],
		"passive_bonus": {"military_power": 1.2, "conquest_speed": 1.3},
		"skill_tree": {
			"tier1": [
				{"id": "battle_frenzy", "name": "Battle Frenzy", "desc": "Believers fight harder when outnumbered.", "cost": 1, "requires": []},
				{"id": "war_drums", "name": "War Drums", "desc": "+10% recruitment speed per 20 believers.", "cost": 2, "requires": []},
				{"id": "blood_oath", "name": "Blood Oath", "desc": "Followers never retreat. Morale locked above 30%.", "cost": 2, "requires": []},
			],
			"tier2": [
				{"id": "smite_invaders", "name": "Smite Invaders", "desc": "Call divine lightning on enemy armies.", "cost": 3, "requires": ["battle_frenzy"]},
				{"id": "war_path", "name": "War Path", "desc": "Movement speed doubled during war. Miracle unlocked.", "cost": 3, "requires": ["war_drums"]},
				{"id": "trophy_collector", "name": "Trophy Collector", "desc": "Gain divine power from battles won.", "cost": 2, "requires": ["blood_oath"]},
			],
			"tier3": [
				{"id": "avatar_of_war", "name": "Avatar of War", "desc": "Manifest on the battlefield. Win a losing battle once per age.", "cost": 6, "requires": ["smite_invaders", "trophy_collector"]},
				{"id": "endless_crusade", "name": "Endless Crusade", "desc": "War exhaustion never applies to your followers.", "cost": 5, "requires": ["war_path"]},
			],
		},
	},
	"nature_warden": {
		"name": "Nature Warden",
		"description": "Guardian of life and growth. Your followers flourish in harmony.",
		"synergy_races": ["elf", "halfling"],
		"starting_miracles": ["bless_harvest", "healing_rain"],
		"passive_bonus": {"food_production": 1.3, "population_growth": 1.2},
		"skill_tree": {
			"tier1": [
				{"id": "bountiful_harvest", "name": "Bountiful Harvest", "desc": "+25% food from believers.", "cost": 1, "requires": []},
				{"id": "wild_growth", "name": "Wild Growth", "desc": "Forests spread into neighboring tiles over time.", "cost": 2, "requires": []},
				{"id": "animal_kinship", "name": "Animal Kinship", "desc": "Wild animals defend believer territory.", "cost": 2, "requires": []},
			],
			"tier2": [
				{"id": "golden_age", "name": "Golden Age", "desc": "Temporary massive boost to all yields. Miracle unlocked.", "cost": 3, "requires": ["bountiful_harvest"]},
				{"id": "living_forest", "name": "Living Forest", "desc": "Tree ents defend your forests. +50% forest defense.", "cost": 4, "requires": ["wild_growth"]},
				{"id": "herbal_mastery", "name": "Herbal Mastery", "desc": "+50% healing rate. Plagues never strike believers.", "cost": 3, "requires": ["animal_kinship"]},
			],
			"tier3": [
				{"id": "world_tree", "name": "World Tree", "desc": "Plant a divine tree. All believers gain +2 to all stats.", "cost": 6, "requires": ["living_forest", "golden_age"]},
			],
		},
	},
	"trade_lord": {
		"name": "Trade Lord",
		"description": "Master of commerce and diplomacy. Gold flows where you will it.",
		"synergy_races": ["halfling", "human"],
		"starting_miracles": ["bless_harvest", "inspire_crafter"],
		"passive_bonus": {"trade_income": 1.3, "diplomatic_weight": 1.3},
		"skill_tree": {
			"tier1": [
				{"id": "silver_tongue", "name": "Silver Tongue", "desc": "+20% diplomatic success chance.", "cost": 1, "requires": []},
				{"id": "caravan_master", "name": "Caravan Master", "desc": "Trade routes generate +30% income.", "cost": 2, "requires": []},
				{"id": "marketplace", "name": "Marketplace Blessing", "desc": "Believer markets attract foreign traders.", "cost": 1, "requires": []},
			],
			"tier2": [
				{"id": "economic_dominance", "name": "Economic Dominance", "desc": "Nations trading with you become dependent. +vassalage chance.", "cost": 3, "requires": ["caravan_master"]},
				{"id": "gilded_guard", "name": "Gilded Guard", "desc": "Hire mercenaries at 50% cost.", "cost": 3, "requires": ["marketplace"]},
				{"id": "trade_secrets", "name": "Trade Secrets", "desc": "Steal technologies from trading partners.", "cost": 2, "requires": ["silver_tongue"]},
			],
			"tier3": [
				{"id": "golden_roads", "name": "Golden Roads", "desc": "All trade routes through your territory pay you tolls.", "cost": 5, "requires": ["economic_dominance"]},
				{"id": "market_oracle", "name": "Market Oracle", "desc": "Predict resource price changes. Always buy low, sell high.", "cost": 4, "requires": ["trade_secrets", "gilded_guard"]},
			],
		},
	},
	"death_whisper": {
		"name": "Death Whisper",
		"description": "Lord of the end. Your followers know death is not the final word.",
		"synergy_races": ["goblin", "orc"],
		"starting_miracles": ["bless_harvest", "smite_invaders"],
		"passive_bonus": {"fear_aura": 1.0, "undead_labor": 0.5},
		"skill_tree": {
			"tier1": [
				{"id": "death_sense", "name": "Death Sense", "desc": "Detect deaths across the world. Gain power from each.", "cost": 1, "requires": []},
				{"id": "fear_aura", "name": "Fear Aura", "desc": "Enemy morale drops near believers.", "cost": 2, "requires": []},
				{"id": "raise_skeleton", "name": "Raise Skeleton", "desc": "Fallen soldiers rise as undead laborers.", "cost": 2, "requires": []},
			],
			"tier2": [
				{"id": "plague_bringer", "name": "Plague Bringer", "desc": "Unleash disease on enemy nations.", "cost": 3, "requires": ["death_sense"]},
				{"id": "lich_domain", "name": "Lich Domain", "desc": "Immortal undead generals lead armies.", "cost": 4, "requires": ["raise_skeleton"]},
				{"id": "soul_harvest", "name": "Soul Harvest", "desc": "Gain divine power from believers who die in battle.", "cost": 2, "requires": ["fear_aura"]},
			],
			"tier3": [
				{"id": "army_of_damned", "name": "Army of the Damned", "desc": "Mass raise undead army. Miracle unlocked.", "cost": 6, "requires": ["lich_domain", "soul_harvest"]},
			],
		},
	},
	"knowledge_keeper": {
		"name": "Knowledge Keeper",
		"description": "Guardian of wisdom and arcane secrets. Knowledge is true power.",
		"synergy_races": ["elf", "dwarf"],
		"starting_miracles": ["bless_harvest", "inspire_crafter"],
		"passive_bonus": {"research_speed": 1.4, "arcana": 1.3},
		"skill_tree": {
			"tier1": [
				{"id": "ancient_wisdom", "name": "Ancient Wisdom", "desc": "+25% research speed for believers.", "cost": 1, "requires": []},
				{"id": "arcane_insight", "name": "Arcane Insight", "desc": "Reveal hidden resources and secrets on the map.", "cost": 2, "requires": []},
				{"id": "prophetic_visions", "name": "Prophetic Visions", "desc": "See events 10 ticks before they trigger.", "cost": 2, "requires": []},
			],
			"tier2": [
				{"id": "enchantment_mastery", "name": "Enchantment Mastery", "desc": "Permanently enchant believer equipment.", "cost": 3, "requires": ["ancient_wisdom"]},
				{"id": "ley_lines", "name": "Ley Lines", "desc": "Tap into magical ley lines. +50% miracle power.", "cost": 4, "requires": ["arcane_insight"]},
				{"id": "mind_link", "name": "Mind Link", "desc": "Directly communicate with leaders anywhere.", "cost": 2, "requires": ["prophetic_visions"]},
			],
			"tier3": [
				{"id": "omniscience", "name": "Omniscience", "desc": "Reveal the entire world map. See everything.", "cost": 5, "requires": ["ley_lines"]},
				{"id": "arcane_cataclysm", "name": "Arcane Cataclysm", "desc": "Unleash raw magic. Devastate an area. Miracle unlocked.", "cost": 6, "requires": ["enchantment_mastery", "mind_link"]},
			],
		},
	},
}

# =============================================================================
# ASPECTS - Unlocked at specific skill tiers. New aspect dimension beyond class.
# =============================================================================

const ASPECTS: Dictionary = {
	"aspect_of_war": {
		"name": "Aspect of War", "domain": "war",
		"description": "Your martial aspect. Empowers warriors and conquest.",
		"unlock_skill_requirement": "smite_invaders",
		"unlock_rank": 2,
		"mini_skills": [
			{"id": "war_aspect_fury", "name": "Divine Fury", "desc": "+10% military per 50 believers.", "cost": 1},
			{"id": "war_aspect_conquest", "name": "Path of Conquest", "desc": "Captured territory instantly converts 10% belief.", "cost": 2},
			{"id": "war_aspect_champion", "name": "Divine Champion", "desc": "Spawn a hero unit in believing nation.", "cost": 3},
		],
		"aspect_miracles": ["smite_invaders"],
		"passive_bonus": {"military_power": 1.15, "fear": 0.3},
		"believer_attraction": {"orc": 0.3, "human": 0.1},
		"compatible_with": ["aspect_of_knowledge", "aspect_of_death"],
		"conflicts_with": ["aspect_of_nature", "aspect_of_trade"],
	},
	"aspect_of_harvest": {
		"name": "Aspect of Harvest", "domain": "bounty",
		"description": "Your nurturing aspect. Blesses fields and families.",
		"unlock_skill_requirement": "bountiful_harvest",
		"unlock_rank": 2,
		"mini_skills": [
			{"id": "harvest_abundance", "name": "Abundance", "desc": "+20% food production.", "cost": 1},
			{"id": "harvest_family", "name": "Blessed Family", "desc": "+15% growth rate.", "cost": 2},
			{"id": "harvest_feast", "name": "Great Feast", "desc": "Annual festival boosts morale +20.", "cost": 2},
		],
		"aspect_miracles": ["bless_harvest", "golden_age"],
		"passive_bonus": {"food": 1.2, "growth": 1.1},
		"believer_attraction": {"halfling": 0.3, "human": 0.15},
		"compatible_with": ["aspect_of_nature", "aspect_of_trade"],
		"conflicts_with": ["aspect_of_war", "aspect_of_death"],
	},
	"aspect_of_knowledge": {
		"name": "Aspect of Knowledge", "domain": "arcana",
		"description": "Your scholarly aspect. Illuminates minds and reveals secrets.",
		"unlock_skill_requirement": "ancient_wisdom",
		"unlock_rank": 2,
		"mini_skills": [
			{"id": "know_library", "name": "Divine Library", "desc": "+30% research.", "cost": 1},
			{"id": "know_prophecy", "name": "Greater Prophecy", "desc": "See farther into the future.", "cost": 2},
			{"id": "know_inscription", "name": "Rune Inscription", "desc": "Enchant believing nation's equipment.", "cost": 3},
		],
		"aspect_miracles": ["inspire_crafter"],
		"passive_bonus": {"research": 1.3, "prophecy_range": 1},
		"believer_attraction": {"elf": 0.3, "dwarf": 0.2},
		"compatible_with": ["aspect_of_war", "aspect_of_trade"],
		"conflicts_with": ["aspect_of_death"],
	},
	"aspect_of_nature": {
		"name": "Aspect of Nature", "domain": "life",
		"description": "Your wild aspect. Commands beasts and forests.",
		"unlock_skill_requirement": "wild_growth",
		"unlock_rank": 2,
		"mini_skills": [
			{"id": "nature_beasts", "name": "Beastmaster", "desc": "Wild animals defend believers.", "cost": 1},
			{"id": "nature_grove", "name": "Sacred Grove", "desc": "Plant sacred forest. +20% forest production.", "cost": 2},
			{"id": "nature_ent", "name": "Awaken Ent", "desc": "Tree ents fight for believers.", "cost": 3},
		],
		"aspect_miracles": ["healing_rain"],
		"passive_bonus": {"forest_production": 1.3, "defense": 1.1},
		"believer_attraction": {"elf": 0.35, "halfling": 0.15},
		"compatible_with": ["aspect_of_harvest"],
		"conflicts_with": ["aspect_of_war", "aspect_of_forge"],
	},
	"aspect_of_trade": {
		"name": "Aspect of Trade", "domain": "commerce",
		"description": "Your mercantile aspect. Blesses markets and caravans.",
		"unlock_skill_requirement": "caravan_master",
		"unlock_rank": 2,
		"mini_skills": [
			{"id": "trade_coin", "name": "Golden Touch", "desc": "+20% gold from trade.", "cost": 1},
			{"id": "trade_silk", "name": "Silk Road", "desc": "Trade routes extend farther.", "cost": 2},
			{"id": "trade_monopoly", "name": "Divine Monopoly", "desc": "Nations trading with you pay tribute.", "cost": 3},
		],
		"aspect_miracles": ["inspire_crafter"],
		"passive_bonus": {"trade_income": 1.25, "gold": 1.15},
		"believer_attraction": {"halfling": 0.3, "human": 0.2},
		"compatible_with": ["aspect_of_harvest", "aspect_of_knowledge"],
		"conflicts_with": ["aspect_of_war"],
	},
	"aspect_of_death": {
		"name": "Aspect of Death", "domain": "destruction",
		"description": "Your fearsome aspect. Commands the dead and dying.",
		"unlock_skill_requirement": "raise_skeleton",
		"unlock_rank": 3,
		"mini_skills": [
			{"id": "death_wither", "name": "Withering Touch", "desc": "Enemy crops fail. -30% enemy food.", "cost": 2},
			{"id": "death_shadow", "name": "Shadow Walk", "desc": "Prophets travel unseen.", "cost": 2},
			{"id": "death_lichdom", "name": "Path to Lichdom", "desc": "Your prophets can become immortal liches.", "cost": 4},
		],
		"aspect_miracles": ["smite_invaders"],
		"passive_bonus": {"fear": 0.5, "undead_strength": 1.2},
		"believer_attraction": {"goblin": 0.4, "orc": 0.2},
		"compatible_with": ["aspect_of_war"],
		"conflicts_with": ["aspect_of_nature", "aspect_of_harvest", "aspect_of_knowledge"],
	},
	"aspect_of_forge": {
		"name": "Aspect of Forge", "domain": "industry",
		"description": "Your crafting aspect. Empowers smiths and builders.",
		"unlock_skill_requirement": "master_smiths",
		"unlock_rank": 2,
		"mini_skills": [
			{"id": "forge_fire", "name": "Eternal Flame", "desc": "Forges never go cold. +25% metal.", "cost": 1},
			{"id": "forge_wall", "name": "Fortress Builder", "desc": "+30% defense construction speed.", "cost": 2},
			{"id": "forge_golem", "name": "War Golems", "desc": "Build golem defenders.", "cost": 3},
		],
		"aspect_miracles": ["inspire_crafter"],
		"passive_bonus": {"metal": 1.25, "stone": 1.2},
		"believer_attraction": {"dwarf": 0.35, "human": 0.1},
		"compatible_with": ["aspect_of_war"],
		"conflicts_with": ["aspect_of_nature"],
	},
}

# Runtime aspect state
var active_aspects: Array[String] = []
var aspect_power_allocation: Dictionary = {}  # {aspect_id: percentage (0.0-1.0)}
var max_aspects: int = 1  # Base: 1 aspect can be active

# Player's selected class
var deity_class: String = ""
# Skill points to spend
var skill_points: int = 0
# Unlocked skill IDs
var unlocked_skills: Array[String] = []

# =============================================================================
# DYNAMIC STATE
# =============================================================================

var divine_power: float = 10.0
var max_divine_power: float = 50.0
var rank: int = 1

var all_miracles: Dictionary = {
	"bless_harvest": {
		"name": "Bless Harvest", "desc": "Instantly produce extra food.", "cost": 5, "unlock_rank": 1, "category": "bounty",
	},
	"inspire_crafter": {
		"name": "Inspire Crafter", "desc": "Double crafting output for a season.", "cost": 8, "unlock_rank": 1, "category": "industry",
	},
	"fortify_defenses": {
		"name": "Fortify Defenses", "desc": "Divine shield on walls. +20 defense.", "cost": 12, "unlock_rank": 1, "category": "war",
	},
	"healing_rain": {
		"name": "Healing Rain", "desc": "Heal all believers. Cures plagues.", "cost": 10, "unlock_rank": 2, "category": "life",
	},
	"smite_invaders": {
		"name": "Smite Invaders", "desc": "Destroy enemy armies with divine fire.", "cost": 20, "unlock_rank": 3, "category": "war",
	},
	"golden_age": {
		"name": "Golden Age", "desc": "All yields doubled. Morale soars.", "cost": 30, "unlock_rank": 3, "category": "bounty",
	},
	"earthquake": {
		"name": "Earthquake", "desc": "Shatter the earth under enemies.", "cost": 35, "unlock_rank": 4, "category": "destruction",
	},
}

var _active_effects: Array[Dictionary] = []

func _ready() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)

# =============================================================================
# CLASS SELECTION
# =============================================================================

func select_class(class_id: String) -> bool:
	if not DEITY_CLASSES.has(class_id):
		return false
	deity_class = class_id
	unlocked_skills.clear()
	skill_points = 3  # Starting skill points
	for m_id in DEITY_CLASSES[class_id]["starting_miracles"]:
		if all_miracles.has(m_id):
			pass  # Already there, just tracking
	print("[DeityManager] Class selected: %s" % DEITY_CLASSES[class_id]["name"])
	EventBus.deity_class_selected.emit(class_id)
	return true

# =============================================================================
# ASPECT MANAGEMENT
# =============================================================================

func unlock_aspect(aspect_id: String) -> bool:
	if not ASPECTS.has(aspect_id):
		return false

	var aspect_data: Dictionary = ASPECTS[aspect_id]

	if rank < aspect_data["unlock_rank"]:
		return false

	var required_skill: String = aspect_data["unlock_skill_requirement"]
	if required_skill not in unlocked_skills:
		return false

	if aspect_id in active_aspects:
		return false

	if active_aspects.size() >= max_aspects:
		return false

	# Conflict check — both directions
	for active_id in active_aspects:
		if aspect_id in ASPECTS[active_id].get("conflicts_with", []):
			return false
		if active_id in aspect_data.get("conflicts_with", []):
			return false

	active_aspects.append(aspect_id)
	aspect_power_allocation[aspect_id] = 1.0 / max_aspects
	EventBus.aspect_unlocked.emit(aspect_id)
	print("[DeityManager] Aspect unlocked: %s" % ASPECTS[aspect_id]["name"])
	return true


func allocate_power(aspect_id: String, percentage: float) -> bool:
	percentage = clamp(percentage, 0.0, 1.0)

	if aspect_id not in active_aspects:
		return false

	aspect_power_allocation[aspect_id] = percentage
	EventBus.aspect_power_allocated.emit(aspect_id, percentage)
	print("[DeityManager] Power allocated to %s: %.0f%%" % [ASPECTS[aspect_id]["name"], percentage * 100])
	return true


func get_aspect_bonus(aspect_id: String) -> Dictionary:
	if aspect_id not in active_aspects:
		return {}
	return ASPECTS[aspect_id].get("passive_bonus", {}).duplicate()


func get_total_aspect_bonuses() -> Dictionary:
	var result: Dictionary = {}

	if active_aspects.is_empty():
		return result

	var total_power: float = 0.0
	for aspect_id in active_aspects:
		total_power += aspect_power_allocation.get(aspect_id, 0.0)

	if total_power <= 0.0:
		return result

	for aspect_id in active_aspects:
		var weight: float = aspect_power_allocation.get(aspect_id, 0.0) / total_power
		var bonuses: Dictionary = ASPECTS[aspect_id].get("passive_bonus", {})
		for key in bonuses:
			result[key] = result.get(key, 0.0) + bonuses[key] * weight

	return result


func check_aspect_conflicts() -> Array[Dictionary]:
	var conflicts: Array[Dictionary] = []

	for i in range(active_aspects.size()):
		for j in range(i + 1, active_aspects.size()):
			var a: String = active_aspects[i]
			var b: String = active_aspects[j]

			var a_conflicts_b: bool = b in ASPECTS[a].get("conflicts_with", [])
			var b_conflicts_a: bool = a in ASPECTS[b].get("conflicts_with", [])

			if a_conflicts_b and b_conflicts_a:
				conflicts.append({"aspect_a": a, "aspect_b": b, "conflict_type": "mutual"})
			elif a_conflicts_b:
				conflicts.append({"aspect_a": a, "aspect_b": b, "conflict_type": "one_way"})
			elif b_conflicts_a:
				conflicts.append({"aspect_a": b, "aspect_b": a, "conflict_type": "one_way"})

	return conflicts


func can_unlock_aspect(aspect_id: String) -> bool:
	if not ASPECTS.has(aspect_id):
		return false

	var aspect_data: Dictionary = ASPECTS[aspect_id]

	if rank < aspect_data["unlock_rank"]:
		return false

	var required_skill: String = aspect_data["unlock_skill_requirement"]
	if required_skill not in unlocked_skills:
		return false

	if aspect_id in active_aspects:
		return false

	if active_aspects.size() >= max_aspects:
		return false

	for active_id in active_aspects:
		if aspect_id in ASPECTS[active_id].get("conflicts_with", []):
			return false
		if active_id in aspect_data.get("conflicts_with", []):
			return false

	return true


func get_aspect_skill_tree(aspect_id: String) -> Dictionary:
	if aspect_id not in active_aspects:
		return {}

	var mini_skills: Array = ASPECTS[aspect_id].get("mini_skills", [])
	if mini_skills.is_empty():
		return {}

	# Group into tiers (2 skills per tier) for UI compatibility
	var tree: Dictionary = {}
	for i in range(mini_skills.size()):
		var tier_index: int = i / 2
		var tier_key: String = "tier%d" % (tier_index + 1)
		if not tree.has(tier_key):
			tree[tier_key] = []
		tree[tier_key].append(mini_skills[i])

	return tree

# =============================================================================
# SKILL TREE
# =============================================================================

func get_skill_tree() -> Dictionary:
	if deity_class.is_empty():
		return {}
	return DEITY_CLASSES[deity_class]["skill_tree"]

func can_unlock_skill(skill_id: String) -> bool:
	var tree = get_skill_tree()
	if tree.is_empty():
		return false

	var skill_data: Dictionary = {}
	for tier in tree:
		for skill in tree[tier]:
			if skill["id"] == skill_id:
				skill_data = skill
				break

	if skill_data.is_empty():
		return false
	if skill_id in unlocked_skills:
		return false
	if skill_points < skill_data["cost"]:
		return false
	for req in skill_data["requires"]:
		if req not in unlocked_skills:
			return false
	return true

func unlock_skill(skill_id: String) -> bool:
	if not can_unlock_skill(skill_id):
		return false

	var cost = 0
	var tree = get_skill_tree()
	for tier in tree:
		for skill in tree[tier]:
			if skill["id"] == skill_id:
				cost = skill["cost"]
				break

	skill_points -= cost
	unlocked_skills.append(skill_id)
	EventBus.skill_unlocked.emit(skill_id)
	print("[DeityManager] Skill unlocked: %s" % skill_id)
	return true

func get_available_skills() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var tree = get_skill_tree()
	for tier in tree:
		for skill in tree[tier]:
			skill["tier"] = tier
			skill["unlockable"] = can_unlock_skill(skill["id"])
			skill["unlocked"] = skill["id"] in unlocked_skills
			result.append(skill.duplicate())
	return result

func gain_skill_point() -> void:
	skill_points += 1
	EventBus.divine_power_changed.emit(divine_power, max_divine_power)
	print("[DeityManager] Gained skill point. Total: %d" % skill_points)

# =============================================================================
# MIRACLE CASTING
# =============================================================================

func get_available_miracles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in all_miracles:
		var m = all_miracles[id]
		if m["unlock_rank"] <= rank:
			result.append(m.duplicate())
	return result

func get_locked_miracles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in all_miracles:
		var m = all_miracles[id]
		if m["unlock_rank"] > rank:
			result.append(m.duplicate())
	return result

func cast_miracle(miracle_id: String, target: Variant = null) -> bool:
	if not all_miracles.has(miracle_id):
		return false
	var miracle = all_miracles[miracle_id]
	if miracle["unlock_rank"] > rank:
		return false
	if divine_power < miracle["cost"]:
		return false

	divine_power -= miracle["cost"]
	_apply_miracle_gameplay_effects(miracle_id, target)
	EventBus.miracle_cast.emit(miracle_id, target)
	EventBus.divine_power_changed.emit(divine_power, max_divine_power)
	return true


func _apply_miracle_gameplay_effects(miracle_id: String, target: Variant) -> void:
	match miracle_id:
		"bless_harvest":
			# Instantly produce extra food in believing nations
			for nation in ColonyData.nations:
				if _nation_has_belief(nation["id"]):
					nation["resources"]["food"] += 30.0
			print("[DeityManager] Bless Harvest — +30 food to all believing nations")

		"inspire_crafter":
			# Double crafting output for a season (temporary production boost)
			_active_effects.append({"effect": {"production": 1.0, "crafting_speed": 1.0}, "remaining": 15})
			print("[DeityManager] Inspire Crafter — double production for 15 ticks")

		"fortify_defenses":
			# Divine shield on walls — +50% defense for believers
			_active_effects.append({"effect": {"defense": 0.5}, "remaining": 25})
			print("[DeityManager] Fortify Defenses — +50% defense for 25 ticks")

		"healing_rain":
			# Heal all believers — restore population, cure effects
			for nation in ColonyData.nations:
				if _nation_has_belief(nation["id"]):
					# Restore 5% of max pop capacity worth of population
					var restored = int(float(nation["population"]) * 0.05)
					nation["population"] += max(1, restored)
					# Clear any negative effects (morale restoration)
					nation["resources"]["food"] += 10.0
			print("[DeityManager] Healing Rain — believers healed and restored")

		"smite_invaders":
			# Destroy enemy armies with divine fire — hits non-believing nations hard
			for nation in ColonyData.nations:
				if not _nation_has_belief(nation["id"]):
					var damage = int(float(nation["military_strength"]) * 0.35)
					nation["military_strength"] = max(1, nation["military_strength"] - damage)
					print("[DeityManager] Smite Invaders — %s lost %d military" % [nation["name"], damage])

		"golden_age":
			# All yields boosted massively — morale soars
			_active_effects.append({"effect": {
				"production": 1.0,
				"food_production": 1.0,
				"trade_income": 1.0,
				"growth": 0.5,
			}, "remaining": 20})
			print("[DeityManager] Golden Age — all yields doubled for 20 ticks!")

		"earthquake":
			# Shatter the earth under enemies — damages military and stone resources
			for nation in ColonyData.nations:
				if not _nation_has_belief(nation["id"]):
					var mil_damage = int(float(nation["military_strength"]) * 0.40)
					nation["military_strength"] = max(1, nation["military_strength"] - mil_damage)
					nation["resources"]["stone"] = max(0.0, nation["resources"]["stone"] * 0.5)
					nation["resources"]["metal"] = max(0.0, nation["resources"]["metal"] * 0.7)
					print("[DeityManager] Earthquake — %s shattered: -%d military, stone & metal halved" % [nation["name"], mil_damage])


func _nation_has_belief(nation_id: int) -> bool:
	for race_id in ColonyData.RACES:
		if ColonyData.get_belief(nation_id, race_id) > 0.05:
			return true
	return false

# =============================================================================
# POWER & RANK
# =============================================================================

func _on_tick_advanced(_tick: int, _day: int, _season: String, _year: int) -> void:
	divine_power = min(divine_power + _calculate_power_regen(), max_divine_power)

	var total_believers = _count_total_believers()
	var new_rank = calculate_rank(total_believers)
	if new_rank > rank:
		rank = new_rank
		max_divine_power = 50.0 * rank
		for id in all_miracles:
			if all_miracles[id]["unlock_rank"] == rank:
				EventBus.power_unlocked.emit(id)
		gain_skill_point()

	EventBus.divine_power_changed.emit(divine_power, max_divine_power)

	# Tick down temporary effects
	var expired: Array[int] = []
	for i in range(_active_effects.size()):
		_active_effects[i]["remaining"] -= 1
		if _active_effects[i]["remaining"] <= 0:
			expired.append(i)
	for i in expired:
		_active_effects.remove_at(i)

func _calculate_power_regen() -> float:
	var total_believers = _count_total_believers()
	var base_regen = total_believers * 0.001

	# Multi-race synergy bonus
	var race_count = 0
	for nation_id in ColonyData.belief_by_nation:
		for race_id in ColonyData.belief_by_nation[nation_id]:
			if ColonyData.belief_by_nation[nation_id][race_id] > 0.1:
				race_count += 1
	var synergy_mult = 1.0 + (race_count - 1) * 0.15  # +15% per additional race believing

	return base_regen * synergy_mult

func _count_total_believers() -> int:
	var total = 0
	for nation in ColonyData.nations:
		for race_id in nation.get("race_demographics", {}):
			var pop_share = nation.get("race_demographics", {})[race_id]
			var pop_of_race = int(nation["population"] * pop_share)
			var belief = ColonyData.get_belief(nation["id"], race_id)
			total += int(pop_of_race * belief)
	return total

func calculate_rank(believers: int) -> int:
	if believers < 50:    return 1  # Local Spirit
	elif believers < 150: return 2  # Minor Deity
	elif believers < 500: return 3  # Regional Deity
	elif believers < 1500: return 4  # Major Deity
	else:                 return 5  # Supreme Deity

func get_class_passive_bonus() -> Dictionary:
	var result: Dictionary = {}
	if not deity_class.is_empty():
		result = DEITY_CLASSES[deity_class].get("passive_bonus", {}).duplicate()
	# Merge aspect bonuses — aspect overrides class passive for matching keys
	var aspect_bonuses = get_total_aspect_bonuses()
	for key in aspect_bonuses:
		result[key] = aspect_bonuses[key]
	return result

func get_active_effects() -> Dictionary:
	var result: Dictionary = {}
	for ae in _active_effects:
		for key in ae["effect"]:
			result[key] = result.get(key, 0.0) + ae["effect"][key]
	return result


# Map skill IDs to their numeric gameplay effects (multiplier values)
const SKILL_EFFECTS: Dictionary = {
	# Forge Lord
	"master_smiths": {"metal": 1.2},
	"deep_mining": {"metal": 1.4, "stone": 1.4},
	"living_metal": {"military_power": 1.3},
	# Nature Warden
	"bountiful_harvest": {"food_production": 1.25},
	# Trade Lord
	"caravan_master": {"trade_income": 1.3},
	"golden_roads": {"trade_income": 1.2},
	# Knowledge Keeper
	"ancient_wisdom": {"research_speed": 1.25},
	"ley_lines": {"miracle_power": 1.5},
}


func get_effective_bonus(key: String) -> float:
	var total = 1.0

	# Class passive bonus (base only, without aspect merge)
	if not deity_class.is_empty():
		var class_passive: Dictionary = DEITY_CLASSES[deity_class].get("passive_bonus", {})
		if class_passive.has(key):
			total *= class_passive[key]

	# Skill bonuses from unlocked skills
	for skill_id in unlocked_skills:
		if SKILL_EFFECTS.has(skill_id):
			var effects: Dictionary = SKILL_EFFECTS[skill_id]
			if effects.has(key):
				total *= effects[key]

	# Active temporary effect bonuses
	var active_effects = get_active_effects()
	if active_effects.has(key):
		total *= (1.0 + active_effects[key])

	# Aspect bonus contribution (weighted by power allocation)
	var aspect_bonuses = get_total_aspect_bonuses()
	if aspect_bonuses.has(key):
		total *= aspect_bonuses[key]

	return total
