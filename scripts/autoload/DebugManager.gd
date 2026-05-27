extends Node

# Toggle with ` key (backtick) or set debug_mode = true for always-on
var debug_mode: bool = false
var show_overlay: bool = false

# Console messages ring buffer
var _console_messages: Array[String] = []
const MAX_CONSOLE_LINES: int = 20

# File logging constants
const LOG_FILE_PATH: String = "user://thronehold.log"
const LOG_FILE_MAX_BYTES: int = 1048576  # 1 MB

# Validation results
var _check_results: Array[Dictionary] = []
var _all_checks_passed: bool = true

var _overlay: CanvasLayer = null
var _console_text: RichTextLabel = null
var _checks_text: RichTextLabel = null
var _fps_label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_write_to_log_file("=== SESSION START ===")
	_run_startup_checks()
	# Delay overlay check until scene is ready
	await get_tree().process_frame
	if debug_mode:
		show_overlay = true
		_toggle_overlay()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_QUOTELEFT:
				show_overlay = !show_overlay
				_toggle_overlay()
				get_viewport().set_input_as_handled()
			KEY_F1:
				_spawn_random_event()
				get_viewport().set_input_as_handled()
			KEY_F2:
				_add_resources(50)
				get_viewport().set_input_as_handled()
			KEY_F3:
				_advance_ticks(40)
				get_viewport().set_input_as_handled()
			KEY_F4:
				_dump_state()
				get_viewport().set_input_as_handled()
			KEY_F5:
				var sm = _find_save_manager()
				if sm and sm.save_game("user://save.json"):
					_log("[Debug] Game saved to user://save.json")
				else:
					_log("[Debug] Save failed — SaveManager not found")
				get_viewport().set_input_as_handled()
			KEY_F6:
				_toggle_time()
				get_viewport().set_input_as_handled()
			KEY_F7:
				_add_population(10)
				get_viewport().set_input_as_handled()
			KEY_F8:
				_run_system_checks()
				get_viewport().set_input_as_handled()
			KEY_F9:
				var sm = _find_save_manager()
				if sm and sm.load_game("user://save.json"):
					_log("[Debug] Game loaded from user://save.json")
				else:
					_log("[Debug] Load failed — SaveManager not found")
				get_viewport().set_input_as_handled()

func _run_startup_checks() -> void:
	_check_results.clear()
	_all_checks_passed = true

	_check("Autoloads loaded", func() -> bool:
		return GameManager != null and EventBus != null and ColonyData != null
	)

	_check("ColonyData has races", func() -> bool:
		return ColonyData.RACES.size() >= 3
	)

	_check("ColonyData has terrains", func() -> bool:
		return ColonyData.TERRAINS.size() >= 5
	)

	_check("EventBus has signals", func() -> bool:
		return EventBus.has_signal("tick_advanced")
	)

	_log("[Debug] Startup checks: %d passed, %d failed" % [
		_count_passed(), _check_results.size() - _count_passed()
	])

func _run_system_checks() -> void:
	_check_results.clear()
	_all_checks_passed = true

	_check("World tiles allocated", func() -> bool:
		return ColonyData.world_tiles.size() == ColonyData.world_width * ColonyData.world_height
	)

	_check("Nations exist", func() -> bool:
		return ColonyData.nations.size() > 0
	)

	_check("Player nation assigned", func() -> bool:
		return ColonyData.player_nation_id >= 0
	)

	_check("Player nation valid", func() -> bool:
		return not ColonyData.get_player_nation().is_empty()
	)

	_check("World has non-water tiles", func() -> bool:
		for tile in ColonyData.world_tiles:
			if tile["terrain"] != "water":
				return true
		return false
	)

	_check("Diplomacy matrix matches nations", func() -> bool:
		return ColonyData.diplomacy_matrix.size() == ColonyData.nations.size()
	)

	_check("Time manager running", func() -> bool:
		var root = get_tree().current_scene
		if not root:
			return false
		var sys = root.get_node_or_null("Systems")
		if not sys:
			return false
		var tm = sys.get_node_or_null("TimeManager")
		return tm != null and tm.is_processing()
	)

	_check("Resource flow active", func() -> bool:
		var nat = ColonyData.get_player_nation()
		if nat.is_empty():
			return false
		return nat["resources"]["food"] > 0 or ColonyData.current_tick > 50
	)

	_log("[Debug] Runtime checks: %d passed, %d failed" % [
		_count_passed(), _check_results.size() - _count_passed()
	])

	# Print failures
	for r in _check_results:
		if not r["passed"]:
			_log_error("[FAIL] %s: %s" % [r["name"], r["message"]])

func _check(name: String, test: Callable) -> void:
	var passed = false
	var message = "OK"
	if test.is_valid():
		passed = test.call()
		if not passed:
			message = "FAILED"
	else:
		message = "INVALID CALLABLE"
	_all_checks_passed = _all_checks_passed and passed
	_check_results.append({"name": name, "passed": passed, "message": message})

func _count_passed() -> int:
	var count = 0
	for r in _check_results:
		if r["passed"]:
			count += 1
	return count

# --- Debug Actions ---

func _spawn_random_event() -> void:
	var eligible: Array[Dictionary] = []
	# EventManager is a system node, access via scene tree
	var root = get_tree().current_scene
	var sys = root.get_node_or_null("Systems") if root else null
	var em = sys.get_node_or_null("EventManager") if sys else null
	if not em:
		_log("[Debug] EventManager not found")
		return
	for ev in em.event_pool:
		if ColonyData.current_year >= ev["min_year"]:
			eligible.append(ev)
	if eligible.is_empty():
		_log("[Debug] No eligible events to spawn")
		return

	var ev = eligible[randi() % eligible.size()]
	EventBus.event_triggered.emit(ColonyData.player_nation_id, ev["id"], ev)
	_log("[Debug] Spawned event: %s" % ev["name"])

func _add_resources(amount: float) -> void:
	var nat = ColonyData.get_player_nation()
	if nat.is_empty():
		return
	for res in nat["resources"]:
		nat["resources"][res] += amount
	EventBus.resources_updated.emit(nat["id"], nat["resources"].duplicate())
	_log("[Debug] Added %.0f to all resources" % amount)

func _advance_ticks(count: int) -> void:
	_log("[Debug] Advancing %d ticks..." % count)
	# Fast-forward: set speed to max, do ticks, restore
	var root = get_tree().current_scene
	if not root:
		return
	var sys = root.get_node_or_null("Systems")
	if not sys:
		return
	var tm = sys.get_node_or_null("TimeManager")
	if not tm:
		return

	var was_paused: bool = tm.is_paused
	var was_speed: float = tm.speed_multiplier
	tm.is_paused = false
	tm.speed_multiplier = 8.0

	for _i in range(count):
		tm._advance_tick()
		await get_tree().process_frame

	tm.speed_multiplier = was_speed
	tm.is_paused = was_paused
	_log("[Debug] Advanced %d ticks complete" % count)

func _dump_state() -> void:
	_log("=== STATE DUMP ===")
	_log("Tick: %d | Day: %d | Season: %s | Year: %d" % [
		ColonyData.current_tick, ColonyData.current_day,
		ColonyData.current_season, ColonyData.current_year
	])

	for n in ColonyData.nations:
		var marker = " [YOU]" if n["id"] == ColonyData.player_nation_id else ""
		_log("Nation %d: %s%s | Pop: %d | Mil: %d" % [
			n["id"], n["name"], marker,
			n["population"], n["military_strength"]
		])
		_log("  Resources: %s" % var_to_str(n["resources"]))

	_log("Diplomacy matrix: %s" % var_to_str(ColonyData.diplomacy_matrix))
	_log("==================")

func _toggle_time() -> void:
	var root = get_tree().current_scene
	if not root:
		return
	var sys = root.get_node_or_null("Systems")
	if not sys:
		return
	var tm = sys.get_node_or_null("TimeManager")
	if not tm:
		return
	tm.is_paused = !tm.is_paused
	_log("[Debug] Time %s" % ["PAUSED" if tm.is_paused else "RUNNING"])

func _add_population(amount: int) -> void:
	var nat = ColonyData.get_player_nation()
	if nat.is_empty():
		return
	nat["population"] += amount
	EventBus.population_changed.emit(nat["id"], nat["population"])
	EventBus.colonist_arrived.emit(nat["id"], amount)
	_log("[Debug] Added %d population (now %d)" % [amount, nat["population"]])

func _find_save_manager() -> Node:
	var root = get_tree().current_scene
	if not root:
		return null
	var sys = root.get_node_or_null("Systems")
	if not sys:
		return null
	return sys.get_node_or_null("SaveManager")


# --- Logging ---

func log(message: String) -> void:
	_log(message)

func _log(message: String) -> void:
	_console_messages.push_front("[%d] %s" % [ColonyData.current_tick, message])
	if _console_messages.size() > MAX_CONSOLE_LINES:
		_console_messages.resize(MAX_CONSOLE_LINES)
	print_rich(message)
	_write_to_log_file(message)

func _log_error(message: String) -> void:
	push_error(message)
	_log(message)

func _write_to_log_file(message: String) -> void:
	var timestamp = Time.get_datetime_string_from_system(true)
	var log_line = "[%s] %s\n" % [timestamp, message]

	# Rotate if file exceeds max size
	var existing: FileAccess = FileAccess.open(LOG_FILE_PATH, FileAccess.READ)
	if existing:
		if existing.get_length() >= LOG_FILE_MAX_BYTES:
			existing.close()
			if FileAccess.file_exists(LOG_FILE_PATH + ".old"):
				DirAccess.remove_absolute(LOG_FILE_PATH + ".old")
			DirAccess.rename_absolute(LOG_FILE_PATH, LOG_FILE_PATH + ".old")
		else:
			existing.close()

	# Append to log file
	var file = FileAccess.open(LOG_FILE_PATH, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_string(log_line)
		file.close()

# --- Debug Overlay ---

func _toggle_overlay() -> void:
	if show_overlay:
		if not _overlay:
			_create_overlay()
		else:
			_overlay.show()
	else:
		if _overlay:
			_overlay.hide()

func _create_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "DebugOverlay"
	_overlay.layer = 100  # Always on top

	var bg = PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	bg.set_anchor(SIDE_LEFT, 0.65)
	bg.set_offset(SIDE_TOP, 36)
	bg.set_offset(SIDE_BOTTOM, -40)
	bg.self_modulate = Color(0, 0, 0, 0.8)

	var vbox = VBoxContainer.new()

	# Title
	var title = Label.new()
	title.text = "--- DEBUG CONSOLE (` key toggles) ---"
	title.add_theme_color_override("font_color", Color.CYAN)
	title.add_theme_font_size_override("font_size", 11)
	vbox.add_child(title)

	# Shortcuts
	var shortcuts = Label.new()
	shortcuts.text = "F1:Event F2:+Res F3:+40t F4:Dump F5:Save F6:Pause F7:+Pop F8:Chk F9:Load"
	shortcuts.add_theme_color_override("font_color", Color.GRAY)
	shortcuts.add_theme_font_size_override("font_size", 9)
	vbox.add_child(shortcuts)

	# FPS
	_fps_label = Label.new()
	_fps_label.add_theme_color_override("font_color", Color.WHITE)
	_fps_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(_fps_label)

	# Separator
	vbox.add_child(HSeparator.new())

	# Console log
	_console_text = RichTextLabel.new()
	_console_text.bbcode_enabled = true
	_console_text.fit_content = true
	_console_text.add_theme_font_size_override("font_size", 10)
	_console_text.add_theme_color_override("default_color", Color.LIME_GREEN)
	_console_text.scroll_following = true
	_console_text.custom_minimum_size = Vector2(0, 180)
	vbox.add_child(_console_text)

	# Separator
	vbox.add_child(HSeparator.new())

	# Checks
	_checks_text = RichTextLabel.new()
	_checks_text.bbcode_enabled = true
	_checks_text.fit_content = true
	_checks_text.add_theme_font_size_override("font_size", 10)
	vbox.add_child(_checks_text)

	bg.add_child(vbox)
	_overlay.add_child(bg)

	get_tree().root.add_child(_overlay)
	_refresh_overlay()

func _process(_delta: float) -> void:
	if _overlay and _overlay.visible:
		_refresh_overlay()

func _refresh_overlay() -> void:
	if not _overlay:
		return

	# FPS
	if _fps_label:
		var fps = Engine.get_frames_per_second()
		_fps_label.text = "FPS: %.0f | Tick: %d | Year: %d %s D%d" % [
			fps,
			ColonyData.current_tick,
			ColonyData.current_year,
			ColonyData.current_season,
			ColonyData.current_day
		]
		if fps < 30.0 and fps > 0.0:
			_log("[WARN] FPS dropped to %.0f — performance degradation detected" % fps)

	# Console
	if _console_text:
		var bb = ""
		for i in range(_console_messages.size() - 1, -1, -1):
			bb += _console_messages[i] + "\n"
		_console_text.text = bb

	# Checks
	if _checks_text:
		var bb = ""
		for r in _check_results:
			var color = "#44ff44" if r["passed"] else "#ff4444"
			var icon = "[OK]" if r["passed"] else "[FAIL]"
			bb += "[color=%s]%s[/color] %s\n" % [color, icon, r["name"]]
		if _check_results.is_empty():
			bb = "No checks run yet. Press F5."
		_checks_text.text = bb
