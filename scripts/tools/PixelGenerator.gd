@tool
class_name PixelGenerator
extends Node
# =============================================================================
# Pixel art asset generator for Thronehold.
# Attach to a Node in editor and call generate_all_assets() to produce PNGs.
# =============================================================================

# Max reasonable dimensions to prevent memory issues
const MAX_DIM: int = 256

# =============================================================================
# _ready() — Print usage instructions when script is first loaded
# =============================================================================

func _ready() -> void:
	print("=".repeat(56))
	print("  PixelGenerator — Thronehold pixel art pipeline")
	print("=".repeat(56))
	print("  Usage (in editor):")
	print("    $PixelGenerator.generate_all_assets()")
	print("    $PixelGenerator.generate_terrain_tile('plains')")
	print("    $PixelGenerator.generate_nation_flag('ironhold', primary_idx, secondary_idx)")
	print("    $PixelGenerator.generate_nation_flag('cross_star', 10, 13)")
	print("    $PixelGenerator.generate_deity_symbol('forge_lord')")
	print("    $PixelGenerator.generate_building_icon('farm')")
	print("    $PixelGenerator.generate_tech_icon('writing')")
	print("    $PixelGenerator.generate_leader_portrait('human')")
	print("")
	print("  Output dirs (relative to res://):")
	print("    assets/tiles/     — 16×16 terrain tiles")
	print("    assets/flags/     — 32×16 nation flags")
	print("    assets/symbols/   — 32×32 deity symbols")
	print("    assets/buildings/ — 8×8 building icons")
	print("    assets/tech/      — 8×8 tech icons")
	print("    assets/portraits/ — 8×8 leader face portraits")
	print("==".repeat(56))

# =============================================================================
# CORE UTILITY: Convert color-index array to Image
# =============================================================================

func color_index_to_image(
	pixels: Array[int],
	palette: Dictionary,
	width: int,
	height: int
) -> Image:
	"""Convert a flat 1D Array[int] of palette indices into an RGBA8 Image.
	
	Index 0 is transparent. Each pixel is looked up in the palette Dictionary
	(which maps int -> Color hex string). If a palette entry is missing or
	empty, that pixel is rendered as fully transparent.
	"""
	# Clamp dimensions
	width = clamp(width, 1, MAX_DIM)
	height = clamp(height, 1, MAX_DIM)
	
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	if img.is_empty():
		push_error("PixelGenerator: Failed to create Image (%dx%d)" % [width, height])
		return img
	
	var expected_len = width * height
	
	for idx in range(expected_len):
		var px: int = 0
		if idx < pixels.size():
			px = pixels[idx]
		
		var x = idx % width
		var y = idx / width
		
		if px == 0 or not palette.has(px):
			# Transparent
			img.set_pixel(x, y, Color(0, 0, 0, 0))
		else:
			var hex_str: String = palette[px]
			if hex_str.is_empty():
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				img.set_pixel(x, y, Color(hex_str))
	
	return img

# =============================================================================
# PARSE ROWS: Convert PixelPatterns row data to flat Array[int]
# =============================================================================

func _parse_pattern_rows(pattern: Dictionary) -> Array[int]:
	"""Convert a pattern's 'rows' (PackedStringArray) into a flat Array[int].
	
	Supports hex encoding (palette indices 0-15) and binary encoding (0/1).
	"""
	var rows: PackedStringArray = pattern.get("rows", PackedStringArray())
	var result: Array[int] = []
	
	for row in rows:
		for ch in row:
			if ch == "0" or ch == "1":
				result.append(int(ch))
			else:
				result.append(int("0x" + ch))
	
	return result

# =============================================================================
# SCALE 1D PIXEL ARRAY (nearest-neighbor, factor 2)
# =============================================================================

func _scale_pixels_2x(
	src: Array[int],
	src_width: int,
	src_height: int
) -> Array[int]:
	"""Scale a flat pixel array by factor 2 using nearest neighbor."""
	var dst_width = src_width * 2
	var dst_height = src_height * 2
	var result: Array[int] = []
	result.resize(dst_width * dst_height)
	
	for sy in range(src_height):
		for sx in range(src_width):
			var src_idx = sy * src_width + sx
			var val = src[src_idx] if src_idx < src.size() else 0
			
			# Each source pixel becomes a 2x2 block
			var dx0 = sx * 2
			var dy0 = sy * 2
			
			for dy in range(2):
				for dx in range(2):
					var dst_idx = (dy0 + dy) * dst_width + (dx0 + dx)
					if dst_idx < result.size():
						result[dst_idx] = val
	
	return result

# =============================================================================
# GENERATE TERRAIN TILE
# =============================================================================

func generate_terrain_tile(terrain_type: String) -> Image:
	"""Generate a 16×16 terrain tile image from PixelPatterns data."""
	var pattern: Dictionary = PixelPatterns.TERRAIN_PATTERNS.get(terrain_type)
	
	if pattern.is_empty():
		push_error("PixelGenerator: Unknown terrain type '%s'" % terrain_type)
		return Image.create(16, 16, false, Image.FORMAT_RGBA8)
	
	var pixels = _parse_pattern_rows(pattern)
	var img = color_index_to_image(
		pixels,
		PixelPatterns.PALETTE,
		pattern["width"],
		pattern["height"]
	)
	return img

# =============================================================================
# PALETTE SWAP IMAGE — DF-style material recoloring
# Matches each non-transparent pixel to its PALETTE index, then replaces
# palette indices 1-9 with the corresponding ramp colors.
# Indices 10-15 keep their default PALETTE values (highlights/shadows).
# =============================================================================

func palette_swap_image(source: Image, ramp: Array) -> Image:
	if source.is_empty() or ramp.size() < 9:
		push_error("PixelGenerator: palette_swap_image requires valid source and 9-color ramp")
		return source
	
	var w = source.get_width()
	var h = source.get_height()
	var result = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	# Build reverse palette lookup: "#rrggbb" -> index
	var reverse_palette: Dictionary = {}
	for idx in range(1, PixelPatterns.PALETTE.size()):
		var hex_str: String = PixelPatterns.PALETTE.get(idx, "")
		if not hex_str.is_empty():
			reverse_palette[hex_str] = idx
	
	# Pre-parse ramp colors into Color objects
	var ramp_colors: Array[Color] = []
	for hex_str in ramp:
		ramp_colors.append(Color(hex_str))
	
	for y in range(h):
		for x in range(w):
			var pixel: Color = source.get_pixel(x, y)
			if pixel.a < 0.01:
				# Transparent — keep as-is (index 0)
				continue
			
			var hex: String = pixel.to_html(false)
			if not hex.begins_with("#"):
				hex = "#" + hex
			
			var palette_idx: int = reverse_palette.get(hex, -1)
			if palette_idx > 0 and palette_idx <= ramp_colors.size():
				result.set_pixel(x, y, ramp_colors[palette_idx - 1])
			else:
				# High-index palette color (10-15) or unmatched — keep original
				result.set_pixel(x, y, pixel)
	
	return result


# =============================================================================
# GENERATE TERRAIN TILE WITH MATERIAL
# Convenience: generates a terrain tile then applies material palette swap.
# Returns the base terrain tile if material_key is empty or not found.
# =============================================================================

func generate_material_terrain_tile(terrain_type: String, material_key: String) -> Image:
	var base = generate_terrain_tile(terrain_type)
	if base.is_empty() or material_key.is_empty():
		return base
	
	var ramp: Array = PixelPatterns.MATERIAL_RAMPS.get(material_key, [])
	if ramp.is_empty():
		return base
	
	return palette_swap_image(base, ramp)


# =============================================================================
# GENERATE NATION FLAG
# =============================================================================

func generate_nation_flag(
	flag_icon_name: String,
	primary_color_idx: int,
	secondary_color_idx: int
) -> Image:
	"""Generate a 32×16 flag with two-color background + centered icon.
	
	The flag is split vertically: left half = primary, right half = secondary.
	The icon pattern is overlayed in white (index 13) in the center.
	"""
	var flag_w = 32
	var flag_h = 16
	var img = Image.create(flag_w, flag_h, false, Image.FORMAT_RGBA8)
	
	if img.is_empty():
		push_error("PixelGenerator: Failed to create flag image")
		return img
	
	# Draw two-color background
	for y in range(flag_h):
		for x in range(flag_w):
			var color_idx = primary_color_idx if x < flag_w / 2 else secondary_color_idx
			var hex_str: String = PixelPatterns.PALETTE.get(color_idx, "")
			if hex_str.is_empty():
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				img.set_pixel(x, y, Color(hex_str))
	
	# Get icon pattern
	var icon_pattern: Dictionary = PixelPatterns.FLAG_ICONS.get(flag_icon_name)
	if icon_pattern.is_empty():
		push_warning("PixelGenerator: Unknown flag icon '%s'" % flag_icon_name)
		return img
	
	var icon_pixels = _parse_pattern_rows(icon_pattern)
	
	# Scale icon 2x (from 16×16 source to 32×32) but we only need 32×16
	# Clamp to the flag dimensions
	var scaled = _scale_pixels_2x(icon_pixels, icon_pattern["width"], icon_pattern["height"])
	
	# Overlay icon centered on flag (offset to fit 32×16 — we take top half of scaled)
	var src_w = icon_pattern["width"] * 2   # 32
	var src_h = icon_pattern["height"] * 2  # 32
	
	var offset_x = 0   # Full width fits
	var offset_y = (flag_h - min(src_h, flag_h)) / 2  # Center vertically
	
	for y in range(min(src_h, flag_h)):
		for x in range(min(src_w, flag_w)):
			var si = y * src_w + x
			if si < scaled.size() and scaled[si] == 1:
				var white_hex: String = PixelPatterns.PALETTE.get(13, "#f4f4f4")
				img.set_pixel(offset_x + x, offset_y + y, Color(white_hex))
	
	return img

# =============================================================================
# GENERATE DEITY SYMBOL
# =============================================================================

func generate_deity_symbol(class_id: String) -> Image:
	"""Generate a 32×32 deity symbol with colored background and white symbol.
	
	Maps class_id to a symbol pattern via PixelPatterns.DEITY_CLASS_SYMBOL_MAP.
	The background color comes from DEITY_CLASS_COLORS.
	"""
	var symbol_w = 32
	var symbol_h = 32
	var img = Image.create(symbol_w, symbol_h, false, Image.FORMAT_RGBA8)
	
	if img.is_empty():
		push_error("PixelGenerator: Failed to create symbol image")
		return img
	
	# Get background color
	var bg_color_idx: int = PixelPatterns.DEITY_CLASS_COLORS.get(class_id, 1)
	var bg_hex: String = PixelPatterns.PALETTE.get(bg_color_idx, "#1a1c2c")
	var bg_color = Color(bg_hex)
	
	# Fill background
	for y in range(symbol_h):
		for x in range(symbol_w):
			img.set_pixel(x, y, bg_color)
	
	# Get symbol pattern
	var symbol_key: String = PixelPatterns.DEITY_CLASS_SYMBOL_MAP.get(class_id, "")
	var symbol_pattern: Dictionary = PixelPatterns.DEITY_SYMBOLS.get(symbol_key)
	if symbol_pattern.is_empty():
		push_warning("PixelGenerator: No symbol pattern for class '%s'" % class_id)
		return img
	
	var symbol_pixels = _parse_pattern_rows(symbol_pattern)
	
	# Scale 2x (16×16 → 32×32)
	var scaled = _scale_pixels_2x(symbol_pixels, 16, 16)
	
	# Overlay symbol in white (index 13)
	var white_hex: String = PixelPatterns.PALETTE.get(13, "#f4f4f4")
	for y in range(symbol_h):
		for x in range(symbol_w):
			var si = y * symbol_w + x
			if si < scaled.size() and scaled[si] == 1:
				img.set_pixel(x, y, Color(white_hex))
	
	return img

# =============================================================================
# GENERATE BUILDING ICON
# =============================================================================

func generate_building_icon(building_id: String) -> Image:
	"""Generate an 8×8 building icon from PixelPatterns data."""
	var pattern: Dictionary = PixelPatterns.BUILDING_PATTERNS.get(building_id)
	if pattern.is_empty():
		push_error("PixelGenerator: Unknown building id '%s'" % building_id)
		return Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var pixels = _parse_pattern_rows(pattern)
	var img = color_index_to_image(
		pixels,
		PixelPatterns.PALETTE,
		pattern["width"],
		pattern["height"]
	)
	return img

# =============================================================================
# GENERATE BUILDING ICON WITH MATERIAL
# Convenience: generates a building icon then applies material palette swap.
# =============================================================================

func generate_material_building_icon(building_id: String, material_key: String) -> Image:
	var base = generate_building_icon(building_id)
	if base.is_empty() or material_key.is_empty():
		return base
	
	var ramp: Array = PixelPatterns.MATERIAL_RAMPS.get(material_key, [])
	if ramp.is_empty():
		return base
	
	return palette_swap_image(base, ramp)


# =============================================================================
# GENERATE TECH ICON
# =============================================================================

func generate_tech_icon(tech_id: String) -> Image:
	"""Generate an 8×8 tech icon from PixelPatterns data."""
	var pattern: Dictionary = PixelPatterns.TECH_PATTERNS.get(tech_id)
	if pattern.is_empty():
		push_error("PixelGenerator: Unknown tech id '%s'" % tech_id)
		return Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var pixels = _parse_pattern_rows(pattern)
	var img = color_index_to_image(
		pixels,
		PixelPatterns.PALETTE,
		pattern["width"],
		pattern["height"]
	)
	return img

# =============================================================================
# GENERATE LEADER PORTRAIT
# =============================================================================

func generate_leader_portrait(race: String) -> Image:
	"""Generate an 8x8 leader face portrait from PixelPatterns data.
	
	Each face has: 2 eyes (white sclera with dark pupil), skin matching the
	race's color, and a distinguishing racial feature (beard, tusks, etc.).
	"""
	var pattern: Dictionary = PixelPatterns.LEADER_FACES.get(race)
	if pattern.is_empty():
		push_error("PixelGenerator: Unknown race '%s'" % race)
		return Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var pixels = _parse_pattern_rows(pattern)
	var img = color_index_to_image(
		pixels,
		PixelPatterns.PALETTE,
		pattern["width"],
		pattern["height"]
	)
	return img

# =============================================================================
# SAVE TO PNG
# =============================================================================

func save_to_png(image: Image, path: String) -> void:
	"""Save an Image as PNG to the given res:// path."""
	if image.is_empty():
		push_error("PixelGenerator: Cannot save empty image to '%s'" % path)
		return
	
	var err = image.save_png(path)
	if err != OK:
		push_error("PixelGenerator: Failed to save PNG '%s' (error %d)" % [path, err])
	else:
		print("  [OK] Saved: %s" % path)

# =============================================================================
# ENSURE DIRECTORY EXISTS
# =============================================================================

func _ensure_dir(path: String) -> void:
	"""Ensure a directory exists, creating it (and parents) if needed."""
	var err = DirAccess.make_dir_recursive_absolute(path)
	if err != OK:
		push_error("PixelGenerator: Failed to create directory '%s' (error %d)" % [path, err])

# =============================================================================
# GENERATE ALL ASSETS
# =============================================================================

func generate_all_assets(output_dir: String = "res://assets/") -> void:
	"""Generate all terrain tiles, flag presets, deity symbols, building icons, and tech icons."""
	print("")
	print("==".repeat(56))
	print("  PixelGenerator: Generating all assets...")
	print("  Output: %s" % output_dir)
	print("==".repeat(56))
	
	var total_files = 0
	var error_count = 0
	
	# --- Terrain tiles ---
	var tiles_dir = output_dir.path_join("tiles")
	_ensure_dir(tiles_dir)
	
	print("\n--- Terrain Tiles (%s) ---" % tiles_dir)
	var terrain_types: Array[String] = []
	for key in PixelPatterns.TERRAIN_PATTERNS:
		terrain_types.append(key)
	terrain_types.sort()
	
	for t in terrain_types:
		var img = generate_terrain_tile(t)
		if img.is_empty():
			error_count += 1
			continue
		save_to_png(img, tiles_dir.path_join(t + ".png"))
		total_files += 1
	
	# --- Flag presets ---
	var flags_dir = output_dir.path_join("flags")
	_ensure_dir(flags_dir)
	
	print("\n--- Nation Flags (%s) ---" % flags_dir)
	var flag_names: Array[String] = []
	for key in PixelPatterns.FLAG_PRESETS:
		flag_names.append(key)
	flag_names.sort()
	
	for fname in flag_names:
		var preset: Dictionary = PixelPatterns.FLAG_PRESETS[fname]
		var img = generate_nation_flag(
			preset["icon"],
			preset["primary"],
			preset["secondary"]
		)
		if img.is_empty():
			error_count += 1
			continue
		save_to_png(img, flags_dir.path_join(fname + ".png"))
		total_files += 1
	
	# --- Deity symbols ---
	var symbols_dir = output_dir.path_join("symbols")
	_ensure_dir(symbols_dir)
	
	print("\n--- Deity Symbols (%s) ---" % symbols_dir)
	var class_ids: Array[String] = []
	for key in PixelPatterns.DEITY_CLASS_SYMBOL_MAP:
		class_ids.append(key)
	class_ids.sort()
	
	for cid in class_ids:
		var img = generate_deity_symbol(cid)
		if img.is_empty():
			error_count += 1
			continue
		save_to_png(img, symbols_dir.path_join(cid + ".png"))
		total_files += 1
	
	# --- Building icons ---
	var buildings_dir = output_dir.path_join("buildings")
	_ensure_dir(buildings_dir)
	
	print("\n--- Building Icons (%s) ---" % buildings_dir)
	var building_ids: Array[String] = []
	for key in PixelPatterns.BUILDING_PATTERNS:
		building_ids.append(key)
	building_ids.sort()
	
	for bid in building_ids:
		var img = generate_building_icon(bid)
		if img.is_empty():
			error_count += 1
			continue
		save_to_png(img, buildings_dir.path_join(bid + ".png"))
		total_files += 1
	
	# --- Tech icons ---
	var tech_dir = output_dir.path_join("tech")
	_ensure_dir(tech_dir)
	
	print("\n--- Tech Icons (%s) ---" % tech_dir)
	var tech_ids: Array[String] = []
	for key in PixelPatterns.TECH_PATTERNS:
		tech_ids.append(key)
	tech_ids.sort()
	
	for tid in tech_ids:
		var img = generate_tech_icon(tid)
		if img.is_empty():
			error_count += 1
			continue
		save_to_png(img, tech_dir.path_join(tid + ".png"))
		total_files += 1
	
	# --- Leader portraits ---
	var portraits_dir = output_dir.path_join("portraits")
	_ensure_dir(portraits_dir)
	
	print("\n--- Leader Portraits (%s) ---" % portraits_dir)
	var race_ids: Array[String] = []
	for key in PixelPatterns.LEADER_FACES:
		race_ids.append(key)
	race_ids.sort()
	
	for rid in race_ids:
		var img = generate_leader_portrait(rid)
		if img.is_empty():
			error_count += 1
			continue
		save_to_png(img, portraits_dir.path_join(rid + ".png"))
		total_files += 1
	
	# --- Summary ---
	print("")
	print("-=".repeat(56))
	print("  Generation complete: %d files saved, %d errors" % [total_files, error_count])
	if error_count > 0:
		push_warning("PixelGenerator: %d asset(s) failed to generate." % error_count)
	print("-=".repeat(56))
	print("")
