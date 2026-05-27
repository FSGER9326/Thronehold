extends CanvasLayer

# StrategyHudShell is the first pass at a cleaner strategy-game UI architecture.
# It intentionally sits above the legacy GameUI while the older script remains
# available as a compatibility layer for existing signals, modal screens, and
# gameplay callbacks.
#
# Design goals:
# - Keep the map dominant.
# - Show only vital state persistently.
# - Put deep data in an inspector or modal ledger.
# - Make actions contextual instead of exposing every system at once.

const COL_BG := Color(0.035, 0.030, 0.026, 0.94)
const COL_PANEL := Color(0.075, 0.058, 0.045, 0.92)
const COL_PANEL_DARK := Color(0.045, 0.038, 0.034, 0.96)
const COL_BORDER := Color(0.55, 0.42, 0.20, 0.55)
const COL_GOLD := Color(0.95, 0.78, 0.38, 1.0)
const COL_TEXT := Color(0.86, 0.82, 0.72, 1.0)
const COL_MUTED := Color(0.56, 0.55, 0.50, 1.0)
const COL_BLUE := Color(0.40, 0.58, 0.72, 1.0)
const COL_WARN := Color(0.95, 0.58, 0.22, 1.0)
const COL_DANGER := Color(0.82, 0.28, 0.22, 1.0)
const COL_GOOD := Color(0.35, 0.70, 0.38, 1.0)

var _legacy_ui: Node = null
var _root: Control
var _top_bar: PanelContainer
var _command_rail: PanelContainer
var _inspector: PanelContainer
var _context_bar: PanelContainer
var _modal_layer: Control
var _tooltip: Label
var _toast_column: VBoxContainer
var _resources_label: RichTextLabel
var _date_label: Label
var _speed_label: Label
var _inspector_title: Label
var _inspector_body: RichTextLabel
var _context_title: Label
var _context_actions: HBoxContainer
var _active_modal: PanelContainer = null
var _speed_levels: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0]
var _speed_index := 2
var _last_legacy_probe := 0.0


func _ready() -> void:
	layer = 30
	_build_shell()
	call_deferred("_attach_to_legacy_ui")
	call_deferred("_refresh_all")


func _process(delta: float) -> void:
	_last_legacy_probe += delta
	if _last_legacy_probe > 1.0:
		_last_legacy_probe = 0.0
		_attach_to_legacy_ui()
	_refresh_top_bar()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			if _active_modal:
				_close_modal()
				get_viewport().set_input_as_handled()
		KEY_SPACE:
			_call_legacy("_on_pause_pressed")
			get_viewport().set_input_as_handled()
		KEY_PLUS, KEY_EQUAL:
			_change_speed(1)
			get_viewport().set_input_as_handled()
		KEY_MINUS:
			_change_speed(-1)
			get_viewport().set_input_as_handled()


func _attach_to_legacy_ui() -> void:
	if _legacy_ui == null:
		_legacy_ui = get_parent().get_node_or_null("GameUI")
	if _legacy_ui == null:
		return

	# Hide the crowded legacy HUD, but keep the node alive so old signals,
	# save/load callbacks, and deeper panels still exist during the migration.
	for child in _legacy_ui.get_children():
		if child is Control and child.name in [
			"TopStatusBar",
			"OutlinerPanel",
			"InfoPanel",
			"BuildSelectPanel",
			"BottomActionBar"
		]:
			child.hide()


func _build_shell() -> void:
	_root = Control.new()
	_root.name = "StrategyHUDRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_top_bar()
	_build_command_rail()
	_build_inspector()
	_build_context_bar()
	_build_modal_layer()
	_build_toasts()
	_build_tooltip()


func _build_top_bar() -> void:
	_top_bar = _panel("TopBar", COL_PANEL_DARK, 1)
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_bar.offset_left = 8
	_top_bar.offset_top = 8
	_top_bar.offset_right = -8
	_top_bar.offset_bottom = 58
	_top_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_top_bar)

	var margin := _margin(12, 6, 12, 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	_top_bar.add_child(margin)

	_resources_label = RichTextLabel.new()
	_resources_label.name = "ResourceStrip"
	_resources_label.bbcode_enabled = true
	_resources_label.scroll_active = false
	_resources_label.fit_content = true
	_resources_label.custom_minimum_size = Vector2(520, 34)
	_resources_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resources_label.add_theme_color_override("default_color", COL_TEXT)
	row.add_child(_resources_label)

	row.add_child(_thin_separator(true))

	_date_label = _label("Year 1, Spring — Day 1", 13, COL_GOLD)
	_date_label.custom_minimum_size = Vector2(190, 0)
	row.add_child(_date_label)

	row.add_child(_thin_separator(true))
	row.add_child(_top_button("Pause", "Pause / resume time", func(): _call_legacy("_on_pause_pressed")))
	row.add_child(_top_button("−", "Decrease speed", func(): _change_speed(-1), Vector2(34, 34)))

	_speed_label = _label("1.0x", 13, COL_BLUE)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.custom_minimum_size = Vector2(54, 0)
	row.add_child(_speed_label)

	row.add_child(_top_button("+", "Increase speed", func(): _change_speed(1), Vector2(34, 34)))
	row.add_child(_top_button("Home", "Center on capital", func(): _call_legacy("_on_home_pressed")))
	row.add_child(_top_button("Save", "Save the current game", func(): _call_legacy("_on_save_pressed")))


func _build_command_rail() -> void:
	_command_rail = _panel("CommandRail", COL_PANEL, 1)
	_command_rail.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_command_rail.offset_left = 8
	_command_rail.offset_top = 68
	_command_rail.offset_right = 108
	_command_rail.offset_bottom = -88
	_command_rail.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_command_rail)

	var margin := _margin(8, 8, 8, 8)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	margin.add_child(col)
	_command_rail.add_child(margin)

	col.add_child(_rail_button("Build", "Construction and settlement projects", func(): _call_legacy("_toggle_placement_mode")))
	col.add_child(_rail_button("Divine", "Miracles, influence, prophets", func(): _open_modal("Divine Powers", _modal_text_divine())))
	col.add_child(_rail_button("Army", "Military forces and conflicts", func(): _open_modal("Military", _modal_text_military())))
	col.add_child(_rail_button("Diplo", "Relations, factions, wars", func(): _call_legacy("_show_diplomacy_panel")))
	col.add_child(_rail_button("Tech", "Research and discoveries", func(): _call_legacy("_show_tech_panel")))
	col.add_child(_rail_button("Faith", "Pantheon and culture", func(): _call_legacy("_show_pantheon_panel")))
	col.add_child(_rail_button("Chron", "History, log, events", func(): _call_legacy("_show_log_panel")))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	col.add_child(_rail_button("Help", "UI overview", func(): _open_modal("How to read the strategy UI", _modal_text_help())))


func _build_inspector() -> void:
	_inspector = _panel("InspectorPanel", COL_PANEL, 1)
	_inspector.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_inspector.set_anchor(SIDE_LEFT, 0.765)
	_inspector.offset_top = 68
	_inspector.offset_right = -8
	_inspector.offset_bottom = -88
	_inspector.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_inspector)

	var margin := _margin(12, 10, 12, 10)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	_inspector.add_child(margin)

	_inspector_title = _label("Realm Inspector", 16, COL_GOLD)
	col.add_child(_inspector_title)
	col.add_child(_thin_separator(false))

	_inspector_body = RichTextLabel.new()
	_inspector_body.bbcode_enabled = true
	_inspector_body.fit_content = true
	_inspector_body.scroll_active = true
	_inspector_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_inspector_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inspector_body.add_theme_color_override("default_color", COL_TEXT)
	_inspector_body.text = "Select a tile, nation, settlement, army, prophet, or event.\n\nThe inspector explains why it matters and what you can do next."
	col.add_child(_inspector_body)


func _build_context_bar() -> void:
	_context_bar = _panel("ContextActionBar", COL_PANEL_DARK, 1)
	_context_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_context_bar.offset_left = 118
	_context_bar.offset_top = -78
	_context_bar.offset_right = -8
	_context_bar.offset_bottom = -8
	_context_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_context_bar)

	var margin := _margin(12, 8, 12, 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	_context_bar.add_child(margin)

	_context_title = _label("No selection", 14, COL_GOLD)
	_context_title.custom_minimum_size = Vector2(160, 0)
	row.add_child(_context_title)
	row.add_child(_thin_separator(true))

	_context_actions = HBoxContainer.new()
	_context_actions.add_theme_constant_override("separation", 8)
	_context_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_context_actions)
	_set_default_context_actions()


func _build_modal_layer() -> void:
	_modal_layer = Control.new()
	_modal_layer.name = "ModalLayer"
	_modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_modal_layer)


func _build_toasts() -> void:
	_toast_column = VBoxContainer.new()
	_toast_column.name = "ToastColumn"
	_toast_column.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toast_column.offset_left = -330
	_toast_column.offset_top = 68
	_toast_column.offset_right = -122
	_toast_column.offset_bottom = 260
	_toast_column.add_theme_constant_override("separation", 6)
	_toast_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast_column)


func _build_tooltip() -> void:
	_tooltip = _label("", 11, COL_BLUE)
	_tooltip.name = "HUDTooltip"
	_tooltip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_tooltip.offset_left = 118
	_tooltip.offset_top = -104
	_tooltip.offset_right = 620
	_tooltip.offset_bottom = -82
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tooltip)


func _refresh_all() -> void:
	_refresh_top_bar()
	_refresh_inspector()
	_set_default_context_actions()


func _refresh_top_bar() -> void:
	var nation := _get_player_nation()
	if nation.is_empty():
		_resources_label.text = "[color=#d8c28a]Food[/color] --  [color=#d8c28a]Wood[/color] --  [color=#d8c28a]Stone[/color] --  [color=#d8c28a]Metal[/color] --  [color=#d8c28a]Gold[/color] --"
	else:
		var res: Dictionary = nation.get("resources", {})
		_resources_label.text = "[color=#d8c28a]Food[/color] %s   [color=#d8c28a]Wood[/color] %s   [color=#d8c28a]Stone[/color] %s   [color=#d8c28a]Metal[/color] %s   [color=#d8c28a]Gold[/color] %s" % [
			_fmt_num(res.get("food", 0)),
			_fmt_num(res.get("wood", 0)),
			_fmt_num(res.get("stone", 0)),
			_fmt_num(res.get("metal", 0)),
			_fmt_num(res.get("gold", 0)),
		]

	if GameManager and GameManager.has_method("get_current_date_string"):
		_date_label.text = str(GameManager.call("get_current_date_string"))
	elif ColonyData:
		_date_label.text = "Year %s" % str(ColonyData.get("current_year") if "current_year" in ColonyData else 1)
	_speed_label.text = "%sx" % str(_speed_levels[_speed_index])


func _refresh_inspector() -> void:
	var nation := _get_player_nation()
	if nation.is_empty():
		_inspector_title.text = "Realm Inspector"
		_inspector_body.text = "[color=#d8c28a]No realm selected yet.[/color]\n\nStart or load a game, then use this panel as the one readable place for the current selection."
		return

	_inspector_title.text = str(nation.get("name", "Player Realm"))
	var lines: Array[String] = []
	lines.append("[color=#d8c28a]Race[/color] %s" % str(nation.get("race", "unknown")).capitalize())
	lines.append("[color=#d8c28a]Capital[/color] %s, %s" % [str(nation.get("capital_x", "?")), str(nation.get("capital_y", "?"))])
	lines.append("[color=#d8c28a]Population[/color] %s" % _fmt_num(nation.get("population", 0)))
	lines.append("[color=#d8c28a]Stability[/color] %s" % _fmt_num(nation.get("stability", 0)))
	lines.append("\n[color=#88aacc]Next useful actions[/color]")
	lines.append("• Build near the capital")
	lines.append("• Inspect nearby hostile borders")
	lines.append("• Open Divine to spend influence")
	lines.append("• Open Tech to check long-term direction")
	_inspector_body.text = "\n".join(lines)


func _set_default_context_actions() -> void:
	for child in _context_actions.get_children():
		child.queue_free()
	_context_title.text = "Realm actions"
	_context_actions.add_child(_action_button("Build", "Open construction", func(): _call_legacy("_toggle_placement_mode")))
	_context_actions.add_child(_action_button("Divine Power", "Open deity actions", func(): _open_modal("Divine Powers", _modal_text_divine())))
	_context_actions.add_child(_action_button("Diplomacy", "Open diplomacy ledger", func(): _call_legacy("_show_diplomacy_panel")))
	_context_actions.add_child(_action_button("Research", "Open research ledger", func(): _call_legacy("_show_tech_panel")))
	_context_actions.add_child(_action_button("Chronicle", "Open event log", func(): _call_legacy("_show_log_panel")))


func _open_modal(title: String, body: String) -> void:
	_close_modal()
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.name = "ModalDim"
	dim.color = Color(0, 0, 0, 0.42)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_layer.add_child(dim)

	_active_modal = _panel("Modal", COL_PANEL_DARK, 2)
	_active_modal.set_anchors_preset(Control.PRESET_CENTER)
	_active_modal.custom_minimum_size = Vector2(780, 520)
	_active_modal.offset_left = -390
	_active_modal.offset_top = -260
	_active_modal.offset_right = 390
	_active_modal.offset_bottom = 260
	_active_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer.add_child(_active_modal)

	var margin := _margin(18, 14, 18, 14)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	_active_modal.add_child(margin)

	var header := HBoxContainer.new()
	header.add_child(_label(title, 18, COL_GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(_top_button("Close", "Close this ledger", func(): _close_modal(), Vector2(82, 34)))
	col.add_child(header)
	col.add_child(_thin_separator(false))

	var content := RichTextLabel.new()
	content.bbcode_enabled = true
	content.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.scroll_active = true
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_color_override("default_color", COL_TEXT)
	content.text = body
	col.add_child(content)


func _close_modal() -> void:
	for child in _modal_layer.get_children():
		child.queue_free()
	_active_modal = null
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _change_speed(dir: int) -> void:
	_speed_index = clamp(_speed_index + dir, 0, _speed_levels.size() - 1)
	_speed_label.text = "%sx" % str(_speed_levels[_speed_index])
	if _legacy_ui and _legacy_ui.has_method("_change_speed"):
		_legacy_ui.call("_change_speed", dir)


func _call_legacy(method_name: String) -> void:
	_attach_to_legacy_ui()
	if _legacy_ui and _legacy_ui.has_method(method_name):
		_legacy_ui.call(method_name)
		_show_toast("Command", method_name.replace("_", " ").strip_edges().capitalize())
	else:
		_show_toast("Not wired yet", "%s has no legacy callback." % method_name, COL_WARN)


func _show_toast(title: String, body: String, accent: Color = COL_BLUE) -> void:
	var toast := _panel("Toast", Color(COL_PANEL.r, COL_PANEL.g, COL_PANEL.b, 0.96), 1)
	toast.custom_minimum_size = Vector2(208, 58)
	var margin := _margin(8, 6, 8, 6)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.add_child(_label(title, 12, accent))
	col.add_child(_label(body, 10, COL_TEXT))
	margin.add_child(col)
	toast.add_child(margin)
	_toast_column.add_child(toast)
	if _toast_column.get_child_count() > 3:
		_toast_column.get_child(0).queue_free()
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		if is_instance_valid(toast):
			toast.queue_free()
	)


func _get_player_nation() -> Dictionary:
	if ColonyData and ColonyData.has_method("get_player_nation"):
		var nation = ColonyData.call("get_player_nation")
		if nation is Dictionary:
			return nation
	return {}


func _fmt_num(value) -> String:
	if value is float:
		return str(round(value))
	return str(value)


func _modal_text_help() -> String:
	return "[color=#d8c28a]Main rule:[/color] the map is the game. The HUD only frames decisions.\n\n[color=#d8c28a]Top bar[/color]\nResources, time, speed, pause, home and save.\n\n[color=#d8c28a]Left rail[/color]\nPrimary command categories. These are stable, muscle-memory actions.\n\n[color=#d8c28a]Right inspector[/color]\nThe current thing you care about: selected realm, tile, army, prophet, settlement, event.\n\n[color=#d8c28a]Bottom context bar[/color]\nOnly actions that make sense right now. This is where decision pressure should live.\n\n[color=#d8c28a]Ledgers[/color]\nDeep systems such as diplomacy, research, pantheon and chronicles should use focused modal screens instead of crowding the map."


func _modal_text_divine() -> String:
	return "[color=#d8c28a]Divine Powers[/color]\n\nThis is the future home for miracles, omens, prophet commands, holy sites, blessings, curses and influence spending.\n\nThe important design change is that divine actions should be contextual: select a tile, nation, army, settlement or prophet first, then show only powers that can affect it."


func _modal_text_military() -> String:
	return "[color=#d8c28a]Military Ledger[/color]\n\nThis screen should summarize armies, wars, hostile borders, raids, monster pressure and defensive priorities.\n\nThe map should answer [color=#88aacc]where[/color]. This ledger should answer [color=#88aacc]how bad is it and what can I do[/color]."


func _panel(node_name: String, bg: Color, border_width: int = 1) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = COL_BORDER
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(text: String, size: int = 12, color: Color = COL_TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	return label


func _top_button(text: String, tip: String, cb: Callable, min_size := Vector2(72, 34)) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.tooltip_text = tip
	btn.custom_minimum_size = min_size
	btn.pressed.connect(cb)
	btn.mouse_entered.connect(func(): _tooltip.text = tip)
	btn.mouse_exited.connect(func(): _tooltip.text = "")
	_apply_button_style(btn)
	return btn


func _rail_button(text: String, tip: String, cb: Callable) -> Button:
	var btn := _top_button(text, tip, cb, Vector2(0, 44))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 12)
	return btn


func _action_button(text: String, tip: String, cb: Callable) -> Button:
	var btn := _top_button(text, tip, cb, Vector2(132, 40))
	btn.add_theme_font_size_override("font_size", 12)
	return btn


func _apply_button_style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.10, 0.075, 0.95)
	normal.border_color = Color(0.50, 0.38, 0.18, 0.60)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.17, 0.13, 0.085, 0.98)
	hover.border_color = COL_GOLD
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.08, 0.065, 0.050, 1.0)
	pressed.border_color = COL_BLUE
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_hover_color", COL_GOLD)


func _thin_separator(vertical: bool) -> Control:
	var rect := ColorRect.new()
	rect.color = Color(0.75, 0.62, 0.36, 0.30)
	if vertical:
		rect.custom_minimum_size = Vector2(1, 28)
	else:
		rect.custom_minimum_size = Vector2(0, 1)
	return rect


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin
