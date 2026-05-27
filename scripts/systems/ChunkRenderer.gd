class_name ChunkRenderer
extends Node2D
# =============================================================================
# Chunk-based renderer using per-terrain MultiMeshInstance2D layers.
# Each terrain type gets its own MultiMeshInstance2D layer with instance color
# modulation from ColonyData.TERRAINS colors. No texture atlas required.
# Includes time-based water/coast color animation.
# =============================================================================

const CHUNK_SIZE: int = 32
const TILE_PX: int = 16

# Vector2i(cx, cy) -> {terrain_name: MultiMeshInstance2D}
var _chunk_layers: Dictionary = {}
var _texture_cache: Dictionary = {}
var _water_anim_time: float = 0.0


# =============================================================================
# _get_terrain_texture() -- Load/cache a 16×16 terrain PNG from the PixelGenerator
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
# _ready() -- Connect to events; rendering is deferred until world_generated
# =============================================================================

func _ready() -> void:
	EventBus.world_generated.connect(_on_world_generated)
	EventBus.territory_captured.connect(func(_c: int, x: int, y: int): _mark_dirty(x, y))


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
# _fill_chunk() -- Build per-terrain MultiMeshInstance2D layers for one chunk.
# Counts tiles by terrain, creates one layer per terrain, fills transforms and
# instance colors from ColonyData.TERRAINS.
# =============================================================================

func _fill_chunk(cx: int, cy: int) -> void:
	var key = Vector2i(cx, cy)

	# Free old layers for this chunk (handle terrain changes)
	if _chunk_layers.has(key):
		var old_layers: Dictionary = _chunk_layers[key]
		for terrain in old_layers:
			var old = old_layers[terrain] as MultiMeshInstance2D
			if old:
				old.visible = false
				remove_child(old)
				old.queue_free()

	# Count tiles per terrain type
	var terrain_counts = {}
	for dy in range(CHUNK_SIZE):
		for dx in range(CHUNK_SIZE):
			var tx = cx * CHUNK_SIZE + dx
			var ty = cy * CHUNK_SIZE + dy
			if tx >= ColonyData.world_width or ty >= ColonyData.world_height:
				continue
			var tile = ColonyData.get_tile(tx, ty)
			var terrain: String = tile.get("terrain", "water")
			terrain_counts[terrain] = terrain_counts.get(terrain, 0) + 1

	# Create one MultiMesh layer per terrain type
	var layers = {}
	for terrain in terrain_counts:
		var count = terrain_counts[terrain]
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = QuadMesh.new()
		mm.mesh.size = Vector2(TILE_PX, TILE_PX)
		mm.instance_count = count
		mm.visible_instance_count = 0

		var mmi = MultiMeshInstance2D.new()
		mmi.multimesh = mm
		var tex = _get_terrain_texture(terrain)
		if tex:
			mmi.texture = tex
			mmi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mmi.position = Vector2(cx * CHUNK_SIZE * TILE_PX, cy * CHUNK_SIZE * TILE_PX)
		add_child(mmi)
		layers[terrain] = mmi

	# Fill instance transforms and colors
	var instance_idx = {}
	for terrain in layers:
		instance_idx[terrain] = 0

	for dy in range(CHUNK_SIZE):
		for dx in range(CHUNK_SIZE):
			var tx = cx * CHUNK_SIZE + dx
			var ty = cy * CHUNK_SIZE + dy
			if tx >= ColonyData.world_width or ty >= ColonyData.world_height:
				continue
			var tile = ColonyData.get_tile(tx, ty)
			var terrain: String = tile.get("terrain", "water")

			var mmi: MultiMeshInstance2D = layers[terrain]
			var mm = mmi.multimesh
			var idx = instance_idx[terrain]

			var t = Transform2D(0, Vector2(dx * TILE_PX, dy * TILE_PX))
			mm.set_instance_transform_2d(idx, t)

			var color_str: String = ColonyData.TERRAINS.get(terrain, {}).get("color", "#4488ff")
			mm.set_instance_color(idx, Color(color_str))

			instance_idx[terrain] = idx + 1

	# Set visible instance counts
	for terrain in layers:
		layers[terrain].multimesh.visible_instance_count = instance_idx[terrain]

	_chunk_layers[key] = layers


# =============================================================================
# _mark_dirty() -- Rebuild a chunk when a tile inside it changes
# =============================================================================

func _mark_dirty(tile_x: int, tile_y: int) -> void:
	var cx = tile_x / CHUNK_SIZE
	var cy = tile_y / CHUNK_SIZE
	_fill_chunk(cx, cy)


# =============================================================================
# _process() -- Frustum culling and water animation
# =============================================================================

func _process(delta: float) -> void:
	_update_chunk_visibility()
	_animate_water(delta)


func _update_chunk_visibility() -> void:
	var cam = get_node_or_null("../Camera2D")
	var viewport_size = get_viewport().get_visible_rect().size
	var cam_pos = cam.position if cam else Vector2.ZERO
	for key in _chunk_layers:
		var cx: int = key.x
		var cy: int = key.y
		var chunk_center = Vector2(
			(cx + 0.5) * CHUNK_SIZE * TILE_PX,
			(cy + 0.5) * CHUNK_SIZE * TILE_PX
		)
		var visible = (
			abs(chunk_center.x - cam_pos.x) < viewport_size.x * 1.5
			and abs(chunk_center.y - cam_pos.y) < viewport_size.y * 1.5
		)
		var layers: Dictionary = _chunk_layers[key]
		for terrain in layers:
			layers[terrain].visible = visible


# =============================================================================
# _animate_water() -- Subtle time-based blue shift modulation for water/coast
# =============================================================================

func _animate_water(delta: float) -> void:
	_water_anim_time += delta
	var wave = sin(_water_anim_time * 0.6) * 0.06
	for key in _chunk_layers:
		var layers: Dictionary = _chunk_layers[key]
		for terrain in layers:
			if terrain == "water" or terrain == "coast":
				var mmi: MultiMeshInstance2D = layers[terrain]
				# Subtle blue-shift oscillation: shifts toward blue then back to normal
				var r = 1.0 - wave * 0.5
				var g = 1.0 - wave * 0.2
				var b = 1.0 + wave * 0.6
				mmi.self_modulate = Color(
					clamp(r, 0.92, 1.08),
					clamp(g, 0.95, 1.05),
					clamp(b, 0.92, 1.08),
					1.0
				)