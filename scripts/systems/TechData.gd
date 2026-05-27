class_name TechData
extends RefCounted

# =============================================================================
# TECH TREES - 5 eras: stone → bronze → iron → steel → arcane
# =============================================================================

const TECH_TREES: Dictionary = {
	"stone": [
		{"id": "basic_weapons", "name": "Basic Weapons", "desc": "+10% military strength. Unlocks militia policy.", "cost": 5, "requires": [], "unlocks_military": 0.10},
		{"id": "basic_farming", "name": "Basic Farming", "desc": "+15% food production.", "cost": 5, "requires": [], "unlocks_food": 0.15},
		{"id": "tribal_crafting", "name": "Tribal Crafting", "desc": "+10% production.", "cost": 5, "requires": [], "unlocks_production": 0.10},
	],
	"bronze": [
		{"id": "bronze_weapons", "name": "Bronze Weapons", "desc": "+20% military.", "cost": 15, "requires": ["basic_weapons"], "unlocks_military": 0.20},
		{"id": "pottery", "name": "Pottery", "desc": "+20% food capacity.", "cost": 15, "requires": ["basic_farming"], "unlocks_food_capacity": 0.20},
		{"id": "masonry", "name": "Masonry", "desc": "Unlocks quarry (tier 2). +15% stone/metal.", "cost": 15, "requires": ["tribal_crafting"], "unlocks_stone": 0.15, "unlocks_metal": 0.15},
	],
	"iron": [
		{"id": "iron_weapons", "name": "Iron Weapons", "desc": "+30% military.", "cost": 30, "requires": ["bronze_weapons"], "unlocks_military": 0.30},
		{"id": "writing", "name": "Writing", "desc": "+25% research speed.", "cost": 30, "requires": ["basic_farming"], "unlocks_research": 0.25},
		{"id": "fortifications", "name": "Fortifications", "desc": "+20% defense.", "cost": 30, "requires": ["masonry"], "unlocks_defense": 0.20},
		{"id": "coinage", "name": "Coinage", "desc": "+15% trade +10% gold.", "cost": 30, "requires": ["tribal_crafting"], "unlocks_trade": 0.15, "unlocks_gold": 0.10},
	],
	"steel": [
		{"id": "steel_weapons", "name": "Steel Weapons", "desc": "+40% military.", "cost": 50, "requires": ["iron_weapons"], "unlocks_military": 0.40},
		{"id": "architecture", "name": "Architecture", "desc": "Unlocks building upgrades (tier 3).", "cost": 50, "requires": ["masonry", "fortifications"], "unlocks_building_tier": 3},
		{"id": "navigation", "name": "Navigation", "desc": "+25% trade range. Unlocks harbor.", "cost": 50, "requires": ["coinage"], "unlocks_trade": 0.25},
	],
	"arcane": [
		{"id": "enchanting", "name": "Enchanting", "desc": "+20% all production. Arcane bonus.", "cost": 80, "requires": ["steel_weapons", "writing"], "unlocks_production": 0.20, "unlocks_arcane": 0.3},
		{"id": "gunpowder", "name": "Gunpowder", "desc": "+60% military. Unlocks conscription.", "cost": 80, "requires": ["steel_weapons", "fortifications"], "unlocks_military": 0.60},
	],
}

const ERA_THRESHOLDS: Dictionary = {
	"stone": 0,
	"bronze": 3,
	"iron": 5,
	"steel": 7,
	"arcane": 10,
}

const ERAS: Array = ["stone", "bronze", "iron", "steel", "arcane"]

const RACE_TECH_AFFINITY: Dictionary = {
	"dwarf": 1.3, "gnome": 1.25, "elf": 1.2, "human": 1.0,
	"orc": 0.8, "goblin": 0.7, "troll": 0.5, "ogre": 0.4, "halfling": 0.9,
}

# =============================================================================
# LOOKUP
# =============================================================================

static func get_tech(tech_id: String) -> Dictionary:
	for era in TECH_TREES:
		for tech in TECH_TREES[era]:
			if tech["id"] == tech_id:
				return tech.duplicate()
	return {}
