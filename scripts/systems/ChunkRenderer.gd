class_name ChunkRenderer
extends Node2D
# =============================================================================
# DF-style chunk-based renderer with three explicit Z-layers:
#
#   Layer 0 (bottom): Terrain — per-terrain MultiMeshInstance2D children under
#                     a _terrain_layer Node2D container. Each terrain type gets
#                     its own MultiMesh so distinct textures are preserved.
#                     Instance colors come from ColonyData.TERRAINS + nation tint.
#
#   Layer 1 (middle): Buildings — single MultiMeshInstance2D for building
#                     sprites atop terrain. Instance colors by building category.
#
#   Layer 2 (top):    Creatures — single MultiMeshInstance2D for faction/
#                     monster sprites atop everything. Instance colors by type.
#
# Integer TILE_SIZE (32) for crisp pixel art at every zoom level.
# Includes time-based water/coast color animation.
# =============================================================================

const CHUNK_SIZE: int = 32
const TILE_SIZE: int = 32

# Layer storage: Vector2i(cx, cy) -> node references
var _terrain_containers: Dictionary = {}   # Node2D containers holding per-terrain MultiMeshInstance2D children
var _building_layers: Dictionary = {}      # MultiMeshInstance2D for all buildings in chunk
var _creature_layers: Dictionary = {}      # MultiMeshInstance2D for all creatures in chunk

var _chunk_visible_cache: Dictionary = {}
var _texture_cache: Dictionary = {}
var _water_anim_time: float = 0.0
var _frame_counter: int = 0


# =============================================================================
# _get_terrain_texture() — Load/cache a terrain PNG from assets/tiles/
# The source assets are 16x16; with TILE_SIZE=32 and NEAREST filter they
# render as crisp pixel-doubled sprites.
# =============================================================================

func _get_terrain_texture(terrain: String) -> Texture2D:
	if _texture_cache.has(terrain):
		return _texture_cache[terrain]
	var path = "res://assets/tiles/" + terrain + ".png"
	if FileAccess.file_exists(path):
		var img = Image.new()
		if img.load(path) == OK:
			var tex = ImageTexture.create_from_image(img)
			_texture_cache[terrain] = tex
			return tex
	return null


# =============================================================================
# _make_layer_key() — Composite key for terrain + material grouping
# =============================================================================

func _make_layer_key(terrain: String, material: String) -> String:
	if material.is_empty():
		return terrain
	return terrain + ":" + material


# =============================================================================
# _get_material_texture() — generate & cache a palette-swapped terrain texture
# =============================================================================

func _get_material_texture(terrain: String, material: String) -> Texture2D:
	var key = _make_layer_key(terrain, material)
	if _texture_cache.has(key):
		return _texture_cache[key]

	# Load the base terrain image
	var base_path = "res://assets/tiles/" + terrain + ".png"
	if not FileAccess.file_exists(base_path):
		return null

	var base_img = Image.new()
	if base_img.load(base_path) != OK:
		return null

	# Apply palette swap
	var ramp: Array = PixelPatterns.MATERIAL_RAMPS.get(material, [])
	if ramp.is_empty():
		# No material ramp — use base texture as-is
		var tex = ImageTexture.create_from_image(base_img)
		_texture_cache[key] = tex
		return tex

	# Inline palette swap — avoids PixelGenerator class_name dependency
	var ramp_idx_to_color = {}
	for i in range(ramp.size()):
		ramp_idx_to_color[i] = Color(ramp[i])
	var reverse = {}
	for idx in PixelPatterns.PALETTE:
		var hex = PixelPatterns.PALETTE[idx]
		if not hex.is_empty(): reverse[hex] = idx
	var swapped = Image.create(base_img.get_width(), base_img.get_height(), false, Image.FORMAT_RGBA8)
	for y in range(base_img.get_height()):
		for x in range(base_img.get_width()):
			var pixel = base_img.get_pixel(x, y)
			if pixel.a == 0: continue
			var hex_match = "#" + pixel.to_html(false)
			var pidx = reverse.get(hex_match, -1)
			if pidx > 0 and pidx <= ramp.size():
				swapped.set_pixel(x, y, Color(ramp[pidx - 1]))
			else:
				swapped.set_pixel(x, y, pixel)
	var tex = ImageTexture.create_from_image(swapped)
	_texture_cache[key] = tex
	return tex


# =============================================================================
# _get_building_texture() — Load a generic building indicator texture
# =============================================================================

func _get_building_texture() -> Texture2D:
	if _texture_cache.has("__building__"):
		return _texture_cache["__building__"]
	var path = "res://assets/tiles/building.png"
	if FileAccess.file_exists(path):
		var img = Image.new()
		if img.load(path) == OK:
			var tex = ImageTexture.create_from_image(img)
			_texture_cache["__building__"] = tex
			return tex
	# Fallback: generate a simple 32x32 building icon
	var img = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var half = TILE_SIZE / 2
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			# Simple house shape: body + triangle roof
			if y >= half:  # body
				img.set_pixel(x, y, Color(1, 1, 1, 1))
			elif y >= half - 4 and x >= half - 4 and x <= half + 3:  # roof
				var roof_y = y - (half - 4)
				var roof_h = 4
				var left_x = half - 4 + roof_y
				var right_x = half + 3 - roof_y
				if x >= left_x and x <= right_x:
					img.set_pixel(x, y, Color(1, 1, 1, 1))
				else:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var tex = ImageTexture.create_from_image(img)
	_texture_cache["__building__"] = tex
	return tex


# =============================================================================
# _get_creature_texture() — Load a generic creature indicator texture
# =============================================================================

func _get_creature_texture() -> Texture2D:
	if _texture_cache.has("__creature__"):
		return _texture_cache["__creature__"]
	var path = "res://assets/tiles/creature.png"
	if FileAccess.file_exists(path):
		var img = Image.new()
		if img.load(path) == OK:
			var tex = ImageTexture.create_from_image(img)
			_texture_cache["__creature__"] = tex
			return tex
	# Fallback: generate a simple 32x32 creature icon (diamond/eye shape)
	var img = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var cx = TILE_SIZE / 2
	var cy = TILE_SIZE / 2
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var dx = abs(x - cx)
			var dy = abs(y - cy)
			# Diamond shape
			if dx + dy < TILE_SIZE / 2 - 2:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var tex = ImageTexture.create_from_image(img)
	_texture_cache["__creature__"] = tex
	return tex


# =============================================================================
# _ready() — Connect to events; rendering is deferred until world_generated
# =============================================================================

func _ready() -> void:
	EventBus.world_generated.connect(_on_world_generated)
	EventBus.territory_captured.connect(func(_c: int, x: int, y: int): _mark_dirty(x, y))


# =============================================================================
# _on_world_generated() — Create and fill all chunks
# =============================================================================

func _on_world_generated(w: int, h: int) -> void:
	var chunks_x = int(ceil(float(w) / CHUNK_SIZE))
	var chunks_y = int(ceil(float(h) / CHUNK_SIZE))
	for cy in range(chunks_y):
		for cx in range(chunks_x):
			_fill_chunk(cx, cy)


# =============================================================================
# _get_visible_count() – Count actual tiles per (terrain, material) in a chunk.
# Returns {layer_key: count}. Edge chunks return < CHUNK_SIZE².
# =============================================================================

func _get_visible_count(cx: int, cy: int) -> Dictionary:
	var layer_counts = {}
	for dy in range(CHUNK_SIZE):
		for dx in range(CHUNK_SIZE):
			var tx = cx * CHUNK_SIZE + dx
			var ty = cy * CHUNK_SIZE + dy
			if tx >= ColonyData.world_width or ty >= ColonyData.world_height:
				continue
			var tile = ColonyData.get_tile(tx, ty)
			var terrain: String = tile.get("terrain", "water")
			var material: String = tile.get("material", "")
			var layer_key = _make_layer_key(terrain, material)
			layer_counts[layer_key] = layer_counts.get(layer_key, 0) + 1
	return layer_counts


# =============================================================================
# _count_buildings() — Count building instances in a chunk
# =============================================================================

func _count_buildings(cx: int, cy: int) -> int:
	var count := 0
	for dy in range(CHUNK_SIZE):
		for dx in range(CHUNK_SIZE):
			var tx = cx * CHUNK_SIZE + dx
			var ty = cy * CHUNK_SIZE + dy
			if tx >= ColonyData.world_width or ty >= ColonyData.world_height:
				continue
			var tile = ColonyData.get_tile(tx, ty)
			if not tile.get("buildings", []).is_empty():
				count += 1
	return count


# =============================================================================
# _count_creatures() — Count faction/monster instances in a chunk
# =============================================================================

func _count_creatures(cx: int, cy: int) -> int:
	var count := 0
	# Count factions on tiles in this chunk
	for f in ColonyData.active_factions:
		var tx: int = f.get("tile_x", -1)
		var ty: int = f.get("tile_y", -1)
		var fc_x = tx / CHUNK_SIZE
		var fc_y = ty / CHUNK_SIZE
		if fc_x == cx and fc_y == cy:
			count += 1
	# Count monsters on tiles in this chunk
	for m in ColonyData.world_monsters:
		if not m.get("alive", false):
			continue
		var tx: int = m.get("lair_x", -1)
		var ty: int = m.get("lair_y", -1)
		var mc_x = tx / CHUNK_SIZE
		var mc_y = ty / CHUNK_SIZE
		if mc_x == cx and mc_y == cy:
			count += 1
	return count


# =============================================================================
# _free_chunk_layers() — Free all three layer types for a chunk
# =============================================================================

func _free_chunk_layers(key: Vector2i) -> void:
	# Free terrain container and its children
	if _terrain_containers.has(key):
		var container = _terrain_containers[key] as Node2D
		if container:
			container.visible = false
			remove_child(container)
			container.queue_free()
		_terrain_containers.erase(key)

	# Free building layer
	if _building_layers.has(key):
		var bld = _building_layers[key] as MultiMeshInstance2D
		if bld:
			bld.visible = false
			remove_child(bld)
			bld.queue_free()
		_building_layers.erase(key)

	# Free creature layer
	if _creature_layers.has(key):
		var crt = _creature_layers[key] as MultiMeshInstance2D
		if crt:
			crt.visible = false
			remove_child(crt)
			crt.queue_free()
		_creature_layers.erase(key)


# =============================================================================
# _create_multimesh() — Helper to build a configured MultiMesh
# =============================================================================

func _create_multimesh(instance_count: int) -> MultiMesh:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = QuadMesh.new()
	mm.mesh.size = Vector2(TILE_SIZE, TILE_SIZE)
	mm.instance_count = instance_count
	mm.visible_instance_count = 0
	return mm


# =============================================================================
# _create_mmi() — Helper to build a configured MultiMeshInstance2D
# =============================================================================

func _create_mmi(mm: MultiMesh, texture: Texture2D) -> MultiMeshInstance2D:
	var mmi = MultiMeshInstance2D.new()
	mmi.multimesh = mm
	if texture:
		mmi.texture = texture
		mmi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return mmi


# =============================================================================
# _fill_chunk() — Three-pass DF-style rendering:
#   Pass 1: Terrain tiles  → _terrain_container (per-terrain MultiMeshInstance2Ds)
#   Pass 2: Buildings       → _building_layer (single MultiMeshInstance2D)
#   Pass 3: Creatures       → _creature_layer (single MultiMeshInstance2D)
# =============================================================================

func _fill_chunk(cx: int, cy: int) -> void:
	var key = Vector2i(cx, cy)

	# Free old layers
	_free_chunk_layers(key)

	var chunk_origin = Vector2(cx * CHUNK_SIZE * TILE_SIZE, cy * CHUNK_SIZE * TILE_SIZE)

	# =========================================================================
	# PASS 1: TERRAIN — Material-aware palette-swapped textures (DF-style)
	# Each (terrain, material) pair gets its own MultiMesh layer with a
	# palette-swapped texture. No per-instance color modulation needed;
	# the texture already carries the material color.
	# =========================================================================
	var terrain_counts := _get_visible_count(cx, cy)

	var terrain_container = Node2D.new()
	terrain_container.name = "TerrainLayer_%d_%d" % [cx, cy]
	terrain_container.position = chunk_origin
	add_child(terrain_container)

	var terrain_layers = {}  # {layer_key: MultiMeshInstance2D}

	for layer_key in terrain_counts:
		var count = terrain_counts[layer_key]
		var instance_count := ceili(count * 1.1)  # 10% buffer

		var mm = _create_multimesh(instance_count)

		# Resolve terrain and material from the composite key
		var parts = layer_key.split(":", false, 1)
		var terrain: String = parts[0]
		var material: String = parts[1] if parts.size() > 1 else ""

		# Use palette-swapped texture if material is present
		var tex: Texture2D
		if not material.is_empty():
			tex = _get_material_texture(terrain, material)
		if not tex:
			tex = _get_terrain_texture(terrain)

		var mmi = _create_mmi(mm, tex)
		mmi.position = Vector2.ZERO
		mmi.set_meta("terrain_name", terrain)
		terrain_container.add_child(mmi)
		terrain_layers[layer_key] = mmi

	# Fill terrain instance transforms and colors
	var instance_idx = {}
	for layer_key in terrain_layers:
		instance_idx[layer_key] = 0

	for dy in range(CHUNK_SIZE):
		for dx in range(CHUNK_SIZE):
			var tx = cx * CHUNK_SIZE + dx
			var ty = cy * CHUNK_SIZE + dy
			if tx >= ColonyData.world_width or ty >= ColonyData.world_height:
				continue
			var tile = ColonyData.get_tile(tx, ty)
			var terrain: String = tile.get("terrain", "water")
			var material: String = tile.get("material", "")
			var layer_key = _make_layer_key(terrain, material)

			var mmi: MultiMeshInstance2D = terrain_layers[layer_key]
			var mm = mmi.multimesh
			var idx = instance_idx[layer_key]

			var t = Transform2D(0, Vector2(dx * TILE_SIZE, dy * TILE_SIZE))
			mm.set_instance_transform_2d(idx, t)

			# Color modulation: material-swapped tiles already have correct colors;
			# non-material tiles use the terrain base color for their default look.
			var base_color = Color.WHITE
			if material.is_empty():
				var color_str: String = ColonyData.TERRAINS.get(terrain, {}).get("color", "#4488ff")
				base_color = Color(color_str)

			# Nation tinting: subtle lerp toward owner color
			var owner: int = tile.get("owner", -1)
			if owner >= 0 and owner < ColonyData.nations.size():
				var nation_color_str: String = ColonyData.nations[owner].get("color", "#ffffff")
				base_color = base_color.lerp(Color(nation_color_str), 0.3)

			mm.set_instance_color(idx, base_color)

			instance_idx[layer_key] = idx + 1

	# Set visible instance counts for terrain
	for layer_key in terrain_layers:
		terrain_layers[layer_key].multimesh.visible_instance_count = instance_idx[layer_key]

	_terrain_containers[key] = terrain_container

	# =========================================================================
	# PASS 2: BUILDINGS
	# =========================================================================
	var building_count = _count_buildings(cx, cy)
	if building_count > 0:
		var bld_instance_count := ceili(building_count * 1.1)
		var bld_mm = _create_multimesh(bld_instance_count)
		var bld_tex = _get_building_texture()
		var bld_mmi = _create_mmi(bld_mm, bld_tex)
		bld_mmi.position = chunk_origin
		add_child(bld_mmi)

		var bld_idx := 0
		var category_colors = {
			"economic": _get_ramp_mid_color("wood_oak", Color(0.2, 0.8, 0.2)),
			"military": _get_ramp_mid_color("stone_granite", Color(0.9, 0.2, 0.2)),
			"religious": _get_ramp_mid_color("metal_gold", Color(1.0, 0.85, 0.0)),
			"infrastructure": _get_ramp_mid_color("stone_marble", Color(0.2, 0.4, 0.9)),
		}

		for dy in range(CHUNK_SIZE):
			for dx in range(CHUNK_SIZE):
				var tx = cx * CHUNK_SIZE + dx
				var ty = cy * CHUNK_SIZE + dy
				if tx >= ColonyData.world_width or ty >= ColonyData.world_height:
					continue
				var tile = ColonyData.get_tile(tx, ty)
				var buildings: Array = tile.get("buildings", [])
				if buildings.is_empty():
					continue

				var t = Transform2D(0, Vector2(dx * TILE_SIZE, dy * TILE_SIZE))
				bld_mm.set_instance_transform_2d(bld_idx, t)

				# Use color of the first building's category
				var first_bld = buildings[0]
				var category: String = ColonyData.BUILDINGS.get(first_bld, {}).get("category", "")
				var bld_color: Color = category_colors.get(category, Color.WHITE)

				# Also tint by owner
				var owner: int = tile.get("owner", -1)
				if owner >= 0 and owner < ColonyData.nations.size():
					var nation_color_str: String = ColonyData.nations[owner].get("color", "#ffffff")
					bld_color = bld_color.lerp(Color(nation_color_str), 0.2)

				bld_mm.set_instance_color(bld_idx, bld_color)
				bld_idx += 1

		bld_mm.visible_instance_count = bld_idx
		_building_layers[key] = bld_mmi

	# =========================================================================
	# PASS 3: CREATURES (factions + monsters)
	# =========================================================================
	var creature_count = _count_creatures(cx, cy)
	if creature_count > 0:
		var crt_instance_count := ceili(creature_count * 1.1)
		var crt_mm = _create_multimesh(crt_instance_count)
		var crt_tex = _get_creature_texture()
		var crt_mmi = _create_mmi(crt_mm, crt_tex)
		crt_mmi.position = chunk_origin
		add_child(crt_mmi)

		var crt_idx := 0
		var processed_tiles := {}  # Avoid double-counting faction+monster on same tile

		# First: factions
		for f in ColonyData.active_factions:
			var ftx: int = f.get("tile_x", -1)
			var fty: int = f.get("tile_y", -1)
			var fc_x = ftx / CHUNK_SIZE
			var fc_y = fty / CHUNK_SIZE
			if fc_x != cx or fc_y != cy:
				continue
			if ftx < 0 or ftx >= ColonyData.world_width or fty < 0 or fty >= ColonyData.world_height:
				continue

			var tile_key = "%d,%d" % [ftx, fty]
			if processed_tiles.has(tile_key):
				continue
			processed_tiles[tile_key] = true

			var local_x = ftx - cx * CHUNK_SIZE
			var local_y = fty - cy * CHUNK_SIZE
			var t = Transform2D(0, Vector2(local_x * TILE_SIZE, local_y * TILE_SIZE))
			crt_mm.set_instance_transform_2d(crt_idx, t)

			# Color by faction type
			var ftype: String = f.get("type", "wild_tribe")
			var faction_color = _get_faction_color(ftype)
			crt_mm.set_instance_color(crt_idx, faction_color)
			crt_idx += 1

		# Second: monsters
		for m in ColonyData.world_monsters:
			if not m.get("alive", false):
				continue
			var mtx: int = m.get("lair_x", -1)
			var mty: int = m.get("lair_y", -1)
			var mc_x = mtx / CHUNK_SIZE
			var mc_y = mty / CHUNK_SIZE
			if mc_x != cx or mc_y != cy:
				continue
			if mtx < 0 or mtx >= ColonyData.world_width or mty < 0 or mty >= ColonyData.world_height:
				continue

			var tile_key = "%d,%d" % [mtx, mty]
			if processed_tiles.has(tile_key):
				continue
			processed_tiles[tile_key] = true

			var local_x = mtx - cx * CHUNK_SIZE
			var local_y = mty - cy * CHUNK_SIZE
			var t = Transform2D(0, Vector2(local_x * TILE_SIZE, local_y * TILE_SIZE))
			crt_mm.set_instance_transform_2d(crt_idx, t)

			# Color by monster species (threat-based intensity)
			var species: String = m.get("species", "dragon")
			var threat: int = m.get("threat_rating", 5)
			var monster_color = _get_monster_color(species, threat)
			crt_mm.set_instance_color(crt_idx, monster_color)
			crt_idx += 1

		if crt_idx > 0:
			crt_mm.visible_instance_count = crt_idx
			_creature_layers[key] = crt_mmi


# =============================================================================
# _get_ramp_mid_color() — Pick distinctive mid-tone from a material ramp
# =============================================================================

func _get_ramp_mid_color(material_key: String, fallback: Color) -> Color:
	var ramp: Array = PixelPatterns.MATERIAL_RAMPS.get(material_key, [])
	if ramp.size() >= 5:
		return Color(ramp[4])  # 5th color out of 9 — distinctive mid-tone
	return fallback


# =============================================================================
# _get_faction_color() -- Color mapping for faction types
# =============================================================================

func _get_faction_color(ftype: String) -> Color:
	match ftype:
		"wild_tribe":      return Color(0.6, 0.3, 0.1)
		"bandit_camp":     return Color(0.7, 0.1, 0.1)
		"monster_lair":    return Color(0.8, 0.0, 0.4)
		"ancient_guardian": return Color(0.9, 0.7, 0.0)
		"merchant_caravan": return Color(0.1, 0.7, 0.3)
		"pirate_den":      return Color(0.1, 0.3, 0.7)
		_:                 return Color(0.5, 0.5, 0.5)


# =============================================================================
# _get_monster_color() — Color by species, intensity by threat
# =============================================================================

func _get_monster_color(species: String, threat: int) -> Color:
	var base: Color
	match species:
		"dragon":   base = Color(0.9, 0.2, 0.0)
		"hydra":    base = Color(0.1, 0.8, 0.2)
		"giant":    base = Color(0.5, 0.3, 0.1)
		"behemoth": base = Color(0.4, 0.1, 0.6)
		_:          base = Color(0.7, 0.2, 0.2)
	var intensity = clamp(threat / 10.0, 0.3, 1.0)
	return Color(base.r * intensity, base.g * intensity, base.b * intensity, 1.0)


# =============================================================================
# _mark_dirty() — Rebuild all three layers when a tile changes
# =============================================================================

func _mark_dirty(tile_x: int, tile_y: int) -> void:
	var cx = tile_x / CHUNK_SIZE
	var cy = tile_y / CHUNK_SIZE
	_fill_chunk(cx, cy)


# =============================================================================
# _process() — Frustum culling and water animation
# =============================================================================

func _process(delta: float) -> void:
	_frame_counter += 1
	if _frame_counter % 30 == 0:
		_update_chunk_visibility()
	_animate_water(delta)


# =============================================================================
# _update_chunk_visibility() — Culling for all three layer types
# =============================================================================

func _update_chunk_visibility() -> void:
	var cam = get_node_or_null("../Camera2D")
	var viewport_size = get_viewport().get_visible_rect().size
	var cam_pos = cam.position if cam else Vector2.ZERO
	for key in _terrain_containers:
		var cx: int = key.x
		var cy: int = key.y
		var chunk_center = Vector2(
			(cx + 0.5) * CHUNK_SIZE * TILE_SIZE,
			(cy + 0.5) * CHUNK_SIZE * TILE_SIZE
		)
		var visible = (
			abs(chunk_center.x - cam_pos.x) < viewport_size.x * 1.5
			and abs(chunk_center.y - cam_pos.y) < viewport_size.y * 1.5
		)
		_chunk_visible_cache[key] = visible

		# Terrain container
		if _terrain_containers.has(key):
			_terrain_containers[key].visible = visible

		# Building layer
		if _building_layers.has(key):
			_building_layers[key].visible = visible

		# Creature layer
		if _creature_layers.has(key):
			_creature_layers[key].visible = visible


# =============================================================================
# _animate_water() — Subtle time-based color modulation for water/coast
# =============================================================================

func _animate_water(delta: float) -> void:
	_water_anim_time += delta
	var wave = sin(_water_anim_time * 0.6) * 0.06
	for key in _terrain_containers:
		var container = _terrain_containers[key] as Node2D
		if not container:
			continue
		for child in container.get_children():
			var mmi = child as MultiMeshInstance2D
			if not mmi:
				continue
			var terrain_name: String = mmi.get_meta("terrain_name", "")
			if terrain_name == "water" or terrain_name == "coast":
				var r = 1.0 - wave * 0.5
				var g = 1.0 - wave * 0.2
				var b = 1.0 + wave * 0.6
				mmi.self_modulate = Color(
					clamp(r, 0.92, 1.08),
					clamp(g, 0.95, 1.05),
					clamp(b, 0.92, 1.08),
					1.0
				)
