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
var _minimap_zlevel_label: Label
var _minimap_dirty: bool = false
var _minimap_tick_counter: int = 0
var _minimap_elevation_bar: TextureRect
var _minimap_underworld_label: Label

var _hovered_tile: Vector2i = Vector2i(-1, -1)

var _visual_effects: Array[Dictionary] = []
var _nation_tile_rects: Dictionary = {}      # {nation_id: Array[Rect2]} — pre-built rects for fast _draw()
var _effects_dirty: bool = false

var _right_click_menu: PopupMenu

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

	# Build tile rect cache after world generation; refresh on territory changes
	EventBus.world_generated.connect(func(_w: int, _h: int):
		_build_nation_tile_rects()
		_rebuild_building_cache()
		_effects_dirty = true)
	EventBus.territory_captured.connect(func(_c: int, _x: int, _y: int):
		_build_nation_tile_rects()
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

	# Create right-click context menu (hidden by default)
	_right_click_menu = PopupMenu.new()
	_right_click_menu.name = "RightClickMenu"
	add_child(_right_click_menu)

	# DF-inspired: z-level indicator update on underground toggle
	EventBus.underground_toggled.connect(_on_underground_toggled_minimap)
	EventBus.tick_advanced.connect(_on_minimap_tick_advanced)

	# Create static grid overlay for tactical feel
	var grid = Node2D.new()
	grid.name = "GridOverlay"
	grid.draw.connect(func():
		var ts = ChunkRenderer.TILE_SIZE
		var gw = ColonyData.world_width * ts
		var gh = ColonyData.world_height * ts
		var grid_color = Color(0, 0, 0, 0.15) # Faint black lines
		for x in range(0, gw + ts, ts):
			grid.draw_line(Vector2(x, 0), Vector2(x, gh), grid_color, 1.0)
		for y in range(0, gh + ts, ts):
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

		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var tile_pos = _screen_to_tile(event.position)
			if tile_pos.x >= 0:
				var context = _get_tile_context(tile_pos.x, tile_pos.y)
				if not context.is_empty():
					EventBus.tile_context_requested.emit(tile_pos.x, tile_pos.y, context)

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
	return Vector2(tile_x * ChunkRenderer.TILE_SIZE, tile_y * ChunkRenderer.TILE_SIZE)


# =============================================================================
# _screen_to_tile() — Convert screen pixel position to tile coordinates
# =============================================================================

func _screen_to_tile(pos: Vector2) -> Vector2i:
	var cam = get_node_or_null("../Camera2D")
	var world_pos = pos
	if cam:
		world_pos = pos + cam.position - get_viewport().get_visible_rect().size / 2.0
	var ts = ChunkRenderer.TILE_SIZE
	var tx = int(world_pos.x / float(ts))
	var ty = int(world_pos.y / float(ts))
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
	# Explicit anchor to top-right — visible and clear
	container.set_anchor(SIDE_RIGHT, 1.0)
	container.set_anchor(SIDE_TOP, 0.0)
	container.set_offset(SIDE_RIGHT, -10)
	container.set_offset(SIDE_TOP, 50)
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	# "MINIMAP" label above the panel
	var label = Label.new()
	label.name = "MiniMapLabel"
	label.text = "MINIMAP"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	label.add_theme_font_size_override("font_size", 9)
	container.add_child(label)

	# DF-inspired: Z-level indicator on the minimap
	_minimap_zlevel_label = Label.new()
	_minimap_zlevel_label.name = "MiniMapZLevel"
	_minimap_zlevel_label.text = "Surface"
	_minimap_zlevel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_minimap_zlevel_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	_minimap_zlevel_label.add_theme_font_size_override("font_size", 8)
	container.add_child(_minimap_zlevel_label)

	# HBox to hold minimap panel + elevation bar side by side
	var map_hbox = HBoxContainer.new()
	map_hbox.add_theme_constant_override("separation", 2)

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

	map_hbox.add_child(_minimap_panel)

	# DF-inspired: Elevation bar (vertical ColorRect on right of minimap)
	var elevation_container = VBoxContainer.new()
	elevation_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var elev_label = Label.new()
	elev_label.text = "E"
	elev_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elev_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.6))
	elev_label.add_theme_font_size_override("font_size", 7)
	elevation_container.add_child(elev_label)

	_minimap_elevation_bar = TextureRect.new()
	_minimap_elevation_bar.name = "MiniMapElevationBar"
	_minimap_elevation_bar.custom_minimum_size = Vector2(8, 120)
	_minimap_elevation_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_minimap_elevation_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_minimap_elevation_bar.stretch_mode = TextureRect.STRETCH_SCALE
	_minimap_elevation_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elevation_container.add_child(_minimap_elevation_bar)
	# Spacer below elevation bar
	var elev_spacer = Control.new()
	elev_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	elevation_container.add_child(elev_spacer)
	map_hbox.add_child(elevation_container)

	container.add_child(map_hbox)
	add_child(container)

	# Build minimap texture
	_build_minimap_texture()
	EventBus.world_generated.connect(func(_w, _h):
		_build_minimap_texture()
		_build_elevation_bar()
	)
	EventBus.territory_captured.connect(func(_c, _x, _y): _minimap_dirty = true)


func _on_minimap_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed:
		return
	var click_pos = event.position
	# Map click position in minimap coordinates to world tile coordinates
	var minimap_w = 160.0
	var minimap_h = 120.0
	var tile_x = int(clamp(click_pos.x / minimap_w * ColonyData.world_width, 0, ColonyData.world_width - 1))
	var tile_y = int(clamp(click_pos.y / minimap_h * ColonyData.world_height, 0, ColonyData.world_height - 1))
	# Move camera to this tile
	var ts_half = ChunkRenderer.TILE_SIZE / 2
	var cam = get_node_or_null("../Camera2D")
	if cam:
		cam.position = Vector2(tile_x * ChunkRenderer.TILE_SIZE + ts_half, tile_y * ChunkRenderer.TILE_SIZE + ts_half)


func _build_minimap_texture() -> void:
	var minimap_w = 160
	var minimap_h = 120
	var img = Image.create(minimap_w, minimap_h, false, Image.FORMAT_RGBA8)
	var vis_grid = ColonyData.visibility_grid
	var has_fog = vis_grid.size() == ColonyData.world_width * ColonyData.world_height
	for y in range(minimap_h):
		for x in range(minimap_w):
			# Sample world tile at the corresponding position
			var world_x = int(x * ColonyData.world_width / minimap_w)
			var world_y = int(y * ColonyData.world_height / minimap_h)
			var tile = ColonyData.get_tile(world_x, world_y)
			var terrain = tile["terrain"]
			var owner = tile["owner"]
			var col = Color(_terrain_base_color(terrain))
			if owner >= 0 and owner < ColonyData.nations.size():
				var nation_color = ColonyData.nations[owner].get("color", "#ffffff")
				col = col.lerp(Color(nation_color), 0.4)
			# Apply fog of war greying
			if has_fog:
				var vis = vis_grid[world_y * ColonyData.world_width + world_x]
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
	sprite.scale = Vector2(1, 1)
	sprite.position = Vector2.ZERO
	sprite.centered = false
	_minimap_rect.add_child(sprite)


func _terrain_base_color(terrain: String) -> String:
	return ColonyData.TERRAINS.get(terrain, {}).get("color", "#000000")


# =============================================================================
# _build_elevation_bar() — Compute and render a vertical elevation profile
# =============================================================================

func _build_elevation_bar() -> void:
	if not _minimap_elevation_bar:
		return
	var w = ColonyData.world_width
	var h = ColonyData.world_height
	if w <= 0 or h <= 0:
		return

	# Sample elevation every 4 rows for a 120px bar (30 segments)
	var bar_h = 120
	var segments = mini(bar_h, max(1, h / 4))
	var step = max(1, h / segments)

	var img = Image.create(4, bar_h, false, Image.FORMAT_RGBA8)
	for py in range(bar_h):
		var seg_y = int(float(py) / bar_h * segments)
		var world_y = seg_y * step
		var high_count = 0
		var total = 0
		for wx in range(0, w, 8):
			var tile = ColonyData.get_tile(wx, world_y)
			var terrain = tile.get("terrain", "water")
			if terrain == "mountain":
				high_count += 3
			elif terrain == "hills":
				high_count += 2
			elif terrain == "forest":
				high_count += 1
			total += 1
		var elev = float(high_count) / max(total, 1) / 3.0  # 0.0 to 1.0
		var color = Color(0.15, 0.15 + elev * 0.4, 0.1 + elev * 0.3)
		for px in range(4):
			img.set_pixel(px, bar_h - 1 - py, color)

	var tex = ImageTexture.create_from_image(img)
	_minimap_elevation_bar.texture = tex


# =============================================================================
# _update_minimap_zlevel() — Update the z-level indicator text
# =============================================================================

func _update_minimap_zlevel(underground: bool) -> void:
	if not _minimap_zlevel_label:
		return
	_minimap_zlevel_label.text = "Cavern 1" if underground else "Surface"


# =============================================================================
# _on_underground_toggled_minimap() — Handle underground toggle for minimap
# =============================================================================

func _on_underground_toggled_minimap(enabled: bool) -> void:
	_update_minimap_zlevel(enabled)


func _on_minimap_tick_advanced(_tick: int, _day: int, _season: String, _year: int) -> void:
	_minimap_tick_counter += 1
	if _minimap_tick_counter >= 120:
		_minimap_tick_counter = 0
		if _minimap_dirty:
			_minimap_dirty = false
			_build_minimap_texture()


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
			var ts = ChunkRenderer.TILE_SIZE
			var world_w = ColonyData.world_width * float(ts)
			var world_h = ColonyData.world_height * float(ts)
			var scale_x = 160.0 / world_w
			var scale_y = 120.0 / world_h
			var cam_left = cam.position.x - viewport_size.x * 0.5
			var cam_top = cam.position.y - viewport_size.y * 0.5
			cam_left = clamp(cam_left, 0.0, world_w - viewport_size.x)
			cam_top = clamp(cam_top, 0.0, world_h - viewport_size.y)
			var base_pos = Vector2(cam_left * scale_x, cam_top * scale_y)
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
		var rects: Array = _nation_tile_rects.get(nation_id, [])
		for r in rects:
			draw_rect(r, current_color)

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


# =============================================================================
# Right-click context menu — Build context data for a given tile
# =============================================================================

func _get_tile_context(tile_x: int, tile_y: int) -> Dictionary:
	var context: Dictionary = {}
	var tile = ColonyData.get_tile(tile_x, tile_y)
	if tile.is_empty():
		return context

	context["terrain"] = tile.get("terrain", "unknown")

	# Check for nation territory
	var owner: int = tile.get("owner", -1)
	if owner >= 0 and owner < ColonyData.nations.size():
		var nation = ColonyData.get_nation(owner)
		if not nation.is_empty():
			context["has_owner"] = true
			context["owner_id"] = owner
			context["owner_name"] = nation.get("name", "Unknown")

	# Check for buildings on tile
	var buildings: Array = tile.get("buildings", [])
	if not buildings.is_empty():
		context["has_buildings"] = true
		context["buildings"] = buildings.duplicate()

	# Check for factions on tile
	if is_inside_tree():
		var scene = get_tree().current_scene
		var systems = scene.get_node_or_null("Systems") if scene else null
		if systems:
			var fm = systems.get_node_or_null("FactionManager")
			if fm and fm.has_method("get_factions_on_tile"):
				var factions_on_tile: Array = fm.get_factions_on_tile(tile_x, tile_y)
				if not factions_on_tile.is_empty():
					context["has_faction"] = true
					context["faction_data"] = factions_on_tile[0]
					var ftype: String = factions_on_tile[0].get("type", "")
					context["faction_name"] = ColonyData.FACTIONS.get(ftype, {}).get("name", ftype.capitalize())

	# Check for monster lair on tile
	for m in ColonyData.world_monsters:
		if m.get("alive", false) and m.get("lair_x", -1) == tile_x and m.get("lair_y", -1) == tile_y:
			context["has_monster"] = true
			context["monster_name"] = m.get("name", "Monster")
			context["monster_species"] = m.get("species", "unknown")
			break

	return context


func _build_nation_tile_rects() -> void:
	_nation_tile_rects.clear()
	for y in range(ColonyData.world_height):
		for x in range(ColonyData.world_width):
			var owner = ColonyData.get_tile(x, y)["owner"]
			if owner < 0:
				continue
			if not _nation_tile_rects.has(owner):
				_nation_tile_rects[owner] = []
			var ts = ChunkRenderer.TILE_SIZE
			_nation_tile_rects[owner].append(Rect2(x * ts, y * ts, ts, ts))


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

	# Category → material ramp lookup; use mid-ramp color for building dots
	var material_colors = {
		"economic": _get_ramp_mid_color("wood_oak", Color.GREEN),
		"military": _get_ramp_mid_color("stone_granite", Color.RED),
		"religious": _get_ramp_mid_color("metal_gold", Color.GOLD),
		"infrastructure": _get_ramp_mid_color("stone_marble", Color.BLUE),
	}

	for nation_id in _building_cache:
		for tile_key in _building_cache[nation_id]:
			var parts: PackedStringArray = tile_key.split(",")
			var tx: int = int(parts[0])
			var ty: int = int(parts[1])
			for building_id in _building_cache[nation_id][tile_key]:
				var category: String = ColonyData.BUILDINGS.get(building_id, {}).get("category", "")
				var color: Color = material_colors.get(category, Color.WHITE)
				var ts = ChunkRenderer.TILE_SIZE
				var half = ts / 2
				draw_rect(Rect2(tx * ts + half - 1, ty * ts + half - 1, 3, 3), color)


# =============================================================================
# _get_ramp_mid_color() — Pick the middle color from a material ramp
# =============================================================================

func _get_ramp_mid_color(material_key: String, fallback: Color) -> Color:
	var ramp: Array = PixelPatterns.MATERIAL_RAMPS.get(material_key, [])
	if ramp.size() >= 5:
		return Color(ramp[4])  # 5th color out of 9 — distinctive mid-tone
	return fallback


func _draw_war_effect(attacker: int, defender: int, alpha: float) -> void:
	var col = Color(1.0, 0.2, 0.2, alpha * 0.4)
	for nation_id in [attacker, defender]:
		var rects: Array = _nation_tile_rects.get(nation_id, [])
		for r in rects:
			draw_rect(r, col)


func _draw_trade_effect(from_id: int, to_id: int, alpha: float) -> void:
	var nat_a = ColonyData.get_nation(from_id)
	var nat_b = ColonyData.get_nation(to_id)
	if nat_a.is_empty() or nat_b.is_empty(): return
	var ts = ChunkRenderer.TILE_SIZE
	var half = ts / 2
	var from_pos = Vector2(nat_a["capital_x"] * ts + half, nat_a["capital_y"] * ts + half)
	var to_pos = Vector2(nat_b["capital_x"] * ts + half, nat_b["capital_y"] * ts + half)
	draw_dashed_line(from_pos, to_pos, Color(1.0, 0.9, 0.2, alpha), 2.0)


func _draw_colony_effect(tile_x: int, tile_y: int, alpha: float) -> void:
	var ts = ChunkRenderer.TILE_SIZE
	draw_circle(Vector2(tile_x * ts + ts / 2, tile_y * ts + ts / 2), 6.0 + (1.0 - alpha) * 4.0, Color(0.2, 1.0, 0.2, alpha))


func _draw_building_effect(tile_x: int, tile_y: int, alpha: float) -> void:
	var ts = ChunkRenderer.TILE_SIZE
	draw_rect(Rect2(tile_x * ts, tile_y * ts, ts, ts), Color(1.0, 1.0, 1.0, alpha * 0.5))


func _draw_alliance_effect(nation_a: int, nation_b: int, alpha: float) -> void:
	var col = Color(0.3, 0.5, 1.0, alpha * 0.3)
	for nation_id in [nation_a, nation_b]:
		var rects: Array = _nation_tile_rects.get(nation_id, [])
		for r in rects:
			draw_rect(r, col)
