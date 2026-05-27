extends Node2D

var cam: Camera2D
var cam_pos: Vector2 = Vector2(640, 360)
var zoom_level: float = 1.0
var drag_start: Vector2 = Vector2.ZERO
var dragging: bool = false
var underground_enabled: bool = false

# Camera shake state
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0
var _shake_enabled: bool = false


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

	# Deferred world generation: only generate now if we're in WORLD_SETUP state
	if GameManager.current_state == GameManager.GameState.WORLD_SETUP:
		_run_world_generation(systems)
	else:
		print("[Main] Waiting for class selection before generating world...")
		call_deferred("_capture_screenshot")
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

	print("[Main] Deity class selection complete. Starting world...")
	GameManager.world_setup_complete()

	
	print("[Main] Game systems ready. %d nations. %d characters." % [
		ColonyData.nations.size(), ColonyData.characters.size()
	])

	# Start time and play
	var tm = systems.get_node_or_null("TimeManager")
	if tm: tm.start()
	GameManager.change_state(GameManager.GameState.PLAYING)
	print("[Main] Auto-play: world ready, time started. %d nations." % ColonyData.nations.size())

	# Capture screenshot after rendering
	call_deferred("_capture_screenshot")


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
	var world_pixel_w = float(ColonyData.world_width * 16)
	var world_pixel_h = float(ColonyData.world_height * 16)
	var half_view = viewport_size * zoom_level * 0.5
	cam_pos.x = clamp(cam_pos.x, half_view.x, world_pixel_w - half_view.x)
	cam_pos.y = clamp(cam_pos.y, half_view.y, world_pixel_h - half_view.y)
	cam.position = cam_pos


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				zoom_level *= 1.1
				zoom_level = clamp(zoom_level, 0.3, 4.0)
				cam.zoom = Vector2(zoom_level, zoom_level)
				_clamp_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom_level *= 0.9
				zoom_level = clamp(zoom_level, 0.3, 4.0)
				cam.zoom = Vector2(zoom_level, zoom_level)
				_clamp_camera()
			MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					drag_start = event.position
					dragging = true
				else:
					dragging = false
	if event is InputEventMouseMotion and dragging:
		var delta: Vector2 = drag_start - event.position
		cam_pos += delta * zoom_level
		cam.position = cam_pos
		drag_start = event.position
		_clamp_camera()

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_U and not event.echo:
			underground_enabled = not underground_enabled
			EventBus.underground_toggled.emit(underground_enabled)


func _process(delta: float) -> void:
	var move = Vector2.ZERO

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 5
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 5
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 5
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 5

	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport().get_visible_rect().size
	var edge = 20

	if mouse_pos.x < edge:
		move.x -= 3
	elif mouse_pos.x > screen_size.x - edge:
		move.x += 3
	if mouse_pos.y < edge:
		move.y -= 3
	elif mouse_pos.y > screen_size.y - edge:
		move.y += 3

	# Apply camera movement (resets base position)
	if move != Vector2.ZERO:
		cam_pos += move * zoom_level
		_clamp_camera()
	else:
		cam.position = cam_pos

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
