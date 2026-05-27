class_name UndergroundRenderer
extends Node2D
# =============================================================================
# Chunk-based renderer for the underworld layer.
# Reads from ColonyData.underground_tiles and uses UNDERGROUND_TERRAINS colors.
# Visible only when underground mode is toggled (U key) AND camera zoom > 2.0.
# =============================================================================

const CHUNK_SIZE: int = 32
const TILE_PX: int = 16

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
# _fill_chunk() -- Build per-terrain MultiMeshInstance2D layers for one chunk.
# =============================================================================

func _fill_chunk(cx: int, cy: int) -> void:
	var key = Vector2i(cx, cy)

	# Free old layers for this chunk
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
			var tile = ColonyData.get_underground_tile(tx, ty)
			var terrain: String = tile.get("terrain", "caves")
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
			var tile = ColonyData.get_underground_tile(tx, ty)
			var terrain: String = tile.get("terrain", "caves")

			var mmi: MultiMeshInstance2D = layers[terrain]
			var mm = mmi.multimesh
			var idx = instance_idx[terrain]

			var t = Transform2D(0, Vector2(dx * TILE_PX, dy * TILE_PX))
			mm.set_instance_transform_2d(idx, t)

			var color_str: String = ColonyData.UNDERGROUND_TERRAINS.get(terrain, {}).get("color", "#2a2a2a")
			mm.set_instance_color(idx, Color(color_str))

			instance_idx[terrain] = idx + 1

	# Set visible instance counts
	for terrain in layers:
		layers[terrain].multimesh.visible_instance_count = instance_idx[terrain]

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
		for terrain in layers:
			layers[terrain].visible = chunk_visible
