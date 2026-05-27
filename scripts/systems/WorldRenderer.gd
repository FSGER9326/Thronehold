class_name WorldRenderer
extends Node2D
# =============================================================================
# Renders the pixel-art world map using chunk-based MultiMeshInstance2D.
# Delegates terrain rendering to ChunkRenderer. Manages minimap, tile interaction,
# and visual AI feedback effects drawn via _draw() overlay.
# =============================================================================

var _chunk_renderer: ChunkRenderer
var _fog_renderer: FogRenderer

var _minimap_panel: PanelContainer
var _minimap_rect: ColorRect
var _minimap_viewport_rect: ColorRect
var _minimap_outline_rect: ColorRect
var _minimap_enabled: bool = true

var _hovered_tile: Vector2i = Vector2i(-1, -1)

var _visual_effects: Array[Dictionary] = []
var _nation_tile_positions: Dictionary = {}
var _effects_dirty: bool = false

var _subrace_transitions: Dictionary = {}  # {nation_id: {old_color, target_color, progress, duration}}

var _building_cache: Dictionary = {}  # {nation_id: {tile_key: [building_id, ...]}}
var _building_cache_dirty: bool = true

var _underground_visible: bool = false


# =============================================================================
# _ready() — Set up ChunkRenderer, visual effects, and minimap
# =============================================================================

func _ready() -> void:
	# Visual AI feedback overlay connections
	EventBus.war_declared.connect(func(a: int, d: int): _add_visual_effect("war", {"attacker": a, "defender": d}))
	EventBus.trade_route_established.connect(func(f: int, t: int, _r: String): _add_visual_effect("trade", {"from": f, "to": t}))
	EventBus.colony_founded.connect(func(n: int, x: int, y: int): _add_visual_effect("colony", {"nation": n, "tile_x": x, "tile_y": y}))
	EventBus.building_placed.connect(func(x: int, y: int, _b: String, _n: int): _add_visual_effect("building", {"tile_x": x, "tile_y": y}))
	EventBus.alliance_formed.connect(func(a: int, b: int): _add_visual_effect("alliance", {"nation_a": a, "nation_b": b}))

	# Subrace emergence — tile color shift over 2 seconds
	EventBus.subrace_emerged.connect(func(nid: int, _old: String, new_race: String):
		_show_subrace_emergence(nid, new_race))

	# Build tile position cache after world generation; refresh on territory changes
	EventBus.world_generated.connect(func(_w: int, _h: int):
		_build_nation_tile_positions()
		_rebuild_building_cache()
		_effects_dirty = true)
	EventBus.territory_captured.connect(func(_c: int, _x: int, _y: int):
		_build_nation_tile_positions()
		_effects_dirty = true)

	# Building indicator cache — invalidate on building changes; world_generated does a full rebuild
	EventBus.building_placed.connect(func(_x: int, _y: int, _b: String, _n: int):
		_building_cache_dirty = true)
	EventBus.building_destroyed.connect(func(_x: int, _y: int, _b: String):
		_building_cache_dirty = true
		queue_redraw())

	# Create chunk-based renderer for terrain
	_chunk_renderer = ChunkRenderer.new()
	_chunk_renderer.name = "ChunkRenderer"
	add_child(_chunk_renderer)

	# Create chunk-based renderer for underground layer
	var underground_renderer = UndergroundRenderer.new()
	underground_renderer.name = "UndergroundRenderer"
	add_child(underground_renderer)

	# Create fog of war overlay
	_fog_renderer = FogRenderer.new()
	_fog_renderer.name = "FogRenderer"
	add_child(_fog_renderer)

	# Create the minimap overlay
	_create_minimap()

	# Create static grid overlay for tactical feel
	var grid = Node2D.new()
	grid.name = "GridOverlay"
	grid.draw.connect(func():
		var gw = ColonyData.world_width * 16
		var gh = ColonyData.world_height * 16
		var grid_color = Color(0, 0, 0, 0.15) # Faint black lines
		for x in range(0, gw + 16, 16):
			grid.draw_line(Vector2(x, 0), Vector2(x, gh), grid_color, 1.0)
		for y in range(0, gh + 16, 16):
			grid.draw_line(Vector2(0, y), Vector2(gw, y), grid_color, 1.0)
	)
	add_child(grid)
	EventBus.world_generated.connect(func(_w, _h): grid.queue_redraw())


# =============================================================================
# _unhandled_input() — Detect mouse clicks and hover for tile interaction
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var tile_pos = _screen_to_tile(event.position)
			if tile_pos.x >= 0:
				EventBus.tile_clicked.emit(tile_pos.x, tile_pos.y)

	if event is InputEventMouseMotion:
		var tile_pos = _screen_to_tile(event.position)
		if tile_pos != _hovered_tile:
			_hovered_tile = tile_pos
			if tile_pos.x >= 0:
				EventBus.tile_hovered.emit(tile_pos.x, tile_pos.y)

	if event is InputEventKey and event.keycode == KEY_U and event.pressed:
		_underground_visible = not _underground_visible
		var ug = get_node_or_null("UndergroundRenderer")
		if ug:
			ug.visible = _underground_visible
		EventBus.underground_toggled.emit(_underground_visible)


# =============================================================================
# get_world_position() — Convert tile coordinates to world pixel position
# =============================================================================

func get_world_position(tile_x: int, tile_y: int) -> Vector2:
	return Vector2(tile_x * 16, tile_y * 16)


# =============================================================================
# _screen_to_tile() — Convert screen pixel position to tile coordinates
# =============================================================================

func _screen_to_tile(pos: Vector2) -> Vector2i:
	var cam = get_node_or_null("../Camera2D")
	var world_pos = pos
	if cam:
		world_pos = pos + cam.position - get_viewport().get_visible_rect().size / 2.0
	var tx = int(world_pos.x / 16.0)
	var ty = int(world_pos.y / 16.0)
	if tx < 0 or tx >= ColonyData.world_width or ty < 0 or ty >= ColonyData.world_height:
		return Vector2i(-1, -1)
	return Vector2i(tx, ty)


# =============================================================================
# Minimap — Territory overview overlay (top-right corner)
# =============================================================================

func _create_minimap() -> void:
	# Wrapper container for label + panel
	var container = VBoxContainer.new()
	container.name = "MiniMapContainer"
	container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	container.position = Vector2(-180, -180)

	# "MINIMAP" label above the panel
	var label = Label.new()
	label.name = "MiniMapLabel"
	label.text = "MINIMAP"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	label.add_theme_font_size_override("font_size", 9)
	container.add_child(label)

	_minimap_panel = PanelContainer.new()
	_minimap_panel.name = "MiniMap"
	_minimap_panel.custom_minimum_size = Vector2(172, 132)
	_minimap_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Dark theme border
	var border_sb = StyleBoxFlat.new()
	border_sb.bg_color = Color(0.08, 0.08, 0.15)
	border_sb.border_color = Color(0.165, 0.165, 0.29)  # #2a2a4a
	border_sb.border_width_left = 2; border_sb.border_width_right = 2
	border_sb.border_width_top = 2; border_sb.border_width_bottom = 2
	_minimap_panel.add_theme_stylebox_override("panel", border_sb)

	_minimap_rect = ColorRect.new()
	_minimap_rect.custom_minimum_size = Vector2(160, 120)
	_minimap_rect.color = Color.BLACK
	_minimap_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_minimap_panel.add_child(_minimap_rect)

	# Viewport outline — thin white border behind the indicator for visibility
	_minimap_outline_rect = ColorRect.new()
	_minimap_outline_rect.name = "MiniMapViewportOutline"
	_minimap_outline_rect.color = Color(1, 1, 1, 0.3)
	_minimap_outline_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap_rect.add_child(_minimap_outline_rect)

	# Viewport indicator overlay — more visible cyan rect
	_minimap_viewport_rect = ColorRect.new()
	_minimap_viewport_rect.name = "MiniMapViewportIndicator"
	_minimap_viewport_rect.color = Color(0.5, 0.9, 1.0, 0.5)
	_minimap_viewport_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap_rect.add_child(_minimap_viewport_rect)

	# Click to jump camera
	_minimap_rect.gui_input.connect(_on_minimap_input)

	container.add_child(_minimap_panel)
	add_child(container)

	# Build minimap texture
	_build_minimap_texture()
	EventBus.world_generated.connect(func(_w, _h): _build_minimap_texture())
	EventBus.territory_captured.connect(func(_c, _x, _y): _build_minimap_texture())


func _on_minimap_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed:
		return
	var click_pos = event.position
	var tile_x = int(clamp(click_pos.x / 2.0, 0, ColonyData.world_width - 1))
	var tile_y = int(clamp(click_pos.y / 2.0, 0, ColonyData.world_height - 1))
	# Move camera to this tile
	var cam = get_node_or_null("../Camera2D")
	if cam:
		cam.position = Vector2(tile_x * 16 + 8, tile_y * 16 + 8)


func _build_minimap_texture() -> void:
	var img = Image.create(ColonyData.world_width, ColonyData.world_height, false, Image.FORMAT_RGBA8)
	var vis_grid = ColonyData.visibility_grid
	var has_fog = vis_grid.size() == ColonyData.world_width * ColonyData.world_height
	for y in range(ColonyData.world_height):
		for x in range(ColonyData.world_width):
			var tile = ColonyData.get_tile(x, y)
			var terrain = tile["terrain"]
			var owner = tile["owner"]
			var col = Color(_terrain_base_color(terrain))
			if owner >= 0 and owner < ColonyData.nations.size():
				var nation_color = ColonyData.nations[owner].get("color", "#ffffff")
				col = col.lerp(Color(nation_color), 0.4)
			# Apply fog of war greying
			if has_fog:
				var vis = vis_grid[y * ColonyData.world_width + x]
				if vis == 0:
					col = col.darkened(0.75)  # unexplored: heavily darkened
				elif vis == 1:
					col = col.darkened(0.35)  # explored but not visible: moderately darkened
			img.set_pixel(x, y, col)

	var tex = ImageTexture.create_from_image(img)
	_minimap_rect.material = null
	# Remove previous sprite if any
	if _minimap_rect.get_node_or_null("MiniMapSprite"):
		_minimap_rect.get_node("MiniMapSprite").queue_free()
	var sprite = Sprite2D.new()
	sprite.name = "MiniMapSprite"
	sprite.texture = tex
	sprite.scale = Vector2(2, 2)
	sprite.position = Vector2(2, 2)
	sprite.centered = false
	_minimap_rect.add_child(sprite)


func _terrain_base_color(terrain: String) -> String:
	return ColonyData.TERRAINS.get(terrain, {}).get("color", "#000000")


# =============================================================================
# _show_subrace_emergence() — Gradual tile color shift when a subrace emerges
# =============================================================================

func _show_subrace_emergence(nation_id: int, variant_id: String) -> void:
	var nation = ColonyData.get_nation(nation_id)
	if nation.is_empty():
		return

	var old_color = Color(nation["color"])
	var variant = ColonyData.RACE_VARIANTS.get(variant_id, {})
	var specialization: String = variant.get("specialization", "")

	# Derive a hue shift from the specialization string
	var hue_offset: float = 0.0
	if not specialization.is_empty():
		var hash_val: int = abs(specialization.hash())
		hue_offset = (hash_val % 41 - 20) / 360.0  # -20..+20 degrees

	var target_color = old_color
	target_color.h = fmod(old_color.h + hue_offset, 1.0)
	if target_color.h < 0.0:
		target_color.h += 1.0

	_subrace_transitions[nation_id] = {
		"old_color": old_color,
		"target_color": target_color,
		"progress": 0.0,
		"duration": 2.0,
	}


# =============================================================================
# Visual AI feedback overlay — Animated indicators for AI actions
# =============================================================================

func _process(delta: float) -> void:
	# Clean up completed subrace transitions (deferred so _draw gets final frame)
	for nid in _subrace_transitions.keys():
		var t: Dictionary = _subrace_transitions[nid]
		if t.get("done", false):
			_subrace_transitions.erase(nid)

	var expired: Array[int] = []
	for i in range(_visual_effects.size()):
		_visual_effects[i]["remaining"] -= delta
		if _visual_effects[i]["remaining"] <= 0:
			expired.append(i)
	if not expired.is_empty():
		_effects_dirty = true
	expired.reverse()
	for i in expired:
		_visual_effects.remove_at(i)

	# Drive subrace emergence transitions
	var has_active_transition = false
	for nation_id in _subrace_transitions.keys():
		var t: Dictionary = _subrace_transitions[nation_id]
		t["progress"] += delta / t["duration"]
		if t["progress"] >= 1.0:
			t["progress"] = 1.0
			t["done"] = true
		else:
			has_active_transition = true

	if _effects_dirty or not _visual_effects.is_empty() or has_active_transition or not _subrace_transitions.is_empty():
		queue_redraw()
		_effects_dirty = false

	# Update minimap viewport indicator and outline
	if _minimap_enabled and _minimap_viewport_rect:
		var cam = get_node_or_null("../Camera2D")
		if cam:
			var viewport_size = get_viewport().get_visible_rect().size
			var world_w = ColonyData.world_width * 16.0
			var world_h = ColonyData.world_height * 16.0
			var scale_x = 160.0 / world_w
			var scale_y = 120.0 / world_h
			var cam_left = cam.position.x - viewport_size.x * 0.5
			var cam_top = cam.position.y - viewport_size.y * 0.5
			cam_left = clamp(cam_left, 0.0, world_w - viewport_size.x)
			cam_top = clamp(cam_top, 0.0, world_h - viewport_size.y)
			var base_pos = Vector2(2 + cam_left * scale_x, 2 + cam_top * scale_y)
			var base_size = Vector2(viewport_size.x * scale_x, viewport_size.y * scale_y)
			_minimap_viewport_rect.position = base_pos
			_minimap_viewport_rect.size = base_size
			if _minimap_outline_rect:
				_minimap_outline_rect.position = base_pos - Vector2(1, 1)
				_minimap_outline_rect.size = base_size + Vector2(2, 2)


func _draw() -> void:
	# Subrace emergence — draw color-shifted overlay on nation tiles
	for nation_id in _subrace_transitions.keys():
		var t: Dictionary = _subrace_transitions[nation_id]
		var current_color = t["old_color"].lerp(t["target_color"], t["progress"])
		var alpha = 0.15 + t["progress"] * 0.25
		current_color.a = alpha
		var positions: PackedVector2Array = _nation_tile_positions.get(nation_id, PackedVector2Array())
		for pos in positions:
			draw_rect(Rect2(pos.x, pos.y, 16, 16), current_color)

	_draw_buildings()

	for effect in _visual_effects:
		var alpha = clamp(effect["remaining"] / effect["duration"], 0.0, 1.0)
		match effect["type"]:
			"war":
				var a_id: int = effect["data"]["attacker"]
				var d_id: int = effect["data"]["defender"]
				_draw_war_effect(a_id, d_id, alpha)
			"trade":
				_draw_trade_effect(effect["data"]["from"], effect["data"]["to"], alpha)
			"colony":
				_draw_colony_effect(effect["data"]["tile_x"], effect["data"]["tile_y"], alpha)
			"building":
				_draw_building_effect(effect["data"]["tile_x"], effect["data"]["tile_y"], alpha)
			"alliance":
				_draw_alliance_effect(effect["data"]["nation_a"], effect["data"]["nation_b"], alpha)


func _add_visual_effect(type: String, data: Dictionary) -> void:
	var duration = 3.0
	match type:
		"war": duration = 3.0
		"trade": duration = 2.0
		"colony": duration = 5.0
		"building": duration = 2.0
		"alliance": duration = 3.0
	_visual_effects.append({"type": type, "data": data, "duration": duration, "remaining": duration})
	_effects_dirty = true


func _build_nation_tile_positions() -> void:
	_nation_tile_positions.clear()
	for y in range(ColonyData.world_height):
		for x in range(ColonyData.world_width):
			var owner = ColonyData.get_tile(x, y)["owner"]
			if owner < 0:
				continue
			if not _nation_tile_positions.has(owner):
				_nation_tile_positions[owner] = PackedVector2Array()
			_nation_tile_positions[owner].append(Vector2(x * 16, y * 16))


func _rebuild_building_cache() -> void:
	_building_cache.clear()
	for y in range(ColonyData.world_height):
		for x in range(ColonyData.world_width):
			var tile = ColonyData.get_tile(x, y)
			var buildings: Array = tile.get("buildings", [])
			if buildings.is_empty():
				continue
			var owner: int = tile.get("owner", -1)
			if owner < 0:
				continue
			if not _building_cache.has(owner):
				_building_cache[owner] = {}
			var key: String = "%d,%d" % [x, y]
			_building_cache[owner][key] = buildings.duplicate()
	_building_cache_dirty = false


func _draw_buildings() -> void:
	if _building_cache_dirty:
		_rebuild_building_cache()

	var category_colors = {
		"economic": Color.GREEN,
		"military": Color.RED,
		"religious": Color.GOLD,
		"infrastructure": Color.BLUE,
	}

	for nation_id in _building_cache:
		for tile_key in _building_cache[nation_id]:
			var parts: PackedStringArray = tile_key.split(",")
			var tx: int = int(parts[0])
			var ty: int = int(parts[1])
			for building_id in _building_cache[nation_id][tile_key]:
				var category: String = ColonyData.BUILDINGS.get(building_id, {}).get("category", "")
				var color: Color = category_colors.get(category, Color.WHITE)
				draw_rect(Rect2(tx * 16 + 7, ty * 16 + 7, 3, 3), color)


func _draw_war_effect(attacker: int, defender: int, alpha: float) -> void:
	var col = Color(1.0, 0.2, 0.2, alpha * 0.4)
	for nation_id in [attacker, defender]:
		var positions: PackedVector2Array = _nation_tile_positions.get(nation_id, PackedVector2Array())
		for pos in positions:
			draw_rect(Rect2(pos.x, pos.y, 16, 16), col)


func _draw_trade_effect(from_id: int, to_id: int, alpha: float) -> void:
	var nat_a = ColonyData.get_nation(from_id)
	var nat_b = ColonyData.get_nation(to_id)
	if nat_a.is_empty() or nat_b.is_empty(): return
	var from_pos = Vector2(nat_a["capital_x"] * 16 + 8, nat_a["capital_y"] * 16 + 8)
	var to_pos = Vector2(nat_b["capital_x"] * 16 + 8, nat_b["capital_y"] * 16 + 8)
	draw_dashed_line(from_pos, to_pos, Color(1.0, 0.9, 0.2, alpha), 2.0)


func _draw_colony_effect(tile_x: int, tile_y: int, alpha: float) -> void:
	draw_circle(Vector2(tile_x * 16 + 8, tile_y * 16 + 8), 6.0 + (1.0 - alpha) * 4.0, Color(0.2, 1.0, 0.2, alpha))


func _draw_building_effect(tile_x: int, tile_y: int, alpha: float) -> void:
	draw_rect(Rect2(tile_x * 16, tile_y * 16, 16, 16), Color(1.0, 1.0, 1.0, alpha * 0.5))


func _draw_alliance_effect(nation_a: int, nation_b: int, alpha: float) -> void:
	var col = Color(0.3, 0.5, 1.0, alpha * 0.3)
	for nation_id in [nation_a, nation_b]:
		var positions: PackedVector2Array = _nation_tile_positions.get(nation_id, PackedVector2Array())
		for pos in positions:
			draw_rect(Rect2(pos.x, pos.y, 16, 16), col)
