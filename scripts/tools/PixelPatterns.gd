class_name PixelPatterns
# =============================================================================
# Static pixel pattern definitions as color-index arrays.
# Uses a 16-color palette where index 0 = transparent.
# =============================================================================

# 16-color palette mapping index -> Color hex string
const PALETTE: Dictionary = {
	0: "",           # Transparent (alpha 0)
	1: "#1a1c2c",    # Dark
	2: "#5d275d",    # Purple
	3: "#b13e53",    # Red
	4: "#ef7d57",    # Orange
	5: "#ffcd75",    # Yellow
	6: "#a7f070",    # Green
	7: "#38b764",    # Dark green
	8: "#257179",    # Teal
	9: "#29366f",    # Dark blue
	10: "#3b5dc9",   # Blue
	11: "#41a6f6",   # Light blue
	12: "#73eff7",   # Cyan
	13: "#f4f4f4",   # White
	14: "#94b0c2",   # Grey
	15: "#566c86",   # Dark grey
}

# =============================================================================
# MATERIAL COLOR RAMPS — DF-style palette swapping
# Each ramp has 9 colors mapped to palette indices 1-9.
# Index 0 is always transparent. Higher indices (10-15) retain their
# default PALETTE values for highlights, shadows, and accent colors.
# One sprite, many materials — the Dwarf Fortress genius insight.
# =============================================================================

const MATERIAL_RAMPS: Dictionary = {
	"stone_granite": ["#ffffff", "#c7c4b4", "#a5a6a5", "#8a9091", "#6b7076", "#5a5e65", "#494c54", "#3c3e46", "#2f3038"],
	"stone_marble": ["#ffffff", "#e8e8e8", "#d0d0d0", "#b8b8b8", "#a0a0a0", "#888888", "#707070", "#585858", "#404040"],
	"stone_obsidian": ["#404040", "#383838", "#303030", "#282828", "#202020", "#181818", "#101010", "#080808", "#000000"],
	"stone_sandstone": ["#f5deb3", "#e8d5a3", "#dbcc93", "#cec383", "#c1ba73", "#b4b163", "#a7a853", "#9a9f43", "#8d9633"],
	"wood_oak": ["#8b6914", "#7a5c12", "#694f10", "#58420e", "#47350c", "#36280a", "#251b08", "#140e06", "#030104"],
	"metal_iron": ["#d4d4d4", "#bebebe", "#a8a8a8", "#929292", "#7c7c7c", "#666666", "#505050", "#3a3a3a", "#242424"],
	"metal_gold": ["#ffd700", "#e6c200", "#ccad00", "#b39800", "#998300", "#806e00", "#665900", "#4d4400", "#332f00"],
	"cloth_red": ["#ff4444", "#e63d3d", "#cc3636", "#b32f2f", "#992828", "#802121", "#661a1a", "#4d1313", "#330c0c"],
}

# =============================================================================
# TERRAIN → MATERIAL MAPPING
# Maps each terrain type to candidate material(s). WorldGenerator picks
# randomly from the list when assigning tile materials.
# =============================================================================

const TERRAIN_MATERIALS: Dictionary = {
	"mountain": ["stone_granite", "stone_marble", "stone_obsidian"],
	"caves": ["stone_granite", "stone_obsidian"],
	"forest": ["wood_oak"],
	"hills": ["stone_sandstone", "stone_granite"],
	"plains": ["stone_sandstone", "stone_granite"],
	"desert": ["stone_sandstone"],
	"swamp": [],  # no material swap — use default palette
	"water": [],   # water uses its own animation
	"coast": [],   # coast uses its own animation
}

# =============================================================================
# BUILDING CATEGORY → MATERIAL
# Buildings of a given category map to a material for palette-swapped icons.
# =============================================================================

const BUILDING_MATERIALS: Dictionary = {
	"military": "stone_granite",
	"religious": "metal_gold",
	"economic": "wood_oak",
	"infrastructure": "stone_marble",
}

# Convenient color name mapping
const C: Dictionary = {
	"transparent": 0, "dark": 1, "purple": 2, "red": 3,
	"orange": 4, "yellow": 5, "green": 6, "dark_green": 7,
	"teal": 8, "dark_blue": 9, "blue": 10, "light_blue": 11,
	"cyan": 12, "white": 13, "grey": 14, "dark_grey": 15,
}

# =============================================================================
# HELPER: Convert hex digit string rows to flat array
# =============================================================================

static func parse_hex_rows(rows: PackedStringArray) -> Array[int]:
	"""Convert rows of hex chars into flat Array[int]."""
	var result: Array[int] = []
	for row in rows:
		for ch in row:
			result.append(int("0x" + ch))
	return result

static func parse_binary_rows(rows: PackedStringArray) -> Array[int]:
	"""Convert rows of '0'/'1' chars into flat Array[int]."""
	var result: Array[int] = []
	for row in rows:
		for ch in row:
			result.append(int(ch))
	return result

# =============================================================================
# TERRAIN PATTERNS (16 × 16)
# Each pattern: { width, height, pixels (Array[int] flat) }
# Encoding: rows of hex chars, each char = palette index (0-15)
# =============================================================================

const PLAINS_ROWS: PackedStringArray = [
	"6676667667666766",  # grass with dark tufts
	"6656665666566656",  # yellow flowers scattered
	"7677667667667676",  # dark green grass shadow
	"6665666656666666",  # light green with flowers
	"6676666667666667",  # grass tufts
	"6656665666566656",  # more yellow flowers
	"7667666766766676",  # shadow patches
	"6666666665666666",  # single yellow flower
	"6676667667666767",  # dense tufts
	"6655565665666656",  # small flower cluster
	"7667667667667666",  # shadow variation
	"6665666666656666",  # scattered flowers
	"6676667667666766",  # grass tufts
	"6665665665566656",  # flower trio
	"7666676667666676",  # shadow bands
	"6676667666766666",  # bottom grass
]

const FOREST_ROWS: PackedStringArray = [
	"6767676767676767",  # canopy top: alternating green/dark green
	"7667667667667667",  # leaf cluster layer
	"6567656765676567",  # light through canopy (yellow)
	"6767667667666766",  # dense foliage
	"7576576576576576",  # canopy highlights
	"6611661166116611",  # trunks emerge (1=dark trunk)
	"6116611661166116",  # staggered trunks
	"6611661166116611",  # thick trunk layer
	"6116611661166116",  # trunks with branch gaps
	"6611661166116611",  # lower trunks
	"6744674467446746",  # transition: fallen leaves on floor
	"7744774477447744",  # forest floor: dark green + orange leaves
	"4774477447744774", # leaf litter scattered
	"7744774477447744",  # more floor
	"4774477447744774",  # deep leaf litter
	"7744774477447744",  # bottom
]

const HILLS_ROWS: PackedStringArray = [
	"6664666466646664",  # hilltop: green grass
	"6646664666466646",  # grass with shadow
	"6466646664666466",  # descending slope
	"4666646664666464",  # green fading to earth
	"4664664664664664",  # earth tones appear
	"1464146414641464",  # exposed brown soil
	"4146414641464146",  # diagonal slope lines
	"6414641464146414",  # continuing slope
	"4641464e14641464",  # small rocks (e=14 grey)
	"1464146414641464",  # soil with grass patches
	"414e414641464146",  # more rocks
	"6414641464146414",  # lower slope
	"4664146414641464",  # grass returning at base
	"1464146414641464",  # soil
	"4146414641464146",  # bottom slope
	"6414641464146414",  # base
]

const MOUNTAIN_ROWS: PackedStringArray = [
	"00db00dd00db00dd",  # snow caps on transparent sky (d=13 white, b=11 light blue)
	"0dbd0dbd0dbd0dbd",  # snow descending
	"d0dbd0dbd0dbd0db",  # pure snow peaks
	"eded1edeeded1ede",  # snow meets grey rock (e=14 grey)
	"0ededede0ededede",  # rock face with snow patches
	"dede1ededede1ede",  # rock with crevices (1=dark)
	"ede1ede1ede1ede1",  # exposed rock face
	"d1edfed1d1edfed1",  # dark rock zones (f=15 dark grey)
	"fed1efedfed1efed",  # rocky texture
	"ed1fed1eed1fed1e",  # alternating rock layers
	"d1fedfe1d1fedfe1",  # shadow crevices deepen
	"fed1fedffed1fedf",  # dark rock dominant
	"efed1efeefed1efe",  # rock base
	"fe1fedf1fe1fedf1",  # mountain base transitions
	"edfed1efedfed1ef",  # lower rock
	"fed1fed1fed1fed1",  # base: consistent rock
]

const SWAMP_ROWS: PackedStringArray = [
	"7777177777717777",  # murky base with tree roots (1=dark)
	"7676176776767676",  # moss patches (6=green) with root dots
	"7772787772787278",  # water puddles (8=teal) with poison (2=purple)
	"7617677617677617",  # moss and roots
	"7827782778277827",  # open murky water (teal)
	"7767767767767767",  # murky shore transition
	"7772787772787278",  # more puddles with purple tint
	"7676767676767676",  # moss between pools
	"7777177777717777",  # surface with twisted roots
	"7672176776727676",  # moss with purple poison bubbles
	"7827782778277827",  # deep water pool
	"7767767767767767",  # murk
	"7772787772787278",  # water puddles
	"7617677617677627",  # moss with poison bubble
	"7827782778277827",  # water dominant
	"7777777777777777",  # bottom murk
]

const DESERT_ROWS: PackedStringArray = [
	"5555455555554555",  # dune ridge (4=orange shadow)
	"5545555555455555",  # dune slope
	"5555554555555545",  # fine ripple
	"5555455555554555",  # ridge repeat
	"554555555545e555",  # scattered rock (e=14 grey)
	"555555e555555545",  # rock on dune
	"5555455555554555",  # open sand
	"5545555555455555",  # slope
	"5555554555555545",  # ripple
	"5555455e55554555",  # rock
	"5545555555455555",  # 
	"555555e555555545",  # rock
	"5555455555554555",  # ridge
	"5545555555455555",  # slope
	"5555554555555545",  # ripple
	"5555455555554555",  # bottom ridge
]

const CAVES_ROWS: PackedStringArray = [
	"e11e1ee11e11ee11",  # stalactites from ceiling (e=14 grey)
	"1ee1e1e1ee1e1ee1",  # jagged rock formations
	"e1e11e1e11e1e1ee",  # more stalactites
	"11e1e11e1e11e1e1",  # stalactite tips
	"1111111111111111",  # cave darkness (1=dark)
	"111c1111c11111c1",  # cyan mineral veins (c=12)
	"1111111111111111",  # darkness
	"1111141111411114",  # orange mineral deposits (4)
	"1f11f11f11f11f11",  # dark rock formations (f=15 dark grey)
	"1111111111111111",  # darkness
	"1111c11111c11111",  # mineral glow
	"1111111111111111",  # darkness
	"1111141111411114",  # orange minerals
	"1111111111111111",  # darkness
	"1f11f11f11f11f11",  # rock base
	"1111111111111111",  # bottom darkness
]

const WATER_ROWS: PackedStringArray = [
	"a9aa9aa9aa9aa9a9",  # mid blue (a=10) with deep patches (9)
	"aa9aa9aa9aa9aa9a",  # depth variation
	"babababababababa",  # light blue wave line (b=11)
	"a9aa9aa9aa9aa9aa",  # post-wave depth
	"9aa9aa9aa9aa9aa9",  # deeper water column
	"aa9aa9aa9aa9aa9a",  # mid tone
	"cacacacacacacaca",  # cyan highlight wave (c=12)
	"a9aa9aa9aa9aa9aa",  # water surface
	"aa9aa9aa9aa9aa9a",  # mid depth
	"9aa9aa9aa9aa9aa9",  # deeper zone
	"dadadadadadadada",  # white foam wave (d=13)
	"a9aa9aa9aa9aa9aa",  # water surface
	"aa9aa9aa9aa9aa9a",  # mid depth
	"9aa9aa9aa9aa9aa9",  # deep patches
	"cacacacacacacaca",  # cyan highlight wave
	"a9aa9aa9aa9aa9aa",  # bottom surface
]

const COAST_ROWS: PackedStringArray = [
	"5555e555555aa8aa",  # sand (5=yellow) with pebble (e=14 grey)
	"5555555555aa8aaa",  # sand -> teal shore (8)
	"5555e55555aa8aaa",  # pebble
	"555545555aa8aaaa",  # wet sand transition (4=orange)
	"55555555aa8aaaaa",  # sand to water gradient
	"5555d555aa8aaaaa",  # shell fragment (d=13 white)
	"555555aa8aaaaaaa",  # more water
	"5555daa8aaaaaaaa",  # shell at water line
	"555aa8aaaaaaaaaa",  # water deepens to blue (a=10)
	"55aa8aaaaaacaaaa",  # cyan highlight wave (c=12)
	"5aa8aaaaaaaaaaaa",  # open water
	"aa8aaaaaaaaaaaaa",  # deep shore
	"a8aaaaaaaaaaaaaa",  # water dominant
	"8aaaaaaaaaaaaaaa",  # full water
	"aaaaaaaaaaaaaaaa",  # blue water
	"aaaaaaaaacaaaaaa",  # wave highlight
]

# Consolidated terrain lookup
const TERRAIN_PATTERNS: Dictionary = {
	"plains": {"width": 16, "height": 16, "rows": PLAINS_ROWS},
	"forest": {"width": 16, "height": 16, "rows": FOREST_ROWS},
	"hills": {"width": 16, "height": 16, "rows": HILLS_ROWS},
	"mountain": {"width": 16, "height": 16, "rows": MOUNTAIN_ROWS},
	"swamp": {"width": 16, "height": 16, "rows": SWAMP_ROWS},
	"desert": {"width": 16, "height": 16, "rows": DESERT_ROWS},
	"caves": {"width": 16, "height": 16, "rows": CAVES_ROWS},
	"water": {"width": 16, "height": 16, "rows": WATER_ROWS},
	"coast": {"width": 16, "height": 16, "rows": COAST_ROWS},
}

# =============================================================================
# FLAG ICON PATTERNS (16 × 16 binary masks)
# 0 = transparent, 1 = foreground pixel
# =============================================================================

const ICON_CROSS_STAR: PackedStringArray = [
	"0000010000000000",
	"0000111000000000",
	"0001111100000000",
	"0011111110000000",
	"0111111111000000",
	"1111111111100000",
	"0011111110000000",
	"0001111100000000",
	"0000111000000000",
	"0001111100000000",
	"0001111100000000",
	"0001111100000000",
	"0001111100000000",
	"0000111000000000",
	"0000010000000000",
	"0000000000000000",
]

const ICON_CRESCENT_MOON: PackedStringArray = [
	"0000000000000000",
	"0000001111000000",
	"0000111111110000",
	"0001111111110000",
	"0011110001111000",
	"0011100000111000",
	"0111000000000000",
	"0111000000000000",
	"0011110000111000",
	"0001111111110000",
	"0000111111110000",
	"0000001111000000",
	"0000000000000000",
	"0000000000000000",
	"0000000000000000",
	"0000000000000000",
]

const ICON_SUN_RADIANT: PackedStringArray = [
	"0000010000000000",
	"0000101000000000",
	"0100000001000000",
	"0010000010000000",
	"0001010100000000",
	"0011111110000000",
	"0111111111000000",
	"1111111111100000",
	"0111111111000000",
	"0011111110000000",
	"0001010100000000",
	"0010000010000000",
	"0100000001000000",
	"0000101000000000",
	"0000010000000000",
	"0000000000000000",
]

const ICON_SKULL: PackedStringArray = [
	"0000000000000000",
	"0000011110000000",
	"0001111111000000",
	"0011111111100000",
	"0110111110110000",
	"0110111110110000",
	"0111111111100000",
	"0011111111000000",
	"0001111110000000",
	"0001111110000000",
	"0011011011000000",
	"0001100011000000",
	"0000111110000000",
	"0000011100000000",
	"0000000000000000",
	"0000000000000000",
]

const ICON_TREE_SILHOUETTE: PackedStringArray = [
	"0000000000000000",
	"0000000000000000",
	"0000011110000000",
	"0001111111000000",
	"0011111111100000",
	"0111111111110000",
	"0111111111110000",
	"0011111111100000",
	"0001111111000000",
	"0000111110000000",
	"0000011110000000",
	"0000011110000000",
	"0000011110000000",
	"0000111110000000",
	"0000000000000000",
	"0000000000000000",
]

const ICON_HAMMER_ANVIL: PackedStringArray = [
	"0000000000000000",
	"0000000001100000",
	"0000000111100000",
	"0000001111100000",
	"0000011111110000",
	"0000001111100000",
	"0000001111100000",
	"0000001111100000",
	"0000011111100000",
	"0000111111000000",
	"0001111110000000",
	"0011111100000000",
	"0111111111000000",
	"0111111111000000",
	"0011111110000000",
	"0000000000000000",
]

const ICON_EYE_WATCHING: PackedStringArray = [
	"0000000000000000",
	"0000000000000000",
	"0001111111100000",
	"0011111111110000",
	"0111000000111000",
	"0110011110011000",
	"1110111111011100",
	"1110000000011100",
	"1110111111011100",
	"0110011110011000",
	"0111000000111000",
	"0011111111110000",
	"0001111111100000",
	"0000011111000000",
	"0000000000000000",
	"0000000000000000",
]

const FLAG_ICONS: Dictionary = {
	"cross_star": {"width": 16, "height": 16, "rows": ICON_CROSS_STAR},
	"crescent_moon": {"width": 16, "height": 16, "rows": ICON_CRESCENT_MOON},
	"sun_radiant": {"width": 16, "height": 16, "rows": ICON_SUN_RADIANT},
	"skull": {"width": 16, "height": 16, "rows": ICON_SKULL},
	"tree_silhouette": {"width": 16, "height": 16, "rows": ICON_TREE_SILHOUETTE},
	"hammer_anvil": {"width": 16, "height": 16, "rows": ICON_HAMMER_ANVIL},
	"eye_watching": {"width": 16, "height": 16, "rows": ICON_EYE_WATCHING},
}

# =============================================================================
# DEITY SYMBOL PATTERNS (16 × 16 binary masks, scaled to 32 × 32 at runtime)
# 0 = transparent/background, 1 = foreground/symbol
# =============================================================================

const SYMBOL_FORGE_HAMMER: PackedStringArray = [
	"0000000100010000",  # sparks at top
	"0000001010100000",  # sparks
	"0000011111100000",  # hammer head
	"0000001110000000",  # handle neck
	"0000011110000000",  # handle
	"0000111110000000",  # handle widens
	"0001111110000000",  # handle
	"0001111110000000",  # handle base
	"0011111111000000",  # transition to anvil
	"0001111111100000",  # anvil horn
	"0011111111110000",  # anvil top surface
	"0111111111111000",  # anvil body
	"0111111111111000",  # anvil body
	"0011111111110000",  # anvil base
	"0001111111100000",  # base
	"0000111111000000",  # bottom
]

const SYMBOL_WAR_SWORDS: PackedStringArray = [
	"0010000000000100",  # sword tips
	"0111000000001110",  # blades
	"0111100000011110",  # blades widen
	"0011110000111100",  # upper blades
	"0001111001111000",  # blades cross
	"0000111101110000",  # lower blades
	"0001111111110000",  # shield top (replaces center)
	"0001111111110000",  # shield
	"0001111111110000",  # shield
	"0001111111110000",  # shield bottom
	"0000111101110000",  # blades below shield
	"0001111001111000",  # blades
	"0011110000111100",  # lower blades
	"0111100000011110",  # blade tips
	"0111000000001110",  # points
	"0010000000000100",  # tips
]

const SYMBOL_NATURE_LEAF: PackedStringArray = [
	"0000000110000000",  # treetop
	"0000001110000000",  # small leaves
	"0000011111000000",  # canopy
	"0000111111100000",  # canopy widens
	"0001111111110000",  # full canopy
	"0011111111111000",  # dense
	"0011111111111000",  # full
	"0011111111111000",  # canopy body
	"0001111111110000",  # narrows
	"0000111111100000",  # canopy base
	"0000011111000000",  # branches converge
	"0000001110000000",  # trunk
	"0000001110000000",  # trunk
	"0000011111000000",  # roots spreading
	"0000011111000000",  # roots
	"0000001110000000",  # center root
]

const SYMBOL_TRADE_COIN: PackedStringArray = [
	"0000001110000000",  # scale hook
	"0111111111111100",  # scale beam
	"0110000000011000",  # chains left/right
	"0110000000011000",  # pans
	"0011000000011000",  # pan bowls
	"0000000000000000",  # spacer
	"0000011111000000",  # large coin outer
	"0001111111100000",  # coin
	"0011111111110000",  # coin
	"0111111111111000",  # coin
	"0111111111111000",  # coin
	"0011111111110000",  # coin
	"0001111111100000",  # coin
	"0000011111000000",  # coin inner
	"0000000000000000",
	"0000000000000000",
]

const SYMBOL_DEATH_SKULL: PackedStringArray = [
	"0000001110000000",  # skull crown
	"0000111111100000",  # skull top
	"0001111111110000",  # upper skull
	"0011011110110000",  # eye sockets (0s)
	"0011011110110000",  # eye sockets
	"0011111111110000",  # nose bridge
	"0001111111110000",  # mid skull
	"0000111111100000",  # narrows
	"0001111111110000",  # jaw
	"0011110011110000",  # teeth
	"0001100001100000",  # jaw gap
	"0110011110011000",  # crossed bones left
	"0011001110011000",  # bones cross
	"0001100110010000",  # bones lower
	"0000110011000000",  # bones
	"0000011110000000",  # bone tips
]

const SYMBOL_KNOWLEDGE_EYE: PackedStringArray = [
	"0001000000001000",  # light rays top
	"0010100000010100",  # rays
	"0100010001000100",  # diagonal rays
	"0000011111000000",  # brow
	"0001111111110000",  # eye socket top
	"0011111111111000",  # eye
	"0011110011111000",  # eye with pupil (center 0s)
	"0011111111111000",  # eye
	"0001111111110000",  # eye bottom
	"0000011111000000",  # under-eye
	"0000000000000000",  # spacer
	"0001111111100000",  # book cover top
	"0001111111100000",  # book
	"0001100001100000",  # book pages
	"0001111111100000",  # book cover bottom
	"0000000000000000",  # bottom
]

const DEITY_SYMBOLS: Dictionary = {
	"forge_hammer": {"width": 16, "height": 16, "rows": SYMBOL_FORGE_HAMMER},
	"war_swords": {"width": 16, "height": 16, "rows": SYMBOL_WAR_SWORDS},
	"nature_leaf": {"width": 16, "height": 16, "rows": SYMBOL_NATURE_LEAF},
	"trade_coin": {"width": 16, "height": 16, "rows": SYMBOL_TRADE_COIN},
	"death_skull": {"width": 16, "height": 16, "rows": SYMBOL_DEATH_SKULL},
	"knowledge_eye": {"width": 16, "height": 16, "rows": SYMBOL_KNOWLEDGE_EYE},
}

# Mapping from deity class ID to symbol key
const DEITY_CLASS_SYMBOL_MAP: Dictionary = {
	"forge_lord": "forge_hammer",
	"war_god": "war_swords",
	"nature_warden": "nature_leaf",
	"trade_lord": "trade_coin",
	"death_whisper": "death_skull",
	"knowledge_keeper": "knowledge_eye",
}

# Mapping from deity class ID to background color index
const DEITY_CLASS_COLORS: Dictionary = {
	"forge_lord": 4,       # orange
	"war_god": 3,          # red
	"nature_warden": 6,    # green
	"trade_lord": 5,       # yellow
	"death_whisper": 2,    # purple
	"knowledge_keeper": 11, # light blue
}

# =============================================================================
# FLAG PRESETS (background colors and icon choices)
# =============================================================================

const FLAG_PRESETS: Dictionary = {
	"ironhold": {
		"icon": "hammer_anvil",
		"primary": 15,  # dark grey
		"secondary": 5,  # yellow
	},
	"silverwood": {
		"icon": "tree_silhouette",
		"primary": 6,   # green
		"secondary": 13, # white
	},
	"northmark": {
		"icon": "cross_star",
		"primary": 10,  # blue
		"secondary": 13, # white
	},
	"bloodfang": {
		"icon": "skull",
		"primary": 3,   # red
		"secondary": 1,  # dark
	},
	"greenfields": {
		"icon": "sun_radiant",
		"primary": 5,   # yellow
		"secondary": 6,  # green
	},
	"deepgrot": {
		"icon": "crescent_moon",
		"primary": 2,   # purple
		"secondary": 12, # cyan
	},
	"watchers": {
		"icon": "eye_watching",
		"primary": 9,   # dark blue
		"secondary": 11, # light blue
	},
}

# =============================================================================
# BUILDING ICON PATTERNS (8 × 8)
# Each row is an 8-char hex string; each char is a palette index (0-15).
# =============================================================================

# --- Economic ---

const FARM_8x8: PackedStringArray = [
	"00111100",  # thatched roof peak
	"04444440",  # orange roof
	"04666640",  # green walls
	"04100140",  # dark door opening
	"06666660",  # base
	"06766760",  # crop row 1
	"06666660",  # crop row 2
	"06766760",  # crop row 3
]

const MINE_8x8: PackedStringArray = [
	"00011000",  # rail/track
	"00e1e000",  # wood supports (e=grey) with dark entrance (1)
	"00e1e000",  # mine tunnel
	"00e1e000",  # tunnel deep
	"00111000",  # ground line
	"04444000",  # ore cart (orange)
	"00440000",  # cart wheels
	"00044000",  # wheel detail
]

const LUMBER_CAMP_8x8: PackedStringArray = [
	"00100100",  # branch/leaves
	"06666600",  # foliage (green)
	"06666600",  # foliage
	"00100100",  # branch cross
	"00660000",  # trunk
	"04440000",  # axe blade (orange)
	"00400000",  # axe handle
	"00000000",
]

const QUARRY_8x8: PackedStringArray = [
	"00000000",
	"00e0e000",  # stone blocks (e=grey)
	"0eeee000",  # stone pile
	"0eeee000",  # more stone
	"000ee000",  # 
	"0000e000",  # stray block
	"00000000",
	"00000000",
]

const HARBOR_8x8: PackedStringArray = [
	"00a0a000",  # water (a=blue)
	"0aa0aa00",  # water
	"00100100",  # dock posts
	"04444400",  # dock planks (orange)
	"0a1a1a00",  # water lapping at dock
	"0aa0aa00",  # water
	"00000000",
	"00000000",
]

const MARKET_8x8: PackedStringArray = [
	"05555500",  # yellow awning top
	"05555500",  # awning
	"04444440",  # stall counter
	"04100140",  # stall opening (dark)
	"04666640",  # goods underneath
	"00000000",
	"00000000",
	"00000000",
]

const WORKSHOP_8x8: PackedStringArray = [
	"00010000",  # gear pivot
	"04444000",  # gear top teeth
	"04444000",  # gear body
	"00010000",  # gear center
	"04444000",  # workbench
	"04444000",  # workbench
	"00044000",  # bench legs
	"00044000",  # legs
]

const GRANARY_8x8: PackedStringArray = [
	"06666660",  # silo dome (green)
	"06666660",  # silo
	"04444440",  # roof (orange)
	"04444440",  # storage
	"04444440",  # storage
	"04444440",  # storage
	"00111100",  # base
	"00000000",
]

const IRRIGATION_FARM_8x8: PackedStringArray = [
	"06666660",  # crop row
	"0a0a0a00",  # irrigation channel (blue)
	"06666660",  # crop row
	"0a0a0a00",  # irrigation
	"06666660",  # crop row
	"0a0a0a00",  # irrigation
	"06666660",  # crop row
	"00000000",
]

const FORGE_8x8: PackedStringArray = [
	"00040000",  # flame top (orange)
	"00444000",  # fire
	"04444000",  # forge fire
	"04444000",  # forge body
	"00111000",  # anvil
	"00111000",  # anvil base
	"00010000",  # pedestal
	"00000000",
]

# --- Military ---

const FORT_8x8: PackedStringArray = [
	"01000100",  # corner battlements
	"01000100",  # battlements
	"01111100",  # red wall top
	"03133100",  # wall with windows
	"04666400",  # orange gate
	"01111100",  # wall
	"01111100",  # base
	"00000000",
]

const CASTLE_8x8: PackedStringArray = [
	"01000100",  # tower tops
	"01000100",  # towers
	"03133130",  # wall with tower windows (blue)
	"03133130",  # wall
	"04666640",  # orange gate
	"01111110",  # wall
	"01111110",  # base
	"00000000",
]

const BARRACKS_8x8: PackedStringArray = [
	"00111000",  # roof peak
	"01111100",  # red roof
	"13131310",  # wall with windows (blue)
	"11111110",  # wall
	"01111100",  # lower wall
	"00111000",  # base
	"00010000",  # flag pole
	"00000000",
]

const GARRISON_8x8: PackedStringArray = [
	"00111000",  # roof
	"01111100",  # red roof
	"13133310",  # wall with windows
	"11111110",  # lower wall
	"01111100",  # base
	"00111000",  # 
	"00000000",
	"00000000",
]

# --- Religious ---

const SHRINE_8x8: PackedStringArray = [
	"00010000",  # spire top
	"00111000",  # spire
	"05555500",  # golden roof
	"05000500",  # wall pillars
	"05000500",  # wall
	"05555500",  # base
	"00010000",  # center mark
	"00000000",
]

const TEMPLE_8x8: PackedStringArray = [
	"00500500",  # top tier spires
	"05500550",  # second tier
	"05555550",  # roof
	"05000050",  # wall pillars
	"05055050",  # window central
	"05e00e50",  # wall with stone detail
	"05555550",  # base
	"00000000",
]

const MONUMENT_8x8: PackedStringArray = [
	"00010000",  # top ornament
	"00010000",  # pillar
	"00111000",  # upper section
	"00111000",  # pillar
	"01111100",  # mid section
	"01111100",  # pillar
	"11111110",  # wide base
	"00000000",
]

# --- Infrastructure ---

const LIBRARY_8x8: PackedStringArray = [
	"00000000",
	"00111100",  # shelf top
	"01444100",  # books (blue theme)
	"01444100",  # books
	"01444100",  # books
	"01444100",  # books
	"00111100",  # shelf bottom
	"00000000",
]

# Consolidated building pattern lookup
const BUILDING_PATTERNS: Dictionary = {
	"farm": {"width": 8, "height": 8, "rows": FARM_8x8},
	"mine": {"width": 8, "height": 8, "rows": MINE_8x8},
	"lumber_camp": {"width": 8, "height": 8, "rows": LUMBER_CAMP_8x8},
	"quarry": {"width": 8, "height": 8, "rows": QUARRY_8x8},
	"harbor": {"width": 8, "height": 8, "rows": HARBOR_8x8},
	"market": {"width": 8, "height": 8, "rows": MARKET_8x8},
	"workshop": {"width": 8, "height": 8, "rows": WORKSHOP_8x8},
	"granary": {"width": 8, "height": 8, "rows": GRANARY_8x8},
	"irrigation_farm": {"width": 8, "height": 8, "rows": IRRIGATION_FARM_8x8},
	"forge": {"width": 8, "height": 8, "rows": FORGE_8x8},
	"fort": {"width": 8, "height": 8, "rows": FORT_8x8},
	"castle": {"width": 8, "height": 8, "rows": CASTLE_8x8},
	"barracks": {"width": 8, "height": 8, "rows": BARRACKS_8x8},
	"garrison": {"width": 8, "height": 8, "rows": GARRISON_8x8},
	"shrine": {"width": 8, "height": 8, "rows": SHRINE_8x8},
	"temple": {"width": 8, "height": 8, "rows": TEMPLE_8x8},
	"monument": {"width": 8, "height": 8, "rows": MONUMENT_8x8},
	"library": {"width": 8, "height": 8, "rows": LIBRARY_8x8},
}

# =============================================================================
# TECH ICON PATTERNS (8 × 8)
# =============================================================================

# --- Stone Age ---

const BASIC_WEAPONS_8x8: PackedStringArray = [
	"00010000",
	"00010000",
	"eee10000",
	"eee10000",
	"00010000",
	"00110000",
	"00110000",
	"00000000",
]

const BASIC_FARMING_8x8: PackedStringArray = [
	"00010000",
	"00010000",
	"00010000",
	"eee10000",
	"eee00000",
	"00ee0000",
	"000e0000",
	"00000000",
]

const TRIBAL_CRAFTING_8x8: PackedStringArray = [
	"01111100",
	"01000100",
	"01000100",
	"01111100",
	"00010000",
	"00111000",
	"00111000",
	"00000000",
]

# --- Bronze Age ---

const BRONZE_WEAPONS_8x8: PackedStringArray = [
	"00111000",
	"00111000",
	"00111000",
	"00111000",
	"00111000",
	"00010000",
	"00010000",
	"00000000",
]

const POTTERY_8x8: PackedStringArray = [
	"00111000",
	"01111100",
	"01111100",
	"01111100",
	"01111100",
	"00111000",
	"01111100",
	"00000000",
]

const MASONRY_8x8: PackedStringArray = [
	"01111110",
	"00000000",
	"01111110",
	"01000010",
	"01111110",
	"00000000",
	"01111110",
	"00000000",
]

# --- Iron Age ---

const IRON_WEAPONS_8x8: PackedStringArray = [
	"00111000",
	"01111100",
	"01111100",
	"01111100",
	"01111100",
	"00010000",
	"00010000",
	"00000000",
]

const WRITING_8x8: PackedStringArray = [
	"00000000",
	"00111100",
	"01444100",
	"01444100",
	"01444100",
	"01444100",
	"00111100",
	"00000000",
]

const FORTIFICATIONS_8x8: PackedStringArray = [
	"01111110",
	"01111110",
	"01000010",
	"01000010",
	"01000010",
	"01111110",
	"01111110",
	"00000000",
]

const COINAGE_8x8: PackedStringArray = [
	"00011000",
	"01111100",
	"11111110",
	"11111110",
	"11111110",
	"01111100",
	"00011000",
	"00000000",
]

# --- Steel Age ---

const STEEL_WEAPONS_8x8: PackedStringArray = [
	"00111000",
	"01111100",
	"01111100",
	"01111100",
	"01111100",
	"00111000",
	"00010000",
	"00010000",
]

const ARCHITECTURE_8x8: PackedStringArray = [
	"01111110",
	"01000010",
	"01111110",
	"01000010",
	"01111110",
	"01000010",
	"01111110",
	"00000000",
]

const NAVIGATION_8x8: PackedStringArray = [
	"00111000",
	"01000100",
	"10000010",
	"10011010",
	"10000010",
	"01000100",
	"00111000",
	"00000000",
]

# --- Arcane Age ---

const ENCHANTING_8x8: PackedStringArray = [
	"00010000",
	"00111000",
	"01111100",
	"11111110",
	"01111100",
	"00111000",
	"00010000",
	"00000000",
]

const GUNPOWDER_8x8: PackedStringArray = [
	"00400400",
	"04044040",
	"40400404",
	"04400440",
	"00400400",
	"04044040",
	"40400404",
	"00000000",
]

# Consolidated tech pattern lookup
const TECH_PATTERNS: Dictionary = {
	"basic_weapons": {"width": 8, "height": 8, "rows": BASIC_WEAPONS_8x8},
	"basic_farming": {"width": 8, "height": 8, "rows": BASIC_FARMING_8x8},
	"tribal_crafting": {"width": 8, "height": 8, "rows": TRIBAL_CRAFTING_8x8},
	"bronze_weapons": {"width": 8, "height": 8, "rows": BRONZE_WEAPONS_8x8},
	"pottery": {"width": 8, "height": 8, "rows": POTTERY_8x8},
	"masonry": {"width": 8, "height": 8, "rows": MASONRY_8x8},
	"iron_weapons": {"width": 8, "height": 8, "rows": IRON_WEAPONS_8x8},
	"writing": {"width": 8, "height": 8, "rows": WRITING_8x8},
	"fortifications": {"width": 8, "height": 8, "rows": FORTIFICATIONS_8x8},
	"coinage": {"width": 8, "height": 8, "rows": COINAGE_8x8},
	"steel_weapons": {"width": 8, "height": 8, "rows": STEEL_WEAPONS_8x8},
	"architecture": {"width": 8, "height": 8, "rows": ARCHITECTURE_8x8},
	"navigation": {"width": 8, "height": 8, "rows": NAVIGATION_8x8},
	"enchanting": {"width": 8, "height": 8, "rows": ENCHANTING_8x8},
	"gunpowder": {"width": 8, "height": 8, "rows": GUNPOWDER_8x8},
}

# =============================================================================
# LEADER FACE PATTERNS (8 × 8)
# One per race: 2 eyes (white with dark pupil), skin matching race, racial feature.
# Palette indices: 0=transparent, 1=dark, 3=red, 4=peach(skin), 5=yellow,
#   6=green, 7=dark_green, 9=dark_blue, 11=light_blue, 13=white, 14=grey, 15=dark_grey
# =============================================================================

const HUMAN_FACE: PackedStringArray = [
	"00111100",  # dark brown hair
	"01111110",
	"44d1d144",  # eyes: white(d=13) with dark(1) pupils
	"44444444",  # skin (peach)
	"44444444",
	"44f44f44",  # neutral mouth (dark grey)
	"44444444",
	"00000000",
]

const DWARF_FACE: PackedStringArray = [
	"00111100",  # dark hair/helmet
	"01111110",
	"44d1d144",  # eyes
	"44444444",  # skin
	"444e4444",  # nose with beard starting (e=grey)
	"4eeeeee4",  # massive full beard
	"4eeeeee4",  # beard continues
	"00eee100",  # beard tip
]

const ELF_FACE: PackedStringArray = [
	"00555500",  # golden hair
	"15555551",  # hair with ear tips showing
	"44d1d144",  # eyes
	"14444441",  # pointed ears at edges
	"44444444",  # skin
	"44d44d44",  # graceful smile (white teeth)
	"44444444",
	"00555500",  # golden hair at bottom
]

const ORC_FACE: PackedStringArray = [
	"00111100",  # dark hair
	"06666660",
	"44d1d144",  # eyes
	"66666666",  # green skin
	"66444666",  # orange nose/snout
	"66d44d66",  # white tusks at mouth corners
	"66666666",  # green chin
	"00000000",
]

const HALFLING_FACE: PackedStringArray = [
	"00111100",  # curly dark hair
	"01111110",
	"44d1d144",  # eyes
	"44433444",  # rosy cheeks (3=red)
	"44444444",
	"44d44d44",  # big cheerful grin
	"44444444",
	"00000000",
]

const GOBLIN_FACE: PackedStringArray = [
	"00111100",  # dark hair
	"06666660",
	"4441d144",  # squinty/angled eyes (menacing)
	"66666666",  # green skin
	"66444666",  # snout
	"66d0d466",  # sharp teeth visible (d=white)
	"66666666",  # chin
	"00000000",
]

const TROLL_FACE: PackedStringArray = [
	"00111100",  # dark hair
	"07777770",
	"44d1d144",  # eyes
	"77777777",  # dark green skin
	"77777777",  # 
	"77f44f77",  # mouth with teeth (f=dark, 4=orange)
	"77777777",
	"00000000",
]

const OGRE_FACE: PackedStringArray = [
	"00111100",  # dark hair
	"0ffffff0",
	"44d1d144",  # eyes
	"ffffffff",  # dark grey skin
	"fff33fff",  # angry furrowed brow (red)
	"ff3ff3ff",  # angry red mouth
	"ffffffff",
	"00000000",
]

const GNOME_FACE: PackedStringArray = [
	"00b9b000",  # pointed blue hat (b=11 light blue, 9=9 dark blue)
	"0b999b00",  # hat
	"44d1d144",  # eyes
	"44444444",  # skin
	"44433444",  # big red nose (3)
	"44d44d44",  # cheerful grin (white teeth)
	"44444444",
	"00000000",
]

# Consolidated leader face lookup (race_id -> pattern)
const LEADER_FACES: Dictionary = {
	"human": {"width": 8, "height": 8, "rows": HUMAN_FACE},
	"dwarf": {"width": 8, "height": 8, "rows": DWARF_FACE},
	"elf": {"width": 8, "height": 8, "rows": ELF_FACE},
	"orc": {"width": 8, "height": 8, "rows": ORC_FACE},
	"halfling": {"width": 8, "height": 8, "rows": HALFLING_FACE},
	"goblin": {"width": 8, "height": 8, "rows": GOBLIN_FACE},
	"troll": {"width": 8, "height": 8, "rows": TROLL_FACE},
	"ogre": {"width": 8, "height": 8, "rows": OGRE_FACE},
	"gnome": {"width": 8, "height": 8, "rows": GNOME_FACE},
}
