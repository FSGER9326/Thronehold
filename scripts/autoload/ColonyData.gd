extends Node

# =============================================================================
# RACES - Rich trait system with playstyles, terrain adaptations, and influence channels
# =============================================================================

const RACES: Dictionary = {
	"human": {
		"name": "Human",
		"description": "Adaptable and ambitious. Humans thrive through diplomacy, trade, and rapid expansion.",
		"playstyle": "balanced",
		"traits": {
			"fertility": 1.3, "strength": 1.0, "intelligence": 1.0,
			"longevity": 60, "piety": 1.0, "stubbornness": 0.5, "adaptability": 1.5,
			"drift_rate": 0.03,
		},
		"preferred_biomes": ["plains", "hills", "forest"],
		"terrain_bonuses": {"plains": 1.2, "hills": 1.1},
		"cultural_tendencies": ["diplomatic", "adaptive", "ambitious"],
		"influence_channel": "priesthood",  # How deity reaches this race
		"influence_difficulty": 0.8,  # Multiplier: lower = easier to influence
		"faith_per_pop": 1.0,  # How much belief each pop generates
		"name_pool": {
			"male": ["Aldric", "Cedric", "Darian", "Edmund", "Gareth", "Harold", "Lionel", "Marcus", "Percival", "Roland"],
			"female": ["Aelina", "Bridget", "Catherine", "Eleanor", "Gwendolyn", "Isabella", "Lianna", "Margret", "Rosalind", "Theresa"],
		},
		"genetics": {
			"adaptability_gene": {"trait": "adaptability", "dominance": "dominant", "value": 1.5},
			"fertility_gene": {"trait": "fertility", "dominance": "dominant", "value": 1.3},
			"strength_gene": {"trait": "strength", "dominance": "recessive", "value": 1.0},
			"intelligence_gene": {"trait": "intelligence", "dominance": "recessive", "value": 1.0},
			"longevity_gene": {"trait": "longevity", "dominance": "recessive", "value": 60.0},
			"piety_gene": {"trait": "piety", "dominance": "recessive", "value": 1.0},
			"stubbornness_gene": {"trait": "stubbornness", "dominance": "recessive", "value": 0.5},
		},
		"strategy_affinity": {"mine": 0.6, "trade": 0.9, "raid": 0.5, "expand": 0.8},
		"interbreeding_tendency": 0.8,
		"hybrid_name": "Half-Human",
		"hybrid_traits": {},
	},
	"dwarf": {
		"name": "Dwarf",
		"description": "Master crafters and miners. Dwarves build impregnable fortresses and forge legendary goods.",
		"playstyle": "fortress_builder",
		"traits": {
			"fertility": 0.5, "strength": 1.4, "intelligence": 1.2,
			"longevity": 200, "piety": 0.7, "stubbornness": 1.8, "adaptability": 0.3,
			"drift_rate": 0.01,
		},
		"preferred_biomes": ["mountain", "hills", "caves"],
		"terrain_bonuses": {"mountain": 1.5, "caves": 1.4, "hills": 1.2},
		"cultural_tendencies": ["traditional", "industrious", "stubborn"],
		"influence_channel": "clan_chief",
		"influence_difficulty": 1.4,
		"faith_per_pop": 0.8,
		"economic_bonuses": {"metal": 1.5, "stone": 1.5, "gems": 2.0},
		"name_pool": {
			"male": ["Balin", "Durin", "Farin", "Gimli", "Kazak", "Orin", "Thorin", "Ulfgar", "Vordin", "Zarkan"],
			"female": ["Beryla", "Dagna", "Freyja", "Gilda", "Helga", "Kazra", "Orna", "Sigrid", "Thora", "Yrsa"],
		},
		"genetics": {
			"strength_gene": {"trait": "strength", "dominance": "dominant", "value": 1.4},
			"stubbornness_gene": {"trait": "stubbornness", "dominance": "dominant", "value": 1.8},
			"craftsmanship_gene": {"trait": "intelligence", "dominance": "dominant", "value": 1.2},
			"fertility_gene": {"trait": "fertility", "dominance": "recessive", "value": 0.5},
			"adaptability_gene": {"trait": "adaptability", "dominance": "recessive", "value": 0.3},
			"longevity_gene": {"trait": "longevity", "dominance": "recessive", "value": 200.0},
		},
		"strategy_affinity": {"mine": 1.0, "trade": 0.5, "raid": 0.3, "expand": 0.5},
		"interbreeding_tendency": 0.3,
		"hybrid_name": "Half-Dwarf",
		"hybrid_traits": {},
	},
	"elf": {
		"name": "Elf",
		"description": "Ancient and mystical. Elves wield subtle power through magic, wisdom, and immortal patience.",
		"playstyle": "arcane_mystic",
		"traits": {
			"fertility": 0.3, "strength": 0.7, "intelligence": 1.6,
			"longevity": 500, "piety": 1.4, "stubbornness": 1.2, "adaptability": 0.5,
			"drift_rate": 0.005,
		},
		"preferred_biomes": ["forest", "plains"],
		"terrain_bonuses": {"forest": 1.6, "plains": 1.0},
		"cultural_tendencies": ["mystical", "conservationist", "arcane"],
		"influence_channel": "high_council",
		"influence_difficulty": 1.0,
		"faith_per_pop": 1.3,
		"arcane_power": 1.5,
		"name_pool": {
			"male": ["Aelar", "Caelynn", "Eldrin", "Faelan", "Ithil", "Laeron", "Orophin", "Thranduil", "Valandil", "Zephyr"],
			"female": ["Aeris", "Celebrian", "Elara", "Illyria", "Luthien", "Nimue", "Sylvara", "Titania", "Vanya", "Ysandra"],
		},
		"genetics": {
			"intelligence_gene": {"trait": "intelligence", "dominance": "dominant", "value": 1.6},
			"longevity_gene": {"trait": "longevity", "dominance": "dominant", "value": 500.0},
			"piety_gene": {"trait": "piety", "dominance": "dominant", "value": 1.4},
			"fertility_gene": {"trait": "fertility", "dominance": "recessive", "value": 0.3},
			"strength_gene": {"trait": "strength", "dominance": "recessive", "value": 0.7},
			"adaptability_gene": {"trait": "adaptability", "dominance": "recessive", "value": 0.5},
		},
		"strategy_affinity": {"mine": 0.5, "trade": 0.7, "raid": 0.2, "expand": 0.3},
		"interbreeding_tendency": 0.2,
		"hybrid_name": "Half-Elf",
		"hybrid_traits": {},
	},
	"orc": {
		"name": "Orc",
		"description": "Brutal and fierce. Orcs dominate through strength, conquest, and overwhelming numbers.",
		"playstyle": "warmonger",
		"traits": {
			"fertility": 1.6, "strength": 1.6, "intelligence": 0.6,
			"longevity": 45, "piety": 0.6, "stubbornness": 1.0, "adaptability": 1.2,
			"drift_rate": 0.04,
		},
		"preferred_biomes": ["plains", "hills", "swamp"],
		"terrain_bonuses": {"plains": 1.2, "hills": 1.1, "swamp": 1.0},
		"cultural_tendencies": ["warlike", "tribal", "might_makes_right"],
		"influence_channel": "warchief",
		"influence_difficulty": 0.6,  # Easy to influence through shows of strength
		"faith_per_pop": 0.5,
		"military_bonus": 1.5,
		"name_pool": {
			"male": ["Gorak", "Karn", "Morg", "Rukhar", "Thokk", "Ugruk", "Varg", "Zarn", "Drakk", "Krull"],
			"female": ["Azgra", "Borga", "Gnasha", "Karga", "Morga", "Rukha", "Shaga", "Urza", "Vasha", "Zarna"],
		},
		"genetics": {
			"strength_gene": {"trait": "strength", "dominance": "dominant", "value": 1.6},
			"fertility_gene": {"trait": "fertility", "dominance": "dominant", "value": 1.6},
			"adaptability_gene": {"trait": "adaptability", "dominance": "dominant", "value": 1.2},
			"intelligence_gene": {"trait": "intelligence", "dominance": "recessive", "value": 0.6},
			"piety_gene": {"trait": "piety", "dominance": "recessive", "value": 0.6},
			"longevity_gene": {"trait": "longevity", "dominance": "recessive", "value": 45.0},
		},
		"strategy_affinity": {"mine": 0.4, "trade": 0.3, "raid": 0.9, "expand": 0.7},
		"interbreeding_tendency": 0.4,
		"hybrid_name": "Half-Orc",
		"hybrid_traits": {},
	},
	"halfling": {
		"name": "Halfling",
		"description": "Clever and cheerful. Halflings prosper through trade, farming, and staying out of trouble.",
		"playstyle": "trader",
		"traits": {
			"fertility": 1.2, "strength": 0.5, "intelligence": 1.1,
			"longevity": 100, "piety": 1.0, "stubbornness": 0.4, "adaptability": 1.4,
			"drift_rate": 0.03,
		},
		"preferred_biomes": ["plains", "hills"],
		"terrain_bonuses": {"plains": 1.4, "hills": 1.1},
		"cultural_tendencies": ["peaceful", "community", "clever"],
		"influence_channel": "community_elders",
		"influence_difficulty": 0.5,  # Very easy — community consensus
		"faith_per_pop": 1.1,
		"economic_bonuses": {"food": 1.5, "trade": 2.0},
		"name_pool": {
			"male": ["Bilbo", "Corbin", "Finn", "Hamfast", "Largo", "Milo", "Odo", "Peregrin", "Robin", "Tobold"],
			"female": ["Belladonna", "Camellia", "Daisy", "Elanor", "Lily", "Marigold", "Pearl", "Primula", "Rosie", "Willow"],
		},
		"genetics": {
			"adaptability_gene": {"trait": "adaptability", "dominance": "dominant", "value": 1.4},
			"fertility_gene": {"trait": "fertility", "dominance": "dominant", "value": 1.2},
			"intelligence_gene": {"trait": "intelligence", "dominance": "dominant", "value": 1.1},
			"strength_gene": {"trait": "strength", "dominance": "recessive", "value": 0.5},
			"longevity_gene": {"trait": "longevity", "dominance": "recessive", "value": 100.0},
			"piety_gene": {"trait": "piety", "dominance": "recessive", "value": 1.0},
		},
		"strategy_affinity": {"mine": 0.4, "trade": 0.9, "raid": 0.1, "expand": 0.6},
		"interbreeding_tendency": 0.7,
		"hybrid_name": "Half-Halfling",
		"hybrid_traits": {},
	},
	"goblin": {
		"name": "Goblin",
		"description": "Cunning and numerous. Goblins overwhelm through sheer numbers, traps, and dirty tricks.",
		"playstyle": "swarm",
		"traits": {
			"fertility": 2.2, "strength": 0.4, "intelligence": 0.8,
			"longevity": 30, "piety": 0.4, "stubbornness": 0.3, "adaptability": 1.8,
			"drift_rate": 0.06,
		},
		"preferred_biomes": ["caves", "swamp", "mountain"],
		"terrain_bonuses": {"caves": 1.5, "swamp": 1.3, "mountain": 1.1},
		"cultural_tendencies": ["cunning", "opportunistic", "explosive_growth"],
		"influence_channel": "tyrant",
		"influence_difficulty": 0.7,  # Easy but unreliable — fear-based
		"faith_per_pop": 0.3,
		"swarm_bonus": 2.0,  # Extra units per pop in military
		"name_pool": {
			"male": ["Grik", "Nibblet", "Retch", "Skiv", "Snik", "Squeak", "Titch", "Wart", "Zig", "Zog"],
			"female": ["Bree", "Gnasha", "Kree", "Rikta", "Snikka", "Spitta", "Tikka", "Vexa", "Yik", "Zikka"],
		},
		"genetics": {
			"fertility_gene": {"trait": "fertility", "dominance": "dominant", "value": 2.2},
			"adaptability_gene": {"trait": "adaptability", "dominance": "dominant", "value": 1.8},
			"cunning_gene": {"trait": "intelligence", "dominance": "dominant", "value": 0.8},
			"piety_gene": {"trait": "piety", "dominance": "recessive", "value": 0.4},
			"longevity_gene": {"trait": "longevity", "dominance": "recessive", "value": 30.0},
			"strength_gene": {"trait": "strength", "dominance": "recessive", "value": 0.4},
		},
		"strategy_affinity": {"mine": 0.7, "trade": 0.5, "raid": 0.8, "expand": 0.9},
		"interbreeding_tendency": 0.9,
		"hybrid_name": "Half-Goblin",
		"hybrid_traits": {},
	},
	"troll": {
		"name": "Troll",
		"description": "Dwelling in caves and swamps, trolls are monstrous brutes feared for their raw strength and regenerative vigor.",
		"playstyle": "brute",
		"traits": {
			"fertility": 1.0, "strength": 1.9, "intelligence": 0.3,
			"longevity": 80, "piety": 0.4, "stubbornness": 1.5, "adaptability": 0.5,
			"drift_rate": 0.02,
		},
		"preferred_biomes": ["caves", "swamp", "mountain"],
		"terrain_bonuses": {"caves": 1.5, "swamp": 1.3, "mountain": 1.1},
		"cultural_tendencies": ["warlike", "tribal", "might_makes_right"],
		"influence_channel": "shaman",
		"influence_difficulty": 0.9,
		"faith_per_pop": 0.4,
		"military_bonus": 1.8,
		"name_pool": {
			"male": ["Gronk", "Thud", "Krum", "Bog", "Grak"],
			"female": ["Morga", "Usha", "Bogra", "Krom"],
		},
		"genetics": {
			"strength_gene": {"trait": "strength", "dominance": "dominant", "value": 1.9},
			"stubbornness_gene": {"trait": "stubbornness", "dominance": "dominant", "value": 1.5},
			"fertility_gene": {"trait": "fertility", "dominance": "recessive", "value": 1.0},
			"longevity_gene": {"trait": "longevity", "dominance": "recessive", "value": 80.0},
			"piety_gene": {"trait": "piety", "dominance": "recessive", "value": 0.4},
			"intelligence_gene": {"trait": "intelligence", "dominance": "recessive", "value": 0.3},
			"adaptability_gene": {"trait": "adaptability", "dominance": "recessive", "value": 0.5},
		},
		"strategy_affinity": {"mine": 0.2, "trade": 0.1, "raid": 0.9, "expand": 0.4},
		"interbreeding_tendency": 0.3,
		"hybrid_name": "Half-Troll",
		"hybrid_traits": {},
	},
	"ogre": {
		"name": "Ogre",
		"description": "Towering behemoths of muscle and rage. Ogres live solitary lives in the high mountains, crushing anything that enters their domain.",
		"playstyle": "juggernaut",
		"traits": {
			"fertility": 0.3, "strength": 2.0, "intelligence": 0.2,
			"longevity": 100, "piety": 0.3, "stubbornness": 1.7, "adaptability": 0.3,
			"drift_rate": 0.01,
		},
		"preferred_biomes": ["mountain", "caves"],
		"terrain_bonuses": {"mountain": 1.6, "caves": 1.2},
		"cultural_tendencies": ["warlike", "might_makes_right"],
		"influence_channel": "tyrant",
		"influence_difficulty": 1.2,
		"faith_per_pop": 0.3,
		"military_bonus": 2.0,
		"name_pool": {
			"male": ["Grog", "Brog", "Mogg", "Thog", "Drok"],
			"female": ["Grasha", "Brogna", "Moga", "Thoga"],
		},
		"genetics": {
			"strength_gene": {"trait": "strength", "dominance": "dominant", "value": 2.0},
			"longevity_gene": {"trait": "longevity", "dominance": "dominant", "value": 100.0},
			"brutality_gene": {"trait": "strength", "dominance": "dominant", "value": 2.0},
			"fertility_gene": {"trait": "fertility", "dominance": "recessive", "value": 0.3},
			"intelligence_gene": {"trait": "intelligence", "dominance": "recessive", "value": 0.2},
			"piety_gene": {"trait": "piety", "dominance": "recessive", "value": 0.3},
			"adaptability_gene": {"trait": "adaptability", "dominance": "recessive", "value": 0.3},
		},
		"strategy_affinity": {"mine": 0.1, "trade": 0.0, "raid": 1.0, "expand": 0.2},
		"interbreeding_tendency": 0.2,
		"hybrid_name": "Half-Ogre",
		"hybrid_traits": {},
	},
	"gnome": {
		"name": "Gnome",
		"description": "Diminutive tinkerers and gem-hoarders. Gnomes build intricate underground workshops and excel at extracting wealth from the earth.",
		"playstyle": "artisan",
		"traits": {
			"fertility": 0.7, "strength": 0.4, "intelligence": 1.5,
			"longevity": 150, "piety": 1.2, "stubbornness": 0.6, "adaptability": 1.2,
			"drift_rate": 0.04,
		},
		"preferred_biomes": ["hills", "forest"],
		"terrain_bonuses": {"hills": 1.5, "forest": 1.2},
		"cultural_tendencies": ["scholarly", "mercantile", "clever"],
		"influence_channel": "community_elders",
		"influence_difficulty": 0.6,
		"faith_per_pop": 1.2,
		"military_bonus": 0.4,
		"economic_bonuses": {"gems": 1.5, "gold": 1.3},
		"name_pool": {
			"male": ["Fizz", "Bix", "Tink", "Gadget", "Cog"],
			"female": ["Gizmo", "Pixie", "Widget", "Spark"],
		},
		"genetics": {
			"intelligence_gene": {"trait": "intelligence", "dominance": "dominant", "value": 1.5},
			"fertility_gene": {"trait": "fertility", "dominance": "dominant", "value": 0.7},
			"adaptability_gene": {"trait": "adaptability", "dominance": "dominant", "value": 1.2},
			"strength_gene": {"trait": "strength", "dominance": "recessive", "value": 0.4},
			"longevity_gene": {"trait": "longevity", "dominance": "dominant", "value": 150.0},
			"piety_gene": {"trait": "piety", "dominance": "recessive", "value": 1.2},
		},
		"strategy_affinity": {"mine": 0.7, "trade": 0.6, "raid": 0.1, "expand": 0.3},
		"interbreeding_tendency": 0.6,
		"hybrid_name": "Half-Gnome",
		"hybrid_traits": {},
	},
}

# =============================================================================
# DIFFICULTY SETTINGS - Presets that affect game balance
# =============================================================================

const DIFFICULTY_SETTINGS: Dictionary = {
	"easy": {
		"ai_aggression": 0.6,
		"threat_scale": 0.5,   # World itself is less dangerous
		"research_rate": 1.3,
	},
	"normal": {
		"ai_aggression": 1.0,
		"threat_scale": 1.0,   # World IS the difficulty curve
		"research_rate": 1.0,
	},
	"hard": {
		"ai_aggression": 1.3,
		"threat_scale": 1.5,   # World hits twice as hard
		"research_rate": 0.7,
	},
}

# =============================================================================
# CHARACTER SYSTEM - Trait and archetype definitions
# =============================================================================

const LEADER_ARCHETYPES: Dictionary = {
	"warlord": {
		"name": "Warlord",
		"description": "Rules through strength and conquest.",
		"preferred_traits": ["aggressive", "brave", "ruthless", "charismatic"],
		"ai_behavior": "aggressive",
		"nation_effects": {"military_strength": 1.3, "diplomacy": 0.7},
		"influence_resistance_mod": 1.2,
	},
	"merchant_prince": {
		"name": "Merchant Prince",
		"description": "Rules through wealth and trade.",
		"preferred_traits": ["cunning", "generous", "ambitious", "calculating"],
		"ai_behavior": "trader",
		"nation_effects": {"income": 1.4, "military_strength": 0.6},
		"influence_resistance_mod": 0.8,
	},
	"high_priest": {
		"name": "High Priest",
		"description": "Rules through faith and divine mandate.",
		"preferred_traits": ["pious", "wise", "zealous", "charismatic"],
		"ai_behavior": "passive",
		"nation_effects": {"faith": 1.5, "military_strength": 0.8},
		"influence_resistance_mod": 0.5,  # Easy — already religious
	},
	"elder_council": {
		"name": "Elder Council",
		"description": "Collective rule by the wisest and oldest.",
		"preferred_traits": ["wise", "patient", "traditional", "cautious"],
		"ai_behavior": "isolationist",
		"nation_effects": {"stability": 1.4, "expansion": 0.5},
		"influence_resistance_mod": 1.0,
	},
	"chieftain": {
		"name": "Chieftain",
		"description": "Tribal rule based on personal strength and loyalty.",
		"preferred_traits": ["brave", "honorable", "ruthless", "stubborn"],
		"ai_behavior": "aggressive",
		"nation_effects": {"military_strength": 1.2, "stability": 0.9},
		"influence_resistance_mod": 1.1,
	},
	"tyrant": {
		"name": "Tyrant",
		"description": "Absolute rule through fear and oppression.",
		"preferred_traits": ["ruthless", "paranoid", "cunning", "ambitious"],
		"ai_behavior": "aggressive",
		"nation_effects": {"production": 1.3, "morale": 0.6},
		"influence_resistance_mod": 1.4,  # Hard — trust no one, not even gods
	},
	"philosopher_king": {
		"name": "Philosopher King",
		"description": "Rules through wisdom and enlightenment.",
		"preferred_traits": ["wise", "patient", "generous", "curious"],
		"ai_behavior": "passive",
		"nation_effects": {"research": 1.4, "diplomacy": 1.2},
		"influence_resistance_mod": 0.7,
	},
}

const CHARACTER_TRAITS: Dictionary = {
	"aggressive":    {"description": "Quick to anger and war.", "influence_mod": -0.2, "ai_mod": 0.3},
	"brave":         {"description": "Faces danger without flinching.", "influence_mod": 0.0, "ai_mod": 0.1},
	"ruthless":      {"description": "No mercy for enemies.", "influence_mod": -0.1, "ai_mod": 0.2},
	"charismatic":   {"description": "Natural leader of people.", "influence_mod": 0.2, "ai_mod": 0.0},
	"cunning":       {"description": "Sharp and scheming.", "influence_mod": -0.1, "ai_mod": 0.1},
	"generous":      {"description": "Gives freely to others.", "influence_mod": 0.1, "ai_mod": -0.1},
	"ambitious":     {"description": "Hungry for power and glory.", "influence_mod": -0.2, "ai_mod": 0.2},
	"calculating":   {"description": "Thinks many steps ahead.", "influence_mod": -0.1, "ai_mod": 0.0},
	"pious":         {"description": "Deeply devoted to the divine.", "influence_mod": 0.4, "ai_mod": -0.1},
	"wise":          {"description": "Deep understanding of the world.", "influence_mod": 0.1, "ai_mod": -0.1},
	"zealous":       {"description": "Fanatical in belief.", "influence_mod": 0.3, "ai_mod": 0.2},
	"patient":       {"description": "Willing to wait for the right moment.", "influence_mod": 0.0, "ai_mod": -0.2},
	"traditional":   {"description": "Values the old ways.", "influence_mod": -0.1, "ai_mod": -0.1},
	"cautious":      {"description": "Better safe than sorry.", "influence_mod": 0.0, "ai_mod": -0.3},
	"honorable":     {"description": "Lives by a strict code.", "influence_mod": 0.1, "ai_mod": 0.0},
	"stubborn":      {"description": "Never changes their mind.", "influence_mod": -0.3, "ai_mod": 0.0},
	"paranoid":      {"description": "Trusts no one.", "influence_mod": -0.4, "ai_mod": 0.1},
	"curious":       {"description": "Seeks new knowledge.", "influence_mod": 0.1, "ai_mod": 0.0},
	"lazy":           {"description": "Avoids work when possible.", "influence_mod": 0.1, "ai_mod": -0.4},
	"mad":           {"description": "Touched by madness — unpredictable.", "influence_mod": -0.5, "ai_mod": 0.5},
}

# =============================================================================
# INFLUENCE TYPES
# =============================================================================

const INFLUENCE_ACTIONS: Dictionary = {
	"divine_sign": {
		"name": "Divine Sign",
		"description": "A subtle omen — comet, eclipse, or strange weather.",
		"cost": 5.0,
		"cooldown_ticks": 10,
		"base_success": 0.8,
		"effect_strength": 0.3,  # Subtle shift
	},
	"dream_vision": {
		"name": "Dream Vision",
		"description": "Send a vision to the ruler's dreams.",
		"cost": 12.0,
		"cooldown_ticks": 25,
		"base_success": 0.65,
		"effect_strength": 0.6,
		"targets_leader": true,
	},
	"prophet_send": {
		"name": "Send Prophet",
		"description": "Dispatch a divine messenger to preach among the people.",
		"cost": 25.0,
		"cooldown_ticks": 60,
		"base_success": 0.9,
		"effect_strength": 1.0,
		"creates_prophet": true,
	},
	"miracle": {
		"name": "Great Miracle",
		"description": "An undeniable display of divine power.",
		"cost": 40.0,
		"cooldown_ticks": 100,
		"base_success": 1.0,
		"effect_strength": 2.0,
	},
}

# =============================================================================
# DIFFICULTY
# =============================================================================

var difficulty: String = "normal"

# =============================================================================
# PLAYER DEITY (identity only)
# =============================================================================

var deity_name: String = "The Unnamed"
var deity_domain: String = "Forge"

# =============================================================================
# TUTORIAL
# =============================================================================

var has_seen_tutorial: bool = false  # Persisted via SaveManager — resets only on fresh game

# =============================================================================
# PLAYER NATION
# =============================================================================

var player_nation_id: int = -1
var selected_race: String = "dwarf"  # Chosen in class selection screen, affects player nation

# =============================================================================
# WORLD
# =============================================================================

var world_width: int = 600
var world_height: int = 450
var world_tiles: Array[Dictionary] = []
var underground_tiles: Array[Dictionary] = []
var world_history: Dictionary = {}  # Populated by HistoryGenerator during world gen
var world_monsters: Array[Dictionary] = []  # Unique named monster lairs
var notification_log: Array[Dictionary] = []  # Ring buffer of event log entries
var visibility_grid: Array = []  # 0 = unexplored, 1 = explored (dim), 2 = visible (active)

# =============================================================================
# NATIONS
# =============================================================================

var nations: Array[Dictionary] = []
var active_factions: Array[Dictionary] = []
var trade_leagues: Array[Dictionary] = []
var diplomacy_matrix: Array[Array] = []
var independence_movements: Array[Dictionary] = []  # {vassal_id, suzerain_id, desire, started_tick}

# O(1) dict caches for hot-loop lookups
var _nation_by_id: Dictionary = {}
var _leader_by_nation: Dictionary = {}

# =============================================================================
# CHARACTERS
# =============================================================================
# characters: Array[Dictionary] of all generated characters (leaders, priests, prophets)
# Each dict: {id, name, race, gender, age, archetype, traits[], role, nation_id, alive}
var characters: Array[Dictionary] = []
var _next_character_id: int = 0

# =============================================================================
# BELIEF SYSTEM
# =============================================================================
# belief_by_nation[nation_id][race_id] = percentage (0.0-1.0) of that race that believes in player's deity
var belief_by_nation: Dictionary = {}  # {nation_id: {race_id: percentage}}

# =============================================================================
# ASPECT ATTRACTION
# =============================================================================
# {race_id: [preferred_aspect_ids]}
var aspect_attraction: Dictionary = {}  # Built at runtime from DeityManager.ASPECTS

# =============================================================================
# CULTURAL TRAITS
# =============================================================================
var nation_culture: Dictionary = {}  # {nation_id: {trait_id: dominance (0.0-1.0)}}
var cultural_drift_rates: Dictionary = {}  # {race_id: base_drift_rate}

# =============================================================================
# PROPHETS
# =============================================================================
var prophets: Array[Dictionary] = []  # Active prophets in the world
var artifacts: Array[Dictionary] = []  # Legendary items created during gameplay

# =============================================================================
# TIME
# =============================================================================

var current_tick: int = 0
var current_day: int = 1
var current_season: String = "Spring"
var current_year: int = 1

# =============================================================================
# TERRAIN
# =============================================================================

const TERRAINS: Dictionary = {
	"plains":   {"color": "#7ec850", "fertility": 1.0, "movement_cost": 1, "defense_bonus": 0},
	"forest":   {"color": "#3a7d25", "fertility": 0.7, "movement_cost": 2, "defense_bonus": 1},
	"hills":    {"color": "#8b7355", "fertility": 0.5, "movement_cost": 1.5, "defense_bonus": 1},
	"mountain": {"color": "#808080", "fertility": 0.1, "movement_cost": 3, "defense_bonus": 2},
	"swamp":    {"color": "#4a5d23", "fertility": 0.3, "movement_cost": 2, "defense_bonus": -1},
	"desert":   {"color": "#d4a553", "fertility": 0.0, "movement_cost": 1, "defense_bonus": 0},
	"caves":    {"color": "#3d3d3d", "fertility": 0.0, "movement_cost": 1, "defense_bonus": 2},
	"water":    {"color": "#4488ff", "fertility": 0.0, "movement_cost": 99, "defense_bonus": 0},
	"coast":    {"color": "#a8d8ea", "fertility": 0.2, "movement_cost": 1, "defense_bonus": 0},
}

const TILE_RESOURCES: Dictionary = {
	"plains": ["food", "food", "herbs"],
	"forest": ["wood", "wood", "herbs", "food"],
	"hills": ["stone", "stone", "metal", "coal"],
	"mountain": ["stone", "metal", "metal", "gold", "gems"],
	"swamp": ["herbs", "peat", "food"],
	"desert": ["gold", "salt", "stone"],
	"caves": ["metal", "gems", "gems", "mushrooms"],
}

# =============================================================================
# UNDERGROUND TERRAIN — Cave/underworld variants with distinctive colors
# =============================================================================

const UNDERGROUND_TERRAINS: Dictionary = {
	"caves":         {"color": "#2a2a2a", "fertility": 0.0, "movement_cost": 1, "defense_bonus": 2},
	"deep_cavern":   {"color": "#1a1a2e", "fertility": 0.0, "movement_cost": 2, "defense_bonus": 3},
	"crystal_cave":  {"color": "#3d2b5a", "fertility": 0.0, "movement_cost": 1, "defense_bonus": 2},
	"fungal_grove":  {"color": "#2d3d1a", "fertility": 0.3, "movement_cost": 1, "defense_bonus": 1},
	"magma_vein":    {"color": "#4a1a0a", "fertility": 0.0, "movement_cost": 2, "defense_bonus": 0},
	"underground_river": {"color": "#1a3a5a", "fertility": 0.1, "movement_cost": 1, "defense_bonus": 0},
	"buried_ruins":  {"color": "#4a3a2a", "fertility": 0.0, "movement_cost": 1, "defense_bonus": 2},
}

const UNDERGROUND_TILE_RESOURCES: Dictionary = {
	"caves": ["metal", "gems", "stone"],
	"deep_cavern": ["metal", "gems", "gems", "gold"],
	"crystal_cave": ["gems", "gems", "gems", "gold"],
	"fungal_grove": ["mushrooms", "mushrooms", "herbs", "food"],
	"magma_vein": ["metal", "metal", "gold", "gems"],
	"underground_river": ["food", "herbs", "mushrooms"],
	"buried_ruins": ["gold", "gems", "metal"],
}

const UNDERGROUND_RACES: Array[String] = ["dwarf", "goblin", "troll", "gnome"]

# =============================================================================
# GENETICS
# =============================================================================

var population_genetics: Dictionary = {}  # {nation_id: {gene_id: frequency (0.0-1.0)}}
var hybrid_demographics: Dictionary = {}  # {nation_id: {hybrid_key: proportion}}  where hybrid_key = "human_elf"

# =============================================================================
# HELPERS
# =============================================================================
# CULTURAL TRAITS - 16 civilization-level cultural traits with effects, compatibility, and emergence
# =============================================================================

const CULTURAL_TRAITS: Dictionary = {
	"warlike": {"name": "Warlike", "category": "warfare", "desc": "Glory through combat. +20% military strength, -10% trade.",
		"effects": {"military_strength": 1.2, "trade_income": 0.9},
		"compatible": ["xenophobic", "honor_bound"], "conflicts": ["pacifist", "cosmopolitan"],
		"emergence": {"min_military_strength": 10, "leader_archetypes": ["warlord", "chieftain"]}},
	"pacifist": {"name": "Pacifist", "category": "warfare", "desc": "Peace is the highest virtue. -30% military, +20% trade, +10% morale.",
		"effects": {"military_strength": 0.7, "trade_income": 1.2, "morale": 0.1},
		"compatible": ["cosmopolitan", "scholarly"], "conflicts": ["warlike", "xenophobic"]},
	"industrious": {"name": "Industrious", "category": "economy", "desc": "Hard work builds empires. +15% production, +10% stone/metal.",
		"effects": {"production": 1.15, "stone": 1.1, "metal": 1.1},
		"compatible": ["traditional", "communal"], "conflicts": ["hedonistic"]},
	"mercantile": {"name": "Mercantile", "category": "economy", "desc": "Trade is the lifeblood. +25% trade income, +1 trade route.",
		"effects": {"trade_income": 1.25},
		"compatible": ["cosmopolitan", "innovative"], "conflicts": ["xenophobic", "agrarian"]},
	"agrarian": {"name": "Agrarian", "category": "economy", "desc": "The land provides. +30% food, -10% trade.",
		"effects": {"food": 1.3, "trade_income": 0.9},
		"compatible": ["communal", "traditional"], "conflicts": ["mercantile", "nomadic"]},
	"devout": {"name": "Devout", "category": "religion", "desc": "Faith above all. +50% belief spread, +20% miracle power.",
		"effects": {"belief_spread": 1.5, "miracle_power": 0.2},
		"compatible": ["traditional", "communal"], "conflicts": ["secular", "innovative"]},
	"secular": {"name": "Secular", "category": "religion", "desc": "Reason over faith. +20% research, followers harder to convert.",
		"effects": {"research": 1.2, "belief_resistance": 0.5},
		"compatible": ["scholarly", "innovative"], "conflicts": ["devout", "traditional"]},
	"scholarly": {"name": "Scholarly", "category": "social", "desc": "Knowledge is power. +30% research, +10% intelligence trait.",
		"effects": {"research": 1.3, "intelligence": 1.1},
		"compatible": ["secular", "innovative"], "conflicts": ["warlike"]},
	"communal": {"name": "Communal", "category": "social", "desc": "Stronger together. +15% morale, +10% growth, -10% individual wealth.",
		"effects": {"morale": 0.15, "growth": 1.1},
		"compatible": ["agrarian", "devout"], "conflicts": ["individualist", "nomadic"]},
	"xenophobic": {"name": "Xenophobic", "category": "social", "desc": "Distrust outsiders. -50% interbreeding, +20% defense, -80% diplomacy.",
		"effects": {"interbreeding": 0.5, "defense": 1.2, "diplomacy": 0.2},
		"compatible": ["warlike", "traditional"], "conflicts": ["cosmopolitan", "mercantile"]},
	"cosmopolitan": {"name": "Cosmopolitan", "category": "social", "desc": "All are welcome. +50% interbreeding, +20% diplomacy, +10% trade.",
		"effects": {"interbreeding": 1.5, "diplomacy": 1.2, "trade_income": 1.1},
		"compatible": ["mercantile", "pacifist"], "conflicts": ["xenophobic", "traditional"]},
	"traditional": {"name": "Traditional", "category": "social", "desc": "The old ways are best. +20% stability, -20% innovation adoption.",
		"effects": {"stability": 0.2},
		"compatible": ["devout", "agrarian"], "conflicts": ["innovative", "secular"]},
	"innovative": {"name": "Innovative", "category": "technology", "desc": "Always looking forward. +25% research, faster tech adoption.",
		"effects": {"research": 1.25},
		"compatible": ["scholarly", "mercantile"], "conflicts": ["traditional"]},
	"honor_bound": {"name": "Honor Bound", "category": "social", "desc": "A promise is iron. +15% diplomacy, -10% cunning, never break treaties.",
		"effects": {"diplomacy": 1.15},
		"compatible": ["warlike", "traditional"], "conflicts": ["cunning", "mercantile"]},
	"hedonistic": {"name": "Hedonistic", "category": "social", "desc": "Life should be enjoyed. +10% morale, -15% production, +20% ale consumption.",
		"effects": {"morale": 0.1, "production": 0.85},
		"compatible": ["cosmopolitan"], "conflicts": ["industrious", "devout"]},
	"nomadic": {"name": "Nomadic", "category": "social", "desc": "The horizon calls. +30% expansion speed, -20% fortification.",
		"effects": {"expansion": 1.3},
		"compatible": ["warlike"], "conflicts": ["agrarian", "communal"]},
}

const GOVERNMENT_TYPES: Dictionary = {
	"kingdom": {"name": "Kingdom", "category": "centralized",
		"desc": "A realm united under a single hereditary monarch. Land and title flow through bloodlines, binding nobles to the crown.",
		"bonuses": {"food": 1.10, "production": 1.05}, "stability_base": 70,
		"diplomatic_bias": {"kingdom": 10, "republic": -5, "theocracy": 0},
		"succession_type": "hereditary",
		"policy_affinities": {"preferred": ["mandatory_labor", "heavy_taxation"], "avoided": []}},
	"republic": {"name": "Republic", "category": "decentralized",
		"desc": "Citizens elect their leaders from among the patrician class. The Senate debates, the people watch, and the realm endures.",
		"bonuses": {"trade": 1.10, "gold": 1.15}, "stability_base": 60,
		"diplomatic_bias": {"republic": 15, "merchant_republic": 10, "kingdom": -5},
		"succession_type": "elected",
		"policy_affinities": {"preferred": ["open_borders"], "avoided": ["heavy_taxation"]}},
	"clan": {"name": "Clan", "category": "tribal",
		"desc": "A gathering of kin bound by blood and oath. The chieftain leads by consent, and every warrior has a voice.",
		"bonuses": {"military": 1.10, "production": 1.05}, "stability_base": 55,
		"diplomatic_bias": {"clan": 15, "horde": 5, "kingdom": -10},
		"succession_type": "challenge",
		"policy_affinities": {"preferred": ["militia_training"], "avoided": ["heavy_taxation"]}},
	"horde": {"name": "Horde", "category": "tribal",
		"desc": "An ever-moving tide of warriors. Might makes right, and the strong devour the weak in pursuit of glory and plunder.",
		"bonuses": {"military": 1.20, "expansion": 1.30, "production": 0.90}, "stability_base": 40,
		"diplomatic_bias": {"horde": 10, "clan": 5, "republic": -15},
		"succession_type": "might",
		"policy_affinities": {"preferred": ["militia_training"], "avoided": ["sanitation_mandate", "open_borders"]}},
	"druidic_council": {"name": "Druidic Council", "category": "religious",
		"desc": "The wise elders of the grove guide the people. Nature's balance is the highest law, and the spirits speak through the council.",
		"bonuses": {"food": 1.15, "wood": 1.10, "faith": 1.20}, "stability_base": 75,
		"diplomatic_bias": {"druidic_council": 15, "theocracy": 5},
		"succession_type": "consensus",
		"policy_affinities": {"preferred": ["sanitation_mandate"], "avoided": ["militia_training", "heavy_taxation"]}},
	"theocracy": {"name": "Theocracy", "category": "religious",
		"desc": "The gods rule through mortal vessels. Priests interpret divine will, and heresy is the greatest crime.",
		"bonuses": {"faith": 1.30, "gold": 1.05}, "stability_base": 80,
		"diplomatic_bias": {"theocracy": 15, "druidic_council": 5, "secular": -10},
		"succession_type": "divine_mandate",
		"policy_affinities": {"preferred": ["sanitation_mandate", "tavern_open"], "avoided": ["open_borders"]}},
	"merchant_republic": {"name": "Merchant Republic", "category": "commercial",
		"desc": "Coin is king and the guilds rule. Wealth buys influence, and the richest families steer the ship of state.",
		"bonuses": {"gold": 1.25, "trade": 1.20, "food": 0.90}, "stability_base": 55,
		"diplomatic_bias": {"merchant_republic": 15, "republic": 10, "horde": -10},
		"succession_type": "wealth_election",
		"policy_affinities": {"preferred": ["open_borders", "heavy_taxation"], "avoided": ["militia_training"]}},
	"mountain_hold": {"name": "Mountain Hold", "category": "decentralized",
		"desc": "Carved into the living rock, these fortress-cities prize endurance above all. Every tunnel is a stronghold, every hall a redoubt.",
		"bonuses": {"stone": 1.25, "metal": 1.20, "expansion": 0.70, "trade": 0.80}, "stability_base": 85,
		"diplomatic_bias": {"mountain_hold": 15, "kingdom": -5},
		"succession_type": "clan_election",
		"policy_affinities": {"preferred": ["mandatory_labor", "militia_training"], "avoided": ["open_borders"]}},
	"tyrant_state": {"name": "Tyrant State", "category": "centralized",
		"desc": "One iron fist rules all. Fear is the currency of loyalty, and opposition is met with the swiftest cruelty.",
		"bonuses": {"production": 1.20, "military": 1.10, "food": 0.85}, "stability_base": 35,
		"diplomatic_bias": {"tyrant_state": 5, "republic": -20},
		"succession_type": "coup_or_inherit",
		"policy_affinities": {"preferred": ["mandatory_labor", "heavy_taxation"], "avoided": ["open_borders", "tavern_open"]}},
	"warrior_society": {"name": "Warrior Society", "category": "tribal",
		"desc": "Every soul is a weapon waiting to be honed. Glory in battle is the highest virtue, and peace is merely the pause between wars.",
		"bonuses": {"military": 1.25, "production": 0.95, "food": 0.90}, "stability_base": 50,
		"diplomatic_bias": {"warrior_society": 15, "horde": 10, "merchant_republic": -10},
		"succession_type": "trial_by_combat",
		"policy_affinities": {"preferred": ["militia_training", "mandatory_labor"], "avoided": ["open_borders", "tavern_open"]}},
}

# =============================================================================
# RACE VARIANTS - Subrace divergences with terrain triggers and bonus modifiers
# =============================================================================

const RACE_VARIANTS: Dictionary = {
	"forest_elf": {
		"parent_race": "elf",
		"terrain_triggers": ["forest"],
		"bonus_modifiers": {"food": 0.8, "wood": 1.4, "intelligence": 1.1},
		"name": "Forest Elf",
		"emergence_generations": 100,
		"specialization": "forestry",
	},
	"grassland_elf": {
		"parent_race": "elf",
		"terrain_triggers": ["plains"],
		"bonus_modifiers": {"food": 1.2, "wood": 0.7},
		"name": "Grassland Elf",
		"emergence_generations": 120,
		"specialization": "agriculture",
	},
	"deep_dwarf": {
		"parent_race": "dwarf",
		"terrain_triggers": ["caves"],
		"bonus_modifiers": {"stone": 1.3, "metal": 1.3, "food": 0.6},
		"name": "Deep Dwarf",
		"emergence_generations": 150,
		"specialization": "deep_mining",
	},
	"hill_dwarf": {
		"parent_race": "dwarf",
		"terrain_triggers": ["hills"],
		"bonus_modifiers": {"food": 1.1, "trade": 1.1},
		"name": "Hill Dwarf",
		"emergence_generations": 100,
		"specialization": "trade",
	},
	"mountain_black_orc": {
		"parent_race": "orc",
		"terrain_triggers": ["mountain"],
		"bonus_modifiers": {"strength": 1.3, "intelligence": 0.8, "fertility": 0.7},
		"name": "Mountain Black Orc",
		"emergence_generations": 150,
		"specialization": "fortress",
	},
	"island_wild_orc": {
		"parent_race": "orc",
		"terrain_triggers": ["coast"],
		"bonus_modifiers": {"military": 1.2, "trade": 0.5},
		"name": "Island Wild Orc",
		"emergence_generations": 100,
		"specialization": "raiding",
	},
	"plains_orc": {
		"parent_race": "orc",
		"terrain_triggers": ["plains"],
		"bonus_modifiers": {"fertility": 1.2, "expansion": 1.2},
		"name": "Plains Orc",
		"emergence_generations": 80,
		"specialization": "expansion",
	},
	"coastal_human": {
		"parent_race": "human",
		"terrain_triggers": ["coast"],
		"bonus_modifiers": {"trade": 1.3, "food": 0.8, "gold": 1.15},
		"name": "Coastal Human",
		"emergence_generations": 80,
		"specialization": "maritime",
	},
	"cave_goblin": {
		"parent_race": "goblin",
		"terrain_triggers": ["caves"],
		"bonus_modifiers": {"fertility": 0.7, "intelligence": 1.2, "adaptability": 0.7},
		"name": "Cave Goblin",
		"emergence_generations": 120,
		"specialization": "crafting",
	},
	"swamp_goblin": {
		"parent_race": "goblin",
		"terrain_triggers": ["swamp"],
		"bonus_modifiers": {"fertility": 1.4, "adaptability": 1.2},
		"name": "Swamp Goblin",
		"emergence_generations": 60,
		"specialization": "survival",
	},
	"river_halfling": {
		"parent_race": "halfling",
		"terrain_triggers": ["plains"],
		"bonus_modifiers": {"food": 1.3, "trade": 1.2},
		"name": "River Halfling",
		"emergence_generations": 100,
		"specialization": "farming",
	},
	"hill_halfling": {
		"parent_race": "halfling",
		"terrain_triggers": ["hills"],
		"bonus_modifiers": {"stone": 1.2, "food": 0.9},
		"name": "Hill Halfling",
		"emergence_generations": 100,
		"specialization": "mining",
	},
	"desert_dwarf": {
		"parent_race": "dwarf",
		"terrain_triggers": ["desert"],
		"bonus_modifiers": {"gold": 1.4, "metal": 1.1, "food": 0.4},
		"name": "Desert Dwarf",
		"emergence_generations": 200,
		"specialization": "prospecting",
	},
	"wild_elf": {
		"parent_race": "elf",
		"terrain_triggers": ["forest"],
		"bonus_modifiers": {"military": 1.2, "piety": 1.2, "trade": 0.6},
		"name": "Wild Elf",
		"emergence_generations": 80,
		"specialization": "hunting",
	},
	"clockwork_gnome": {
		"parent_race": "gnome",
		"terrain_triggers": ["hills"],
		"bonus_modifiers": {"gold": 1.3, "research": 1.3, "piety": 0.6},
		"name": "Clockwork Gnome",
		"emergence_generations": 120,
		"specialization": "engineering",
	},
	"frost_troll": {
		"parent_race": "troll",
		"terrain_triggers": ["mountain"],
		"bonus_modifiers": {"strength": 1.2, "resilience": 1.3, "fertility": 0.5},
		"name": "Frost Troll",
		"emergence_generations": 200,
		"specialization": "hardiness",
	},
	"war_ogre": {
		"parent_race": "ogre",
		"terrain_triggers": ["mountain"],
		"bonus_modifiers": {"military": 1.4, "expansion": 1.2, "intelligence": 0.7},
		"name": "War Ogre",
		"emergence_generations": 180,
		"specialization": "warfare",
	},
}

# =============================================================================
# RACIAL ARCHITECTURE STYLES - Determines visual building themes by race and era
# =============================================================================

const RACIAL_ARCHITECTURE_STYLES: Dictionary = {
	"human": {"era_style": {"stone":"wattle_daub","bronze":"timber_frame","iron":"stone_masonry","steel":"gothic","arcane":"grand_citadel"}},
	"dwarf": {"era_style": {"stone":"carved_stone","bronze":"reinforced_hold","iron":"deep_forge","steel":"adamantine","arcane":"living_rock"}},
	"elf": {"era_style": {"stone":"woven_bough","bronze":"grown_wood","iron":"crystal_spire","steel":"moonsilver","arcane":"star_temple"}},
	"orc": {"era_style": {"stone":"hide_tent","bronze":"timber_fort","iron":"blood_citadel","steel":"war_camp","arcane":"black_fortress"}},
	"halfling": {"era_style": {"stone":"burrow","bronze":"plaster_house","iron":"brick_hall","steel":"manor_house","arcane":"grand_burrow"}},
	"goblin": {"era_style": {"stone":"mud_hut","bronze":"scrap_hut","iron":"timber_shack","steel":"tunnel_warren","arcane":"undercity"}},
	"troll": {"era_style": {"stone":"rock_shelter","bronze":"bone_hut","iron":"crude_fort","steel":"brutal_hold","arcane":"monolith"}},
	"ogre": {"era_style": {"stone":"boulder_pile","bronze":"log_fort","iron":"giant_hold","steel":"titan_citadel","arcane":"sky_breaker"}},
	"gnome": {"era_style": {"stone":"clockwork_house","bronze":"gear_fort","iron":"steam_hall","steel":"automaton_factory","arcane":"grand_academy"}},
}

# =============================================================================
# BUILDINGS
# =============================================================================

const BUILDINGS: Dictionary = {
	"farm": {"name":"Farm","description":"Produces food from fertile land.","category":"economic","effects":{"food":1.15},"cost":{"wood":5},"placement_terrain":["plains","hills"],"tier":1,"maintenance":{"gold":0.5},"upgrade_to":"irrigation_farm"},
	"mine": {"name":"Mine","description":"Extracts stone and metal from hills and mountains.","category":"economic","effects":{"stone":1.15,"metal":1.1},"cost":{"wood":10},"placement_terrain":["hills","mountain","caves"],"tier":1,"maintenance":{"gold":1}},
	"lumber_camp": {"name":"Lumber Camp","description":"Harvests wood from forests.","category":"economic","effects":{"wood":1.2},"cost":{"gold":3},"placement_terrain":["forest"],"tier":1,"maintenance":{"gold":0.5}},
	"quarry": {"name":"Quarry","description":"Deep excavation for stone.","category":"economic","effects":{"stone":1.25},"cost":{"wood":5,"gold":10},"placement_terrain":["mountain","hills"],"tier":2,"maintenance":{"gold":1.5}},
	"shrine": {"name":"Shrine","description":"A small place of worship. Increases belief.","category":"religious","effects":{"faith":1.1},"cost":{"stone":15,"gold":10},"placement_terrain":["plains","hills","forest","mountain","caves","swamp","desert"],"tier":1,"maintenance":{"gold":1}},
	"temple": {"name":"Temple","description":"A grand house of worship. Greatly increases belief.","category":"religious","effects":{"faith":1.25},"cost":{"stone":40,"gold":30},"placement_terrain":["plains","hills","forest"],"tier":2,"maintenance":{"gold":3}},
	"monument": {"name":"Monument","description":"A divine monument. Major belief boost and morale.","category":"religious","effects":{"faith":1.4},"cost":{"stone":80,"gold":60},"placement_terrain":["plains","hills","mountain"],"tier":3,"maintenance":{"gold":5}},
	"fort": {"name":"Fort","description":"Fortified position. +defense.","category":"military","effects":{"defense":1.2},"cost":{"stone":20,"wood":10},"placement_terrain":["hills","mountain","plains","forest"],"tier":1,"maintenance":{"gold":2},"upgrade_to":"castle"},
	"harbor": {"name":"Harbor","description":"Maritime trade and fishing.","category":"economic","effects":{"trade":1.15,"food":1.1},"cost":{"wood":20,"gold":15},"placement_terrain":["coast"],"tier":1,"maintenance":{"gold":2}},
	"market": {"name":"Market","description":"Center of commerce. Boosts trade income.","category":"economic","effects":{"trade":1.2,"gold":1.1},"cost":{"wood":15,"stone":10},"placement_terrain":["plains"],"tier":1,"maintenance":{"gold":1.5}},
	"workshop": {"name":"Workshop","description":"Crafting center. Boosts production.","category":"economic","effects":{"production":1.15},"cost":{"wood":10,"stone":10},"placement_terrain":["plains","hills"],"tier":1,"maintenance":{"gold":1},"upgrade_to":"forge"},
	"barracks": {"name":"Barracks","description":"Military training grounds.","category":"military","effects":{"military":1.15},"cost":{"stone":15,"wood":10},"placement_terrain":["plains","hills"],"tier":1,"maintenance":{"gold":2},"upgrade_to":"garrison"},
	"library": {"name":"Library","description":"Repository of knowledge.","category":"infrastructure","effects":{"research":1.2},"cost":{"wood":20,"gold":25},"placement_terrain":["plains","hills","forest"],"tier":2,"maintenance":{"gold":3}},
	"granary": {"name":"Granary","description":"Food storage. Increases food capacity.","category":"infrastructure","effects":{"food_capacity":1.3},"cost":{"wood":15,"stone":10},"placement_terrain":["plains","hills"],"tier":1,"maintenance":{"gold":0.5}},
	"irrigation_farm": {"name":"Irrigation Farm","desc":"Advanced farming. +30% food.","category":"economic","effects":{"food":1.30},"cost":{"wood":15,"stone":10},"placement_terrain":["plains","hills"],"tier":2,"maintenance":{"gold":1},"upgrades_from":"farm"},
	"castle": {"name":"Castle","desc":"Fortified stronghold. +35% defense.","category":"military","effects":{"defense":1.35},"cost":{"stone":40,"wood":20,"gold":20},"placement_terrain":["hills","mountain","plains","forest"],"tier":2,"maintenance":{"gold":3},"upgrades_from":"fort"},
	"garrison": {"name":"Garrison","desc":"Military training center. +25% military.","category":"military","effects":{"military":1.25},"cost":{"stone":25,"wood":15,"gold":10},"placement_terrain":["plains","hills"],"tier":2,"maintenance":{"gold":2},"upgrades_from":"barracks"},
	"forge": {"name":"Forge","desc":"Advanced crafting. +25% production.","category":"economic","effects":{"production":1.25},"cost":{"stone":20,"gold":15},"placement_terrain":["plains","hills","mountain"],"tier":2,"maintenance":{"gold":2},"upgrades_from":"workshop"},
}

# =============================================================================
# FACTIONS - Neutral factions that can appear on the world map
# =============================================================================

const FACTIONS: Dictionary = {
	"wild_tribe": {"name":"Wild Tribe","threat_level":3,"drops":{"food":10,"gold":5},"interactions":["fight","integrate","enslave"]},
	"bandit_camp": {"name":"Bandit Camp","threat_level":2,"drops":{"gold":15,"metal":5},"interactions":["fight","bribe"]},
	"monster_lair": {"name":"Monster Lair","threat_level":5,"drops":{"gold":30,"gems":10},"interactions":["fight"]},
	"ancient_guardian": {"name":"Ancient Guardian","threat_level":4,"drops":{"gold":50,"gems":15},"interactions":["fight"]},
	"merchant_caravan": {"name":"Lost Caravan","threat_level":1,"drops":{"gold":20,"food":5},"interactions":["fight","trade","bribe"]},
	"pirate_den": {"name":"Pirate Den","threat_level":3,"drops":{"gold":25,"metal":10},"interactions":["fight","bribe"]},
}

# =============================================================================
# HELPERS
# =============================================================================

func _ready() -> void:
	EventBus.leader_changed.connect(_on_leader_changed)

func _on_leader_changed(nation_id: int, _old_id: int, _new_id: int) -> void:
	_leader_by_nation.erase(nation_id)

# =============================================================================
# RACE STARTING RESOURCES - Race-specific initial resource pools
# =============================================================================

const RACE_STARTING_RESOURCES: Dictionary = {
	"human":    {"food": 140.0, "wood": 60.0, "stone": 40.0, "metal": 15.0, "gold": 30.0},
	"dwarf":    {"food": 100.0, "wood": 40.0, "stone": 80.0, "metal": 35.0, "gold": 37.5},
	"elf":      {"food": 120.0, "wood": 80.0, "stone": 30.0, "metal": 10.0, "gold": 22.5},
	"orc":      {"food": 150.0, "wood": 50.0, "stone": 30.0, "metal": 10.0, "gold": 7.5},
	"halfling": {"food": 180.0, "wood": 50.0, "stone": 25.0, "metal": 10.0, "gold": 45.0},
	"goblin":   {"food": 90.0,  "wood": 30.0, "stone": 25.0, "metal": 10.0, "gold": 7.5},
	"troll":    {"food": 80.0,  "wood": 30.0, "stone": 40.0, "metal": 5.0,  "gold": 7.5},
	"ogre":     {"food": 120.0, "wood": 20.0, "stone": 30.0, "metal": 5.0,  "gold": 3.0},
	"gnome":    {"food": 100.0, "wood": 40.0, "stone": 50.0, "metal": 25.0, "gold": 52.5},
}

func create_nation(name: String, primary_race: String, color: String, capital_x: int, capital_y: int) -> Dictionary:
	var starting_res: Dictionary = RACE_STARTING_RESOURCES.get(primary_race, RACE_STARTING_RESOURCES["human"])
	var nation: Dictionary = {
		"id": nations.size(),
		"name": name,
		"primary_race": primary_race,
		"color": color,
		"capital_x": capital_x,
		"capital_y": capital_y,
		"population": randi_range(80, 200),
		"resources": starting_res.duplicate(),
		"military_strength": randi_range(5, 25),
		"relationships": {},
		"policies": [],
		"ai_type": ["passive", "aggressive", "trader", "isolationist"].pick_random(),
		"leader_id": -1,  # Will be set after character generation
		"government": "kingdom",  # Default; overridden by _assign_governments in WorldGenerator
		"race_demographics": {primary_race: 1.0},  # {race_id: proportion}
	}
	_nation_by_id[nation["id"]] = nation
	return nation

func next_character_id() -> int:
	_next_character_id += 1
	return _next_character_id - 1

func get_tile(x: int, y: int) -> Dictionary:
	var idx = y * world_width + x
	if idx < 0 or idx >= world_tiles.size():
		return {"terrain": "water", "resource": "", "owner": -1, "buildings": []}
	return world_tiles[idx]

func set_tile(x: int, y: int, data: Dictionary) -> void:
	var idx = y * world_width + x
	if idx >= 0 and idx < world_tiles.size():
		world_tiles[idx] = data

func get_underground_tile(x: int, y: int) -> Dictionary:
	var idx = y * world_width + x
	if idx < 0 or idx >= underground_tiles.size():
		return {"terrain": "caves", "resource": "", "owner": -1, "buildings": []}
	return underground_tiles[idx]

func add_notification(text: String, category: String = "general") -> void:
	notification_log.append({"tick": current_tick, "text": text, "category": category})
	while notification_log.size() > 200:
		notification_log.pop_front()

func add_chronicle_entry(text: String, category: String) -> void:
	notification_log.push_front({"tick": current_tick, "text": text, "category": category})
	while notification_log.size() > 200:
		notification_log.pop_back()

func set_underground_tile(x: int, y: int, data: Dictionary) -> void:
	var idx = y * world_width + x
	if idx >= 0 and idx < underground_tiles.size():
		underground_tiles[idx] = data

func get_nation(nation_id: int) -> Dictionary:
	if _nation_by_id.has(nation_id):
		return _nation_by_id[nation_id]
	for n in nations:
		if n["id"] == nation_id:
			_nation_by_id[nation_id] = n
			return n
	return {}

func get_nation_cached(id: int) -> Dictionary:
	if _nation_by_id.has(id):
		return _nation_by_id[id]
	return get_nation(id)

func get_player_nation() -> Dictionary:
	return get_nation(player_nation_id)

func get_character(char_id: int) -> Dictionary:
	for c in characters:
		if c["id"] == char_id:
			return c
	return {}

func get_leader(nation_id: int) -> Dictionary:
	if _leader_by_nation.has(nation_id):
		return _leader_by_nation[nation_id]
	for c in characters:
		if c.get("role", "") == "leader" and c["nation_id"] == nation_id and c.get("alive", true):
			_leader_by_nation[nation_id] = c
			return c
	return {}

func get_leader_cached(nation_id: int) -> Dictionary:
	if _leader_by_nation.has(nation_id):
		return _leader_by_nation[nation_id]
	return get_leader(nation_id)

func get_belief(nation_id: int, race_id: String) -> float:
	if not belief_by_nation.has(nation_id):
		return 0.0
	return belief_by_nation[nation_id].get(race_id, 0.0)

func set_belief(nation_id: int, race_id: String, value: float) -> void:
	if not belief_by_nation.has(nation_id):
		belief_by_nation[nation_id] = {}
	belief_by_nation[nation_id][race_id] = clamp(value, 0.0, 1.0)

func get_aspect_attraction(nation_id: int, aspect_id: String) -> float:
	var nation: Dictionary = get_nation(nation_id)
	if nation.is_empty():
		return 0.0
	# Believer attraction lookup per race per aspect (inline to avoid autoload class_name ref)
	const ATTRACTION: Dictionary = {
		"aspect_of_war": {"orc": 0.3, "human": 0.1, "goblin": 0.1},
		"aspect_of_harvest": {"halfling": 0.3, "human": 0.15, "elf": 0.1},
		"aspect_of_knowledge": {"elf": 0.3, "dwarf": 0.2, "gnome": 0.2},
		"aspect_of_nature": {"elf": 0.35, "halfling": 0.15},
		"aspect_of_trade": {"halfling": 0.3, "human": 0.2, "gnome": 0.15},
		"aspect_of_death": {"goblin": 0.4, "orc": 0.2},
		"aspect_of_forge": {"dwarf": 0.35, "human": 0.1, "gnome": 0.1},
	}
	var demographics: Dictionary = nation.get("race_demographics", {})
	var total_attraction: float = 0.0
	var total_share: float = 0.0
	for race_id in demographics:
		var share: float = demographics[race_id]
		total_share += share
		var attraction: float = ATTRACTION.get(aspect_id, {}).get(race_id, 0.0)
		total_attraction += attraction * share
	if total_share > 0.0:
		return total_attraction / total_share
	return 0.0

# =============================================================================
# GENETICS HELPERS
# =============================================================================

const INTERBREEDING_MATRIX: Dictionary = {
	"human_elf": 0.2, "human_dwarf": 0.5, "human_orc": 0.3, "human_halfling": 0.7, "human_goblin": 0.4, "human_troll": 0.1, "human_ogre": 0.05, "human_gnome": 0.6,
	"elf_dwarf": 0.1, "elf_orc": 0.0, "elf_halfling": 0.3, "elf_goblin": 0.1, "elf_troll": 0.0, "elf_ogre": 0.0, "elf_gnome": 0.3,
	"dwarf_orc": 0.1, "dwarf_halfling": 0.4, "dwarf_goblin": 0.2, "dwarf_troll": 0.1, "dwarf_ogre": 0.1, "dwarf_gnome": 0.9,
	"orc_halfling": 0.1, "orc_goblin": 0.6, "orc_troll": 0.5, "orc_ogre": 0.3, "orc_gnome": 0.1,
	"halfling_goblin": 0.5, "halfling_troll": 0.1, "halfling_ogre": 0.0, "halfling_gnome": 0.7,
	"goblin_troll": 0.4, "goblin_ogre": 0.3, "goblin_gnome": 0.3,
	"troll_ogre": 0.4, "troll_gnome": 0.0,
	"ogre_gnome": 0.0,
}

func get_race_genetics(race_id: String) -> Dictionary:
	return RACES.get(race_id, {}).get("genetics", {})

func get_interbreeding_tendency(race_a: String, race_b: String) -> float:
	if race_a == race_b:
		return 0.0
	# Sort alphabetically for consistent matrix key lookup
	var sorted_pair = [race_a, race_b]
	sorted_pair.sort()
	var matrix_key: String = sorted_pair[0] + "_" + sorted_pair[1]
	if INTERBREEDING_MATRIX.has(matrix_key):
		return INTERBREEDING_MATRIX[matrix_key]
	# Fallback to average of both races' interbreeding_tendency values
	var a: float = RACES.get(race_a, {}).get("interbreeding_tendency", 0.5)
	var b: float = RACES.get(race_b, {}).get("interbreeding_tendency", 0.5)
	return (a + b) / 2.0

func create_hybrid_traits(race_a: String, race_b: String) -> Dictionary:
	# Special hybrid: Orc + Troll = Drab Blood Orc with extra strength
	if (race_a == "orc" and race_b == "troll") or (race_a == "troll" and race_b == "orc"):
		var genetics_a: Dictionary = get_race_genetics(race_a)
		var genetics_b: Dictionary = get_race_genetics(race_b)
		var blended: Dictionary = {}
		var all_traits: Array[String] = []
		for gene in genetics_a.values():
			var trait_name: String = gene.get("trait", "")
			if trait_name not in all_traits:
				all_traits.append(trait_name)
		for gene in genetics_b.values():
			var trait_name: String = gene.get("trait", "")
			if trait_name not in all_traits:
				all_traits.append(trait_name)
		for trait_name in all_traits:
			var val_a: float = 0.0
			var dominant_a: bool = false
			var val_b: float = 0.0
			var dominant_b: bool = false
			for gene in genetics_a.values():
				if gene.get("trait", "") == trait_name:
					val_a = gene.get("value", 0.0)
					dominant_a = gene.get("dominance", "recessive") == "dominant"
					break
			for gene in genetics_b.values():
				if gene.get("trait", "") == trait_name:
					val_b = gene.get("value", 0.0)
					dominant_b = gene.get("dominance", "recessive") == "dominant"
					break
			if dominant_a and not dominant_b:
				blended[trait_name] = val_a
			elif dominant_b and not dominant_a:
				blended[trait_name] = val_b
			else:
				blended[trait_name] = (val_a + val_b) / 2.0
		# Extra strength bonus for Drab Blood Orc
		blended["strength"] = blended.get("strength", 0.0) + 0.5
		blended["hybrid_name"] = "Drab Blood Orc"
		return blended

	var genetics_a: Dictionary = get_race_genetics(race_a)
	var genetics_b: Dictionary = get_race_genetics(race_b)
	var blended: Dictionary = {}

	# Collect all unique trait names from both parents
	var all_traits: Array[String] = []
	for gene in genetics_a.values():
		var trait_name: String = gene.get("trait", "")
		if trait_name not in all_traits:
			all_traits.append(trait_name)
	for gene in genetics_b.values():
		var trait_name: String = gene.get("trait", "")
		if trait_name not in all_traits:
			all_traits.append(trait_name)

	for trait_name in all_traits:
		# Find genes in both parents that affect this trait
		var val_a: float = 0.0
		var dominant_a: bool = false
		var val_b: float = 0.0
		var dominant_b: bool = false

		for gene in genetics_a.values():
			if gene.get("trait", "") == trait_name:
				val_a = gene.get("value", 0.0)
				dominant_a = gene.get("dominance", "recessive") == "dominant"
				break
		for gene in genetics_b.values():
			if gene.get("trait", "") == trait_name:
				val_b = gene.get("value", 0.0)
				dominant_b = gene.get("dominance", "recessive") == "dominant"
				break

		# Dominant genes take precedence; if both dominant or both recessive, average
		if dominant_a and not dominant_b:
			blended[trait_name] = val_a
		elif dominant_b and not dominant_a:
			blended[trait_name] = val_b
		else:
			blended[trait_name] = (val_a + val_b) / 2.0

	return blended
