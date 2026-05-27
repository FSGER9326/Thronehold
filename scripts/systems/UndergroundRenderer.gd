class_name UndergroundRenderer
extends Node2D
# =============================================================================
# Chunk-based renderer for the underworld layer.
# Reads from ColonyData.underground_tiles and uses UNDERGROUND_TERRAINS colors.
# Visible only when underground mode is toggled (U key) AND camera zoom > 2.0.
# =============================================================================

const CHUNK_SIZE: int = 32
const TILE_PX: int = 32

# Vector2i(cx, cy) -> {terrain_name: MultiMeshInstance2D}
var _chunk_layers: Dictionary = {}
var _underground_enabled: bool = false
var _texture_cache: Dictionary = {}


# =============================================================================
# _get_terrain_texture() -- Load/cache an underground terrain PNG from the PixelGenerator
# =============================================================================

func _get_terrain_texture(terrain: String) -> Texture2D:
	if _texture_cache.has(terrain):
		return _texture_cache[terrain]
	var path = "res://assets/tiles/underground_" + terrain + ".png"
	if FileAccess.file_exists(path):
		var img = Image.new()
		if img.load(path) == OK:
			var tex = ImageTexture.create_from_image(img)
			_texture_cache[terrain] = tex
			return tex
	return null


# =============================================================================
# _make_layer_key() -- Composite key for terrain + material grouping
# =============================================================================

func _make_layer_key(terrain: String, material: String) -> String:
	if material.is_empty():
		return terrain
	return terrain + ":" + material


# =============================================================================
# _get_material_texture() -- Generate & cache a palette-swapped texture
# =============================================================================

func _get_material_texture(terrain: String, material: String) -> Texture2D:
	var key = _make_layer_key(terrain, material)
	if _texture_cache.has(key):
		return _texture_cache[key]

	# Try loading the base underground terrain image
	var base_path = "res://assets/tiles/underground_" + terrain + ".png"
	if not FileAccess.file_exists(base_path):
		# Fall back to regular tiles directory
		base_path = "res://assets/tiles/" + terrain + ".png"
		if not FileAccess.file_exists(base_path):
			return null

	var base_img = Image.new()
	if base_img.load(base_path) != OK:
		return null

	# Apply palette swap
	var ramp: Array = PixelPatterns.MATERIAL_RAMPS.get(material, [])
	if ramp.is_empty():
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
# _ready() -- Connect to events; start hidden
# =============================================================================

func _ready() -> void:
	visible = false
	EventBus.world_generated.connect(_on_world_generated)
	EventBus.underground_toggled.connect(_on_underground_toggled)


# =============================================================================
# _on_world_generated() -- Create and fill all chunks
# =============================================================================

func _on_world_generated(w: int, h: int) -> void:
	var chunks_x = int(ceil(float(w) / CHUNK_SIZE))
	var chunks_y = int(ceil(float(h) / CHUNK_SIZE))
	for cy in range(chunks_y):
		for cx in range(chunks_x):
			_fill_chunk(cx, cy)


# =============================================================================
# _on_underground_toggled() -- Toggle from U key
# =============================================================================

func _on_underground_toggled(enabled: bool) -> void:
	_underground_enabled = enabled


# =============================================================================
# _get_visible_count() -- Count actual tiles per (terrain, material) in a chunk.
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
			var tile = ColonyData.get_underground_tile(tx, ty)
			var terrain: String = tile.get("terrain", "caves")
			var material: String = tile.get("material", "")
			var layer_key = _make_layer_key(terrain, material)
			layer_counts[layer_key] = layer_counts.get(layer_key, 0) + 1
	return layer_counts


# =============================================================================
# _fill_chunk() -- Build per-(terrain,material) MultiMeshInstance2D layers for one chunk.
# =============================================================================

func _fill_chunk(cx: int, cy: int) -> void:
	var key = Vector2i(cx, cy)

	# Free old layers for this chunk
	if _chunk_layers.has(key):
		var old_layers: Dictionary = _chunk_layers[key]
		for layer_key in old_layers:
			var old = old_layers[layer_key] as MultiMeshInstance2D
			if old:
				old.visible = false
				remove_child(old)
				old.queue_free()

	# Count tiles per (terrain, material) pair (only within world bounds)
	var layer_counts := _get_visible_count(cx, cy)

	# Create one MultiMesh layer per (terrain, material) pair
	var layers = {}
	for layer_key in layer_counts:
		var count = layer_counts[layer_key]
		# Add 10% buffer for future tile-type changes without full rebuild
		var instance_count := ceili(count * 1.1)
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = QuadMesh.new()
		mm.mesh.size = Vector2(TILE_PX, TILE_PX)
		mm.instance_count = instance_count
		mm.visible_instance_count = 0

		var mmi = MultiMeshInstance2D.new()
		mmi.multimesh = mm

		# Resolve terrain and material from composite key
		var parts = layer_key.split(":", false, 1)
		var terrain: String = parts[0]
		var material: String = parts[1] if parts.size() > 1 else ""

		# Use palette-swapped texture if material present
		var tex: Texture2D
		if not material.is_empty():
			tex = _get_material_texture(terrain, material)
		if not tex:
			tex = _get_terrain_texture(terrain)
		if tex:
			mmi.texture = tex
			mmi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		mmi.position = Vector2(cx * CHUNK_SIZE * TILE_PX, cy * CHUNK_SIZE * TILE_PX)
		add_child(mmi)
		layers[layer_key] = mmi

	# Fill instance transforms and colors
	var instance_idx = {}
	for layer_key in layers:
		instance_idx[layer_key] = 0

	for dy in range(CHUNK_SIZE):
		for dx in range(CHUNK_SIZE):
			var tx = cx * CHUNK_SIZE + dx
			var ty = cy * CHUNK_SIZE + dy
			if tx >= ColonyData.world_width or ty >= ColonyData.world_height:
				continue
			var tile = ColonyData.get_underground_tile(tx, ty)
			var terrain: String = tile.get("terrain", "caves")
			var material: String = tile.get("material", "")
			var layer_key = _make_layer_key(terrain, material)

			var mmi: MultiMeshInstance2D = layers[layer_key]
			var mm = mmi.multimesh
			var idx = instance_idx[layer_key]

			var t = Transform2D(0, Vector2(dx * TILE_PX, dy * TILE_PX))
			mm.set_instance_transform_2d(idx, t)

			# Per-instance color: use underground terrain color as subtle tint
			var color_str: String = ColonyData.UNDERGROUND_TERRAINS.get(terrain, {}).get("color", "#2a2a2a")
			mm.set_instance_color(idx, Color(color_str))

			instance_idx[layer_key] = idx + 1

	# Set visible instance counts
	for layer_key in layers:
		layers[layer_key].multimesh.visible_instance_count = instance_idx[layer_key]

	_chunk_layers[key] = layers


# =============================================================================
# _process() -- Check zoom and toggle visibility accordingly
# =============================================================================

func _process(_delta: float) -> void:
	if not _underground_enabled:
		visible = false
		return

	var cam = get_node_or_null("../../../Camera2D")
	if not cam:
		cam = get_tree().current_scene.get_node_or_null("Camera2D")

	if cam:
		var zoom_level: float = cam.zoom.x
		visible = zoom_level > 2.0
	else:
		visible = false

	if visible:
		_update_chunk_visibility()


func _update_chunk_visibility() -> void:
	var cam = get_node_or_null("../../../Camera2D")
	if not cam:
		cam = get_tree().current_scene.get_node_or_null("Camera2D")
	var viewport_size = get_viewport().get_visible_rect().size
	var cam_pos = cam.position if cam else Vector2.ZERO
	for key in _chunk_layers:
		var cx: int = key.x
		var cy: int = key.y
		var chunk_center = Vector2(
			(cx + 0.5) * CHUNK_SIZE * TILE_PX,
			(cy + 0.5) * CHUNK_SIZE * TILE_PX
		)
		var chunk_visible = (
			abs(chunk_center.x - cam_pos.x) < viewport_size.x * 1.5
			and abs(chunk_center.y - cam_pos.y) < viewport_size.y * 1.5
		)
		var layers: Dictionary = _chunk_layers[key]
		for layer_key in layers:
			layers[layer_key].visible = chunk_visible
