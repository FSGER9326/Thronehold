@tool
extends SceneTree

# Automated UI screenshot capture for visual QA
# Usage: godot --headless --script res://scripts/tests/screenshot_test.gd

var _output_dir = "user://screenshots/"
var _screenshots_taken: int = 0

func _init() -> void:
	await _capture_screenshots()
	quit()

func _capture_screenshots() -> void:
	# Create output directory
	DirAccess.make_dir_recursive_absolute(_output_dir)

	# Load the main scene
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame  # Wait for UI to build

	var game_ui = _find_game_ui()
	if not game_ui:
		print("[Screenshot] GameUI not found")
		return

	_hide_all_ui_overlays(game_ui)
	_show_named_panel(game_ui, "main_menu")
	await process_frame
	_take_screenshot(_output_dir + "main_menu.png")
	_screenshots_taken += 1
	print("[Screenshot] Captured: Main Menu -> %s" % (_output_dir + "main_menu.png"))

	_hide_all_ui_overlays(game_ui)
	_show_named_panel(game_ui, "class_select")
	await process_frame
	_take_screenshot(_output_dir + "class_select.png")
	_screenshots_taken += 1
	print("[Screenshot] Captured: Class Selection -> %s" % (_output_dir + "class_select.png"))

	await _prepare_gameplay_state(game_ui)
	_take_screenshot(_output_dir + "gameplay_hud.png")
	_screenshots_taken += 1
	print("[Screenshot] Captured: Gameplay HUD -> %s" % (_output_dir + "gameplay_hud.png"))

	# List of panels to capture
	var panels_to_capture = [
		{"key": "policy_panel", "name": "Policy Panel", "action": "Policies"},
		{"key": "skill_tree_panel", "name": "Skill Tree Panel", "action": "Skill Tree"},
		{"key": "influence_panel", "name": "Influence Panel", "action": "Influence"},
		{"key": "prophet_panel", "name": "Prophet Panel", "action": "Prophets"},
		{"key": "diplomacy_panel", "name": "Diplomacy Panel", "action": "Diplomacy"},
		{"key": "deity_panel", "name": "Divine Miracles Panel", "action": "Miracles"},
		{"key": "government_panel", "name": "Government Panel", "action": "Government"},
		{"key": "history_panel", "name": "History Panel", "action": "History"},
		{"key": "log_panel", "name": "Event Log Panel", "action": "Log"},
		{"key": "faction_panel", "name": "Factions Panel", "action": "Factions"},
		{"key": "tech_panel", "name": "Technology Panel", "action": "Technologies"},
		{"key": "culture_panel", "name": "Culture Panel", "action": "Culture"},
		{"key": "pantheon_panel", "name": "Pantheon Panel", "action": "Pantheon"},
	]

	for panel in panels_to_capture:
		# Open panel if it has an action
		if panel["action"]:
			_open_panel(panel["action"])
			await process_frame
			await process_frame
		
		var path = _output_dir + panel["key"] + ".png"
		_take_screenshot(path)
		_screenshots_taken += 1
		print("[Screenshot] Captured: %s → %s" % [panel["name"], path])
		
		# Close panel for next capture
		if panel["key"] != "main_menu" and panel["key"] != "class_select":
			_close_panels()
			await process_frame

	# Also capture full game view
	_close_panels()
	await process_frame
	_take_screenshot(_output_dir + "full_game_view.png")
	_screenshots_taken += 1
	
	# Capture debug overlay
	# Press ` key to toggle debug
	var input = InputEventKey.new()
	input.keycode = KEY_QUOTELEFT
	input.pressed = true
	Input.parse_input_event(input)
	await process_frame
	await process_frame
	_take_screenshot(_output_dir + "debug_overlay.png")
	_screenshots_taken += 1

	print("[Screenshot] Done. %d screenshots captured to %s" % [_screenshots_taken, _output_dir])

func _open_panel(panel_name: String) -> void:
	var game_ui = _find_game_ui()
	if not game_ui:
		return

	var root = current_scene
	var bottom_bar = _find_bottom_bar(root)
	if bottom_bar:
		var btn = _find_button_by_text(bottom_bar, panel_name)
		if btn:
			btn.pressed.emit()

func _close_panels() -> void:
	var game_ui = _find_game_ui()
	if not game_ui:
		return
	for key in game_ui._panels:
		if str(key).ends_with("_panel"):
			var panel = game_ui._panels[key]
			if panel is Control:
				panel.hide()

func _hide_all_ui_overlays(game_ui: CanvasLayer) -> void:
	for key in game_ui._panels:
		var panel = game_ui._panels[key]
		if panel is Control and (key == "main_menu" or key == "class_select" or str(key).ends_with("_panel")):
			panel.hide()

func _show_named_panel(game_ui: CanvasLayer, panel_key: String) -> void:
	var panel = game_ui._panels.get(panel_key)
	if panel is Control:
		panel.show()

func _prepare_gameplay_state(game_ui: CanvasLayer) -> void:
	_hide_all_ui_overlays(game_ui)
	var systems = _find_systems_node()
	var dm = systems.get_node_or_null("DeityManager") if systems else null
	if dm and dm.deity_class.is_empty():
		var class_ids = dm.DEITY_CLASSES.keys()
		if not class_ids.is_empty():
			dm.select_class(class_ids[0])

	var gm = _get_game_manager()
	if gm and gm.current_state != gm.GameState.PLAYING:
		gm.class_selection_complete()

	for _i in range(45):
		await process_frame

	game_ui._show_player_controls()
	game_ui._refresh_all()

func _take_screenshot(path: String) -> void:
	var img = get_root().get_texture().get_image()
	if img:
		img.save_png(path)

func _find_game_ui() -> CanvasLayer:
	var root = current_scene
	if root:
		return root.get_node_or_null("GameUI") as CanvasLayer
	return null

func _find_bottom_bar(root: Node) -> Control:
	if not root:
		return null
	var game_ui = root.get_node_or_null("GameUI")
	if game_ui:
		return game_ui.get_node_or_null("BottomActionBar") as Control
	return null

func _find_button_by_text(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var btn = _find_button_by_text(child, text)
		if btn:
			return btn
	return null

func _get_game_manager() -> Node:
	return root.get_node_or_null("GameManager")

func _find_systems_node() -> Node:
	var scene = current_scene
	if not scene:
		return null
	return scene.get_node_or_null("Systems")
