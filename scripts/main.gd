extends Node2D

var cam: Camera2D
var cam_pos: Vector2 = Vector2(640, 360)

# Fixed integer zoom steps for crisp pixel art at every level
var zoom_steps: Array[float] = [0.5, 1.0, 2.0, 3.0, 4.0]
var zoom_index: int = 1  # Start at 1.0

var drag_start: Vector2 = Vector2.ZERO
var dragging: bool = false
var underground_enabled: bool = false

# Camera shake state
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0
var _shake_enabled: bool = false

# === DF-style Hotkey Save-Slots (F1-F8) ===
var hotkey_slots: Dictionary = {}     # "F1" → Vector2 (world pixel position)
var hotkey_names: Dictionary = {}     # "F1" → String (custom display name)
var hotkey_display: Label = null


func _ready() -> void:
	print("[Main] Initializing game systems...")

	var systems = Node.new()
	systems.name = "Systems"
	add_child(systems)

	var manager_scripts = [
		"res://scripts/systems/TimeManager.gd",
		"res://scripts/systems/HistoryGenerator.gd",
		"res://scripts/systems/WorldGenerator.gd",
		"res://scripts/systems/CharacterManager.gd",
		"res://scripts/systems/NationManager.gd",
		"res://scripts/systems/DiplomacyManager.gd",
		"res://scripts/systems/DeityManager.gd",
		"res://scripts/systems/InfluenceManager.gd",
		"res://scripts/systems/ProphetManager.gd",
		"res://scripts/systems/ResourceManager.gd",
		"res://scripts/systems/PopulationManager.gd",
		"res://scripts/systems/CultureManager.gd",
		"res://scripts/systems/PolicyManager.gd",
		"res://scripts/systems/EventManager.gd",
		"res://scripts/systems/FactionManager.gd",
		"res://scripts/systems/MonsterManager.gd",
		"res://scripts/systems/BuildingManager.gd",
		"res://scripts/systems/ColonyManager.gd",
		"res://scripts/systems/MilitaryManager.gd",
		"res://scripts/systems/TechManager.gd",
		"res://scripts/systems/ArtifactManager.gd",
		"res://scripts/systems/VictoryManager.gd",
		"res://scripts/systems/SaveManager.gd",
	]

	for script_path in manager_scripts:
		var node = Node.new()
		node.name = script_path.get_file().trim_suffix(".gd")
		node.set_script(load(script_path))
		systems.add_child(node)

	# Node2D renderers Ã¢â‚¬â€ must be direct children of main (also Node2D)
	for rpath in ["res://scripts/systems/WorldRenderer.gd", "res://scripts/systems/ChunkRenderer.gd", "res://scripts/systems/UndergroundRenderer.gd", "res://scripts/systems/FogRenderer.gd"]:
		var rnode = Node2D.new()
		rnode.name = rpath.get_file().trim_suffix(".gd")
		rnode.set_script(load(rpath))
		add_child(rnode)

	cam = Camera2D.new()
	cam.name = "Camera2D"
	cam.position = cam_pos
	cam.enabled = true
	cam.drag_horizontal_enabled = true
	cam.drag_vertical_enabled = true
	add_child(cam)

	var game_ui = CanvasLayer.new()
	game_ui.name = "GameUI"
	game_ui.set_script(load("res://scripts/ui/GameUI.gd"))
	add_child(game_ui)

	# Hotkey display panel — subtle, bottom-left corner
	var hotkey_layer = CanvasLayer.new()
	hotkey_layer.name = "HotkeyLayer"
	hotkey_display = Label.new()
	hotkey_display.name = "HotkeyLabel"
	hotkey_display.add_theme_font_size_override("font_size", 10)
	hotkey_display.modulate = Color(1, 1, 1, 0.45)
	hotkey_display.position = Vector2(8, get_viewport().get_visible_rect().size.y - 150)
	hotkey_display.autowrap_mode = TextServer.AUTOWRAP_OFF
	hotkey_layer.add_child(hotkey_display)
	add_child(hotkey_layer)
	_update_hotkey_display()

	# Normal game flow: main menu → class selection → world gen
	if GameManager.current_state == GameManager.GameState.WORLD_SETUP:
		_run_world_generation(systems)
	else:
		print("[Main] Waiting for class selection before generating world...")
		EventBus.world_generation_requested.connect(func():
			_run_world_generation(systems)
		, CONNECT_ONE_SHOT)

	# Camera shake connections
	EventBus.battle_fought.connect(func(_a: int, _d: int, _r: Dictionary):
		_shake_camera(3.0, 0.3))
	EventBus.defeat_triggered.connect(func(_reason: String, _desc: String):
		_shake_camera(8.0, 0.6))


func _run_world_generation(systems: Node) -> void:
	print("[Main] Generating world...")
	var world_gen = systems.get_node("WorldGenerator")
	if world_gen:
		world_gen.generate_world(ColonyData.world_width, ColonyData.world_height)

	GameManager.world_setup_complete()
	
	# Auto-register F1 hotkey to player nation capital
	call_deferred("_auto_set_capital_hotkey")

	print("[Main] Game systems ready. %d nations. %d characters." % [
		ColonyData.nations.size(), ColonyData.characters.size()
	])


func _capture_screenshot() -> void:
	for _i in range(10): await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img: img.save_png(OS.get_user_data_dir() + "/3_world_map.png")
	print("[Main] Screenshot captured.")


func _shake_camera(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration = duration
	_shake_timer = duration
	_shake_enabled = true


func _clamp_camera() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var ts = ChunkRenderer.TILE_SIZE
	var world_pixel_w = float(ColonyData.world_width * ts)
	var world_pixel_h = float(ColonyData.world_height * ts)
	var current_zoom = zoom_steps[zoom_index]
	var half_view = viewport_size * current_zoom * 0.5
	cam_pos.x = clamp(cam_pos.x, half_view.x, world_pixel_w - half_view.x)
	cam_pos.y = clamp(cam_pos.y, half_view.y, world_pixel_h - half_view.y)
	cam.position = cam_pos


func center_on_player_nation() -> void:
	var nat = ColonyData.get_player_nation()
	if nat.is_empty():
		return
	var ts = ChunkRenderer.TILE_SIZE
	cam_pos = Vector2(nat["capital_x"] * ts, nat["capital_y"] * ts)
	cam.position = cam_pos


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				zoom_index = clamp(zoom_index + 1, 0, zoom_steps.size() - 1)
				cam.zoom = Vector2(zoom_steps[zoom_index], zoom_steps[zoom_index])
				_clamp_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom_index = clamp(zoom_index - 1, 0, zoom_steps.size() - 1)
				cam.zoom = Vector2(zoom_steps[zoom_index], zoom_steps[zoom_index])
				_clamp_camera()
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				if event.pressed:
					drag_start = event.position
					dragging = true
				else:
					dragging = false
	if event is InputEventMouseMotion and dragging:
		var current_zoom = zoom_steps[zoom_index]
		var delta: Vector2 = drag_start - event.position
		cam_pos += delta * current_zoom
		cam.position = cam_pos
		drag_start = event.position
		_clamp_camera()

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_U and not event.echo:
			underground_enabled = not underground_enabled
			EventBus.underground_toggled.emit(underground_enabled)
		if event.keycode == KEY_SPACE and not event.echo:
			center_on_player_nation()

	# === F1-F8 Hotkey Slots ===
	if event is InputEventKey and event.pressed and not event.echo:
		var fkey = _get_fkey_slot(event.keycode)
		if fkey != "":
			if Input.is_key_pressed(KEY_CTRL):
				_save_hotkey(fkey, cam_pos)
			elif Input.is_key_pressed(KEY_SHIFT):
				_save_hotkey_named(fkey, cam_pos)
			elif hotkey_slots.has(fkey):
				_jump_to_hotkey(fkey)


func _process(delta: float) -> void:
	var move = Vector2.ZERO
	var current_zoom = zoom_steps[zoom_index]
	var speed = 8.0 / current_zoom  # Faster when zoomed out

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= speed
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += speed
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= speed
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += speed

	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport().get_visible_rect().size
	var edge = 15

	if mouse_pos.x < edge:
		move.x -= speed
	elif mouse_pos.x > screen_size.x - edge:
		move.x += speed
	if mouse_pos.y < edge:
		move.y -= speed
	elif mouse_pos.y > screen_size.y - edge:
		move.y += speed

	cam_pos += move
	cam.position = cam_pos
	_clamp_camera()

	# Apply camera shake on top of base position
	if _shake_enabled:
		_shake_timer -= delta
		if _shake_timer <= 0.0:
			_shake_enabled = false
			cam.position = cam_pos
		else:
			var intensity = _shake_intensity * (_shake_timer / _shake_duration)
			var shake_offset = Vector2(
				randf_range(-intensity, intensity),
				randf_range(-intensity, intensity)
			)
			cam.position = cam_pos + shake_offset


# =============================================================================
# F1-F8 HOTKEY SAVE-SLOTS
# =============================================================================

func _get_fkey_slot(keycode: int) -> String:
	match keycode:
		KEY_F1: return "F1"
		KEY_F2: return "F2"
		KEY_F3: return "F3"
		KEY_F4: return "F4"
		KEY_F5: return "F5"
		KEY_F6: return "F6"
		KEY_F7: return "F7"
		KEY_F8: return "F8"
	return ""


func _jump_to_hotkey(fkey: String) -> void:
	if not hotkey_slots.has(fkey):
		return
	cam_pos = hotkey_slots[fkey]
	cam.position = cam_pos
	_clamp_camera()


func _save_hotkey(fkey: String, pos: Vector2) -> void:
	hotkey_slots[fkey] = pos
	if not hotkey_names.has(fkey):
		hotkey_names[fkey] = _generate_hotkey_name(pos)
	_update_hotkey_display()


func _save_hotkey_named(fkey: String, pos: Vector2) -> void:
	hotkey_slots[fkey] = pos
	hotkey_names[fkey] = _generate_hotkey_name(pos)
	_update_hotkey_display()


func _generate_hotkey_name(pos: Vector2) -> String:
	var ts = ChunkRenderer.TILE_SIZE
	var tile_x = int(pos.x / ts)
	var tile_y = int(pos.y / ts)

	# Check for nation capitals at or near this position
	for nation in ColonyData.nations:
		var cx = nation.get("capital_x", -1)
		var cy = nation.get("capital_y", -1)
		if abs(cx - tile_x) <= 2 and abs(cy - tile_y) <= 2:
			return nation.get("name", "Unknown")

	# Check tile terrain for a descriptive name
	if tile_x >= 0 and tile_y >= 0 and tile_x < ColonyData.world_width and tile_y < ColonyData.world_height:
		var idx = tile_y * ColonyData.world_width + tile_x
		if idx < ColonyData.world_tiles.size():
			var tile = ColonyData.world_tiles[idx]
			var terrain = tile.get("terrain", "plains")
			match terrain:
				"forest": return "Forest"
				"mountain": return "Mountain"
				"hills": return "Hills"
				"swamp": return "Swamp"
				"desert": return "Desert"
				"caves": return "Cave"
				"water": return "Water"
				"coast": return "Coast"
				"plains": return "Plains"
			return terrain.capitalize()

	return "(%d, %d)" % [tile_x, tile_y]


func _update_hotkey_display() -> void:
	if not hotkey_display:
		return
	var lines: Array[String] = []
	for i in range(1, 9):
		var fkey = "F%d" % i
		var name = hotkey_names.get(fkey, "--")
		lines.append("%s: %s" % [fkey, name])
	hotkey_display.text = "\n".join(lines)


func _auto_set_capital_hotkey() -> void:
	var nat = ColonyData.get_player_nation()
	if nat.is_empty():
		return
	var ts = ChunkRenderer.TILE_SIZE
	var pos = Vector2(nat["capital_x"] * ts, nat["capital_y"] * ts)
	hotkey_slots["F1"] = pos
	hotkey_names["F1"] = nat.get("name", "Capital")
	_update_hotkey_display()
