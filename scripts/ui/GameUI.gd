extends CanvasLayer

var _panels: Dictionary = {}
var _speed_levels: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0]
var _speed_index: int = 2

var _placement_mode: bool = false
var _selected_building: String = ""
var _current_category: String = "economic"
var _hovered_tile_x: int = -1
var _hovered_tile_y: int = -1
var _scene_cache: Node
var _current_game_tick: int = 0
var _showing_underground: bool = false
var _log_filter: String = ""
var _refreshing_pantheon: bool = false

const UI_PARCHMENT_PATH := "res://assets/ui/ui_parchment.jpg"
const UI_WOOD_PANEL_PATH := "res://assets/ui/ui_wood_panel.jpg"
const FULLSCREEN_PANEL_KEYS := [
	"policy_panel",
	"skill_tree_panel",
	"influence_panel",
	"prophet_panel",
	"diplomacy_panel",
	"deity_panel",
	"culture_panel",
	"pantheon_panel",
	"history_panel",
	"government_panel",
	"tech_panel",
	"log_panel",
	"faction_panel",
]

func _ready() -> void:
	_scene_cache = get_tree().current_scene
	_build_ui()
	_connect_signals()
	_connect_chronicle_signals()
	
	if GameManager.current_state == GameManager.GameState.CLASS_SELECT:
		_hide_player_controls()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_ESCAPE:
			for key in FULLSCREEN_PANEL_KEYS:
				var p = _panels.get(key)
				if p is PanelContainer and p.visible:
					p.hide()
					return
			var class_select = _panels.get("class_select")
			if class_select and class_select.visible:
				class_select.hide()
				var main_menu = _panels.get("main_menu")
				if main_menu:
					main_menu.show()
				return
		KEY_PLUS, KEY_EQUAL:
			_change_speed(1)
		KEY_MINUS:
			_change_speed(-1)

func _build_ui() -> void:
	# --- Class selection overlay (shown at game start) ---
	_create_class_selection_screen()

	# --- Top bar ---
	var top_bar = PanelContainer.new()
	top_bar.name = "TopStatusBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0, 52)
	top_bar.add_theme_stylebox_override("panel", _make_textured_panel_style(UI_WOOD_PANEL_PATH, Color(0.11, 0.07, 0.045, 0.97), 16, 6))

	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 10)
	top_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Top bar Resources
	var res_text = RichTextLabel.new()
	res_text.name = "ResourceText"
	res_text.bbcode_enabled = true
	res_text.fit_content = true
	res_text.scroll_active = false
	res_text.custom_minimum_size = Vector2(560, 28)
	res_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_hbox.add_child(res_text)
	_panels["resources"] = res_text
	
	top_hbox.add_child(_make_spacer())

	var date_label = Label.new()
	date_label.name = "DateLabel"
	date_label.text = "Year 1, Spring - Day 1"
	date_label.custom_minimum_size = Vector2(200, 0)
	date_label.add_theme_color_override("font_color", Color("#f1d891"))
	top_hbox.add_child(date_label)
	_panels["date"] = date_label

	top_hbox.add_child(_make_spacer())

	var pause_btn = Button.new()
	pause_btn.text = "Pause"
	pause_btn.custom_minimum_size = Vector2(86, 34)
	pause_btn.pressed.connect(_on_pause_pressed)
	top_hbox.add_child(pause_btn)
	_panels["pause"] = pause_btn

	var speed_down = Button.new()
	speed_down.text = "<"
	speed_down.custom_minimum_size = Vector2(36, 34)
	speed_down.pressed.connect(func(): _change_speed(-1))
	top_hbox.add_child(speed_down)

	var speed_label = Label.new()
	speed_label.name = "SpeedLabel"
	speed_label.text = "Speed: 1.0x"
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label.custom_minimum_size = Vector2(90, 0)
	speed_label.add_theme_color_override("font_color", Color("#d8b458"))
	top_hbox.add_child(speed_label)
	_panels["speed"] = speed_label

	var speed_up = Button.new()
	speed_up.text = ">"
	speed_up.custom_minimum_size = Vector2(36, 34)
	speed_up.pressed.connect(func(): _change_speed(1))
	top_hbox.add_child(speed_up)

	var top_margin = _make_margin_container(12, 7, 12, 7)
	top_margin.add_child(top_hbox)
	top_bar.add_child(top_margin)
	add_child(top_bar)
	_panels["top_bar"] = top_bar

	# --- Outliner (Right Panel) ---
	var side_panel = PanelContainer.new()
	side_panel.name = "OutlinerPanel"
	side_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	side_panel.set_anchor(SIDE_LEFT, 0.78)
	side_panel.set_offset(SIDE_TOP, 58)
	side_panel.set_offset(SIDE_RIGHT, -8)
	side_panel.set_offset(SIDE_BOTTOM, -190) # Leave room for minimap
	side_panel.add_theme_stylebox_override("panel", _make_textured_panel_style(UI_WOOD_PANEL_PATH, Color(0.1, 0.065, 0.045, 0.96), 16, 8))

	var side_scroll = ScrollContainer.new()
	side_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var side_vbox = VBoxContainer.new()
	side_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_vbox.add_theme_constant_override("separation", 8)
	side_scroll.add_child(side_vbox)

	var stats_label = _make_section_header("Nation")
	side_vbox.add_child(stats_label)

	var leader_hbox = HBoxContainer.new()
	leader_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var leader_portrait = TextureRect.new()
	leader_portrait.name = "LeaderPortrait"
	leader_portrait.custom_minimum_size = Vector2(42, 42)
	leader_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	leader_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	leader_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	leader_hbox.add_child(leader_portrait)

	leader_hbox.add_child(_make_spacer())

	var leader_name_label = Label.new()
	leader_name_label.name = "LeaderName"
	leader_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leader_name_label.add_theme_color_override("font_color", Color("#f1d891"))
	leader_hbox.add_child(leader_name_label)

	leader_hbox.add_child(_make_spacer())

	side_vbox.add_child(leader_hbox)
	_panels["leader_portrait"] = leader_portrait
	_panels["leader_name"] = leader_name_label

	var stats_text = RichTextLabel.new()
	stats_text.name = "StatsText"
	stats_text.bbcode_enabled = true
	stats_text.fit_content = true
	side_vbox.add_child(stats_text)
	_panels["stats"] = stats_text

	side_vbox.add_child(_make_separator())

	var artifacts_label = _make_section_header("Artifacts")
	side_vbox.add_child(artifacts_label)

	var artifacts_text = RichTextLabel.new()
	artifacts_text.name = "ArtifactsText"
	artifacts_text.bbcode_enabled = true
	artifacts_text.fit_content = true
	artifacts_text.custom_minimum_size = Vector2(0, 60)
	side_vbox.add_child(artifacts_text)
	_panels["artifacts"] = artifacts_text

	side_vbox.add_child(_make_separator())

	var deity_label = _make_section_header("Deity")
	side_vbox.add_child(deity_label)

	var deity_text = RichTextLabel.new()
	deity_text.name = "DeityText"
	deity_text.bbcode_enabled = true
	deity_text.fit_content = true
	side_vbox.add_child(deity_text)
	_panels["deity"] = deity_text

	side_vbox.add_child(_make_separator())

	var tile_info_label = _make_section_header("Tile Info")
	side_vbox.add_child(tile_info_label)

	var tile_info_text = RichTextLabel.new()
	tile_info_text.name = "TileInfoText"
	tile_info_text.bbcode_enabled = true
	tile_info_text.fit_content = true
	tile_info_text.custom_minimum_size = Vector2(0, 100)
	side_vbox.add_child(tile_info_text)
	_panels["tile_info"] = tile_info_text

	var side_margin = _make_margin_container(10, 10, 10, 10)
	side_margin.add_child(side_scroll)
	side_panel.add_child(side_margin)
	add_child(side_panel)
	_panels["side_panel"] = side_panel

	# --- Building selection panel (left) ---
	var build_panel = PanelContainer.new()
	build_panel.name = "BuildSelectPanel"
	build_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	build_panel.set_anchor(SIDE_RIGHT, 0.28)
	build_panel.set_offset(SIDE_LEFT, 8)
	build_panel.set_offset(SIDE_TOP, 58)
	build_panel.set_offset(SIDE_BOTTOM, -66)
	build_panel.add_theme_stylebox_override("panel", _make_textured_panel_style(UI_WOOD_PANEL_PATH, Color(0.1, 0.065, 0.045, 0.97), 16, 8))
	build_panel.hide()

	var build_vbox = VBoxContainer.new()
	build_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_vbox.add_theme_constant_override("separation", 8)

	build_vbox.add_child(_make_section_header("Construction"))

	# Category tabs
	var tab_hbox = HBoxContainer.new()
	var categories = ["economic", "military", "religious", "infrastructure"]
	var cat_names = {"economic": "Economic", "military": "Military", "religious": "Religious", "infrastructure": "Infrastructure"}
	for cat in categories:
		var tab_btn = Button.new()
		tab_btn.text = cat_names[cat]
		tab_btn.toggle_mode = true
		tab_btn.button_pressed = (cat == _current_category)
		tab_btn.custom_minimum_size = Vector2(0, 24)
		tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var c = cat
		tab_btn.pressed.connect(func():
			_current_category = c
			for other in categories:
				var btn: Button = _panels.get("tab_" + other)
				if btn: btn.button_pressed = (other == c)
			_refresh_building_selection()
		)
		tab_hbox.add_child(tab_btn)
		_panels["tab_" + cat] = tab_btn
	build_vbox.add_child(tab_hbox)
	build_vbox.add_child(_make_separator())

	# Scrollable building list
	var build_scroll = ScrollContainer.new()
	build_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var build_list = VBoxContainer.new()
	build_list.name = "BuildList"
	build_scroll.add_child(build_list)
	build_vbox.add_child(build_scroll)

	var build_margin = _make_margin_container(10, 10, 10, 10)
	build_margin.add_child(build_vbox)
	build_panel.add_child(build_margin)
	add_child(build_panel)
	_panels["build_panel"] = build_panel
	_panels["build_scroll"] = build_scroll
	_panels["build_list"] = build_list

	# --- Bottom tab bar ---
	var bottom_bar = PanelContainer.new()
	bottom_bar.name = "BottomActionBar"
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.set_offset(SIDE_LEFT, 8)
	bottom_bar.set_offset(SIDE_TOP, -58)
	bottom_bar.set_offset(SIDE_RIGHT, -8)
	bottom_bar.set_offset(SIDE_BOTTOM, -8)
	bottom_bar.custom_minimum_size = Vector2(0, 50)
	bottom_bar.add_theme_stylebox_override("panel", _make_textured_panel_style(UI_WOOD_PANEL_PATH, Color(0.1, 0.065, 0.045, 0.97), 16, 6))

	var bottom_margin = _make_margin_container(8, 6, 8, 6)
	var bottom_scroll = ScrollContainer.new()
	bottom_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	bottom_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 6)
	bottom_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var build_btn = Button.new()
	build_btn.text = "Build"
	build_btn.add_theme_font_size_override("font_size", 14)
	build_btn.custom_minimum_size = Vector2(104, 36)
	build_btn.pressed.connect(_toggle_placement_mode)
	build_btn.mouse_entered.connect(func():
		build_btn.add_theme_color_override("font_color", Color("#ffd700"))
	)
	build_btn.mouse_exited.connect(func():
		build_btn.remove_theme_color_override("font_color")
	)
	bottom_hbox.add_child(build_btn)
	_panels["build_btn"] = build_btn

	var tabs = [
		{"name": "Policies", "action": _open_policy_panel},
		{"name": "Skill Tree", "action": _open_skill_tree_panel},
		{"name": "Influence", "action": _open_influence_panel},
		{"name": "Pantheon", "action": _open_pantheon_panel},
		{"name": "Prophets", "action": _open_prophet_panel},
		{"name": "Culture", "action": _open_culture_panel},
		{"name": "History", "action": _open_history_panel},
		{"name": "Diplomacy", "action": _open_diplomacy_panel},
		{"name": "Miracles", "action": _open_deity_miracles_panel},
		{"name": "Factions", "action": _open_factions_panel},
		{"name": "Government", "action": _open_government_panel},
		{"name": "Technologies", "action": _open_tech_tree_panel},
		{"name": "Log", "action": _open_log_panel},
	]
	for tab in tabs:
		var btn = Button.new()
		btn.text = tab["name"]
		btn.add_theme_font_size_override("font_size", 12)
		btn.custom_minimum_size = Vector2(104, 36)
		btn.pressed.connect(tab["action"])
		btn.mouse_entered.connect(func():
			btn.add_theme_color_override("font_color", Color("#ffd700"))
		)
		btn.mouse_exited.connect(func():
			btn.remove_theme_color_override("font_color")
		)
		bottom_hbox.add_child(btn)

	bottom_scroll.add_child(bottom_hbox)
	bottom_margin.add_child(bottom_scroll)
	bottom_bar.add_child(bottom_margin)
	add_child(bottom_bar)
	_panels["bottom_bar"] = bottom_bar

	# --- Event Dialog ---
	var event_dlg = PanelContainer.new()
	event_dlg.name = "EventDialog"
	event_dlg.set_anchors_preset(Control.PRESET_CENTER)
	event_dlg.custom_minimum_size = Vector2(400, 250)
	event_dlg.add_theme_stylebox_override("panel", _make_textured_panel_style(UI_WOOD_PANEL_PATH, Color(0.1, 0.065, 0.045, 0.98), 16, 12))
	event_dlg.hide()

	var event_vbox = VBoxContainer.new()
	event_vbox.add_theme_constant_override("separation", 10)
	var event_title = Label.new()
	event_title.name = "EventTitle"
	event_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_title.add_theme_font_size_override("font_size", 18)
	event_vbox.add_child(event_title)
	_panels["event_title"] = event_title

	var event_desc = Label.new()
	event_desc.name = "EventDesc"
	event_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	event_vbox.add_child(event_desc)
	_panels["event_desc"] = event_desc

	var event_options = VBoxContainer.new()
	event_options.name = "EventOptions"
	event_vbox.add_child(event_options)
	_panels["event_options"] = event_options

	var event_margin = _make_margin_container(14, 14, 14, 14)
	event_margin.add_child(event_vbox)
	event_dlg.add_child(event_margin)
	add_child(event_dlg)
	_panels["event_dialog"] = event_dlg

	# --- Modal overlay panels ---
	_panels["policy_panel"] = _create_fullscreen_panel("Policies")
	_panels["skill_tree_panel"] = _create_fullscreen_panel("Skill Tree")
	_panels["influence_panel"] = _create_fullscreen_panel("Divine Influence")
	_panels["prophet_panel"] = _create_fullscreen_panel("Prophets")
	_panels["diplomacy_panel"] = _create_fullscreen_panel("Diplomacy")
	_panels["deity_panel"] = _create_fullscreen_panel("Divine Miracles")
	_panels["culture_panel"] = _create_fullscreen_panel("Cultural Traits")
	_panels["pantheon_panel"] = _create_fullscreen_panel("Divine Aspects")
	_panels["history_panel"] = _create_fullscreen_panel("World History")
	_panels["government_panel"] = _create_fullscreen_panel("Government")
	_panels["tech_panel"] = _create_fullscreen_panel("Technologies")
	_panels["log_panel"] = _create_fullscreen_panel("Event Log")
	_panels["faction_panel"] = _create_fullscreen_panel("Factions")

	# --- Toast notifications (top-right) ---
	var toast_container = VBoxContainer.new()
	toast_container.name = "ToastContainer"
	toast_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toast_container.set_offset(SIDE_TOP, 42)
	toast_container.set_offset(SIDE_RIGHT, -10)
	toast_container.set_offset(SIDE_LEFT, -300)
	toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_container)
	_panels["toast_container"] = toast_container
	
	_create_main_menu_screen()

	# --- Tutorial overlay (created hidden, shown on first launch after world gen) ---
	_create_tutorial_overlay()

	_apply_dark_theme()
	
	_panels["main_menu"].hide()
	_panels["class_select"].show()

func _create_class_selection_screen() -> void:
	var overlay = PanelContainer.new()
	overlay.name = "ClassSelectScreen"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Add a dark semi-transparent background
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.05, 0.08, 1.0)
	overlay.add_theme_stylebox_override("panel", bg_style)
	overlay.hide()
	_panels["class_select"] = overlay

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var window = PanelContainer.new()
	window.custom_minimum_size = Vector2(700, 500)
	var parch_tex = _load_ui_texture(UI_PARCHMENT_PATH)
	if parch_tex:
		var parch_style = StyleBoxTexture.new()
		parch_style.texture = parch_tex
		parch_style.texture_margin_left = 24
		parch_style.texture_margin_right = 24
		parch_style.texture_margin_top = 24
		parch_style.texture_margin_bottom = 24
		window.add_theme_stylebox_override("panel", parch_style)
	center.add_child(window)

	var vbox = VBoxContainer.new()
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_child(vbox)
	window.add_child(margin)

	var title = Label.new()
	title.text = "Choose Your Divine Form"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "HeaderLarge"
	title.add_theme_color_override("font_color", Color(0.1, 0.05, 0.0))
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "As a deity, your domain shapes how you interact with the mortal world."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	subtitle.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05))
	vbox.add_child(subtitle)

	vbox.add_child(_make_separator())

	# --- Difficulty selector ---
	var diff_hbox = HBoxContainer.new()
	diff_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var diff_label = Label.new()
	diff_label.text = "Difficulty: "
	diff_label.add_theme_font_size_override("font_size", 14)
	diff_label.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05))
	diff_hbox.add_child(diff_label)
	var diff_options = OptionButton.new()
	diff_options.name = "DifficultySelect"
	diff_options.add_item("Easy", 0)
	diff_options.add_item("Normal", 1)
	diff_options.add_item("Hard", 2)
	diff_options.select(1)  # Normal default
	diff_options.item_selected.connect(func(index: int):
		match index:
			0: ColonyData.difficulty = "easy"
			1: ColonyData.difficulty = "normal"
			2: ColonyData.difficulty = "hard"
	)
	diff_hbox.add_child(diff_options)
	vbox.add_child(diff_hbox)

	vbox.add_child(_make_separator())

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)

	var dm = _get_deity_manager()
	if not dm:
		print("[GameUI] _create_class_selection_screen: dm is null! returning early!")
		return
	var first_choose_btn: Button = null
	for class_id in dm.DEITY_CLASSES:
		var data = dm.DEITY_CLASSES[class_id]
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(300, 180)

		var card_vbox = VBoxContainer.new()
		# --- Deity symbol centered above name ---
		var symbol_path = "res://assets/symbols/%s.png" % class_id
		if ResourceLoader.exists(symbol_path):
			var sym_tex = load(symbol_path) as Texture2D
			if sym_tex:
				var sym_center = HBoxContainer.new()
				sym_center.alignment = BoxContainer.ALIGNMENT_CENTER
				var sym_rect = TextureRect.new()
				sym_rect.texture = sym_tex
				sym_rect.custom_minimum_size = Vector2(32, 32)
				sym_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				sym_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				sym_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sym_center.add_child(sym_rect)
				card_vbox.add_child(sym_center)
		var card_title = Label.new()
		card_title.text = data["name"]
		card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_title.add_theme_font_size_override("font_size", 16)
		card_vbox.add_child(card_title)

		var card_desc = Label.new()
		card_desc.text = data["description"]
		card_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		card_vbox.add_child(card_desc)

		var synergy = Label.new()
		synergy.text = "Synergy: %s" % ", ".join(data["synergy_races"])
		synergy.add_theme_color_override("font_color", Color.YELLOW)
		card_vbox.add_child(synergy)

		var passive = Label.new()
		var passive_str = ""
		for k in data["passive_bonus"]:
			passive_str += "%s +%.0f%% " % [k.capitalize(), (data["passive_bonus"][k] - 1.0) * 100]
		passive.text = "Passive: " + passive_str
		passive.add_theme_color_override("font_color", Color.CYAN)
		card_vbox.add_child(passive)

		var choose_btn = Button.new()
		choose_btn.text = "Choose %s" % data["name"]
		if first_choose_btn == null:
			first_choose_btn = choose_btn
		var cid = class_id
		choose_btn.pressed.connect(func():
			var dmgr = _get_deity_manager()
			if dmgr: dmgr.select_class(cid)
			overlay.hide()
			GameManager.class_selection_complete()
		)
		card_vbox.add_child(choose_btn)

		card.add_child(card_vbox)
		grid.add_child(card)

	scroll.add_child(grid)
	vbox.add_child(scroll)
	add_child(overlay)
	if first_choose_btn:
		first_choose_btn.grab_focus()

func _create_main_menu_screen() -> void:
	var overlay = Control.new()
	overlay.name = "MainMenuScreen"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = _load_ui_texture(UI_PARCHMENT_PATH)
	overlay.add_child(bg)

	var shade = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.012, 0.018, 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)

	var layout_margin = _make_margin_container(72, 48, 72, 42)
	layout_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layout = HBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 24)

	var menu_center = CenterContainer.new()
	menu_center.custom_minimum_size = Vector2(500, 0)
	menu_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(menu_center)

	var menu_panel = PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(460, 560)
	menu_panel.add_theme_stylebox_override("panel", _make_textured_panel_style(UI_WOOD_PANEL_PATH, Color(0.1, 0.06, 0.04, 0.98), 18, 12))

	var panel_margin = _make_margin_container(28, 28, 28, 24)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title = Label.new()
	title.text = "THRONEHOLD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_constant_override("outline_size", 6)
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "A game of divine dominion"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("#d8b458"))
	vbox.add_child(subtitle)

	vbox.add_child(_make_separator())

	var new_game_btn = Button.new()
	new_game_btn.text = "NEW GAME"
	new_game_btn.custom_minimum_size = Vector2(320, 56)
	new_game_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	new_game_btn.add_theme_font_size_override("font_size", 22)
	new_game_btn.add_theme_color_override("font_color", Color("#1a1a2e"))
	new_game_btn.add_theme_color_override("font_hover_color", Color("#1a1a2e"))
	var gold_style = StyleBoxFlat.new()
	gold_style.bg_color = Color(0.85, 0.7, 0.2, 0.9)
	gold_style.corner_radius_top_left = 4
	gold_style.corner_radius_top_right = 4
	gold_style.corner_radius_bottom_left = 4
	gold_style.corner_radius_bottom_right = 4
	gold_style.border_color = Color(1.0, 0.9, 0.5, 1.0)
	gold_style.border_width_left = 1; gold_style.border_width_right = 1
	gold_style.border_width_top = 1; gold_style.border_width_bottom = 2
	gold_style.shadow_color = Color(0.85, 0.7, 0.2, 0.4)
	gold_style.shadow_size = 8
	var gold_hover = gold_style.duplicate()
	gold_hover.bg_color = Color(1.0, 0.85, 0.3, 1.0)
	gold_hover.shadow_size = 12
	var gold_pressed = gold_style.duplicate()
	gold_pressed.bg_color = Color(0.65, 0.5, 0.1, 0.9)
	gold_pressed.border_width_bottom = 1
	gold_pressed.shadow_size = 2
	new_game_btn.add_theme_stylebox_override("normal", gold_style)
	new_game_btn.add_theme_stylebox_override("hover", gold_hover)
	new_game_btn.add_theme_stylebox_override("pressed", gold_pressed)
	new_game_btn.pressed.connect(func():
		overlay.hide()
		var class_select: PanelContainer = _panels.get("class_select")
		if class_select:
			class_select.show()
		GameManager._on_new_game_pressed()
	)
	vbox.add_child(new_game_btn)

	# Load Game
	var load_btn = Button.new()
	load_btn.text = "Load Game"
	load_btn.custom_minimum_size = Vector2(300, 44)
	load_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	load_btn.add_theme_font_size_override("font_size", 18)
	load_btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	load_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.5))
	load_btn.pressed.connect(func():
		var systems = _find_systems_node()
		var sm: Node = null
		if systems:
			sm = systems.get_node_or_null("SaveManager")
		if sm and sm.load_game():
			overlay.hide()
			GameManager.change_state(GameManager.GameState.PLAYING)
			var tm = _get_time_manager()
			if tm: tm.start()
		else:
			print("[MainMenu] Load failed â€” no save file or version mismatch")
	)
	vbox.add_child(load_btn)

	# Quit
	var quit_btn = Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(300, 44)
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit_btn.add_theme_font_size_override("font_size", 18)
	quit_btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	quit_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.4))
	quit_btn.pressed.connect(func():
		get_tree().quit()
	)
	vbox.add_child(quit_btn)

	# Subtle footer
	var footer = Control.new()
	footer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(footer)

	var version = Label.new()
	version.text = "v0.2.0"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color("#8e836d"))
	vbox.add_child(version)

	panel_margin.add_child(vbox)
	menu_panel.add_child(panel_margin)
	menu_center.add_child(menu_panel)
	layout.add_child(_make_spacer())
	layout_margin.add_child(layout)
	overlay.add_child(layout_margin)
	add_child(overlay)
	_panels["main_menu"] = overlay
	new_game_btn.grab_focus()


func _create_tutorial_overlay() -> void:
	var tutorial = preload("res://scripts/ui/TutorialOverlay.gd").new()
	tutorial.name = "TutorialOverlay"
	tutorial.hide()
	tutorial.set_on_complete(func():
		print("[Tutorial] Completed â€” marked as seen")
	)
	add_child(tutorial)
	_panels["tutorial"] = tutorial


func _on_class_selected_tutorial(_class_id: String) -> void:
	if ColonyData.has_seen_tutorial:
		return
	var tutorial: CanvasLayer = _panels.get("tutorial")
	if tutorial:
		tutorial.show()
		tutorial.set_process_mode(Node.PROCESS_MODE_ALWAYS)


func _connect_signals() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.resources_updated.connect(_on_resources_updated)
	EventBus.population_changed.connect(_on_population_changed)
	EventBus.divine_power_changed.connect(_on_divine_power_changed)
	EventBus.power_unlocked.connect(_on_power_unlocked)
	EventBus.event_triggered.connect(_on_event_triggered)
	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.world_generated.connect(_on_world_generated)
	EventBus.policy_enacted.connect(func(_n: int, _p: String): _refresh_all())
	EventBus.policy_revoked.connect(func(_n: int, _p: String): _refresh_all())
	EventBus.deity_class_selected.connect(func(_c: String): _refresh_all())
	EventBus.leader_changed.connect(func(_n: int, _o: int, _new: int): _refresh_all())
	EventBus.belief_changed.connect(func(_n: int, _r: String, _v: float): _refresh_all())
	EventBus.tile_hovered.connect(_on_tile_hovered)
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.tile_clicked.connect(_on_placement_tile_clicked)
	EventBus.building_placement_mode_changed.connect(_on_placement_mode_changed)
	EventBus.faction_defeated.connect(func(_n: int, _f: String): _refresh_factions_if_visible())
	EventBus.faction_integrated.connect(func(_n: int, _f: String): _refresh_factions_if_visible())
	EventBus.underground_toggled.connect(_on_underground_toggled)
	EventBus.deity_class_selected.connect(_on_class_selected_tutorial)

	# --- Season change toast ---
	EventBus.season_changed.connect(_on_season_changed)

	# --- Toast signal wiring ---
	EventBus.nation_created.connect(func(nid: int, data: Dictionary): _show_toast("ðŸ›ï¸ Nation founded: %s" % data.get("name", "Unknown")))
	EventBus.history_events_generated.connect(func(): _show_toast("ðŸ“œ History recorded â€” ages of legend written"))
	EventBus.leader_generated.connect(func(cid: int, char_data: Dictionary): _show_toast("ðŸ‘‘ Leader risen: %s the %s" % [char_data.get("name", "?"), char_data.get("archetype", "?")]))
	EventBus.prophet_created.connect(func(cid: int, char_data: Dictionary): _show_toast("ðŸ™ Prophet chosen: %s" % char_data.get("name", "?")))
	EventBus.prophet_sent.connect(func(nid: int, cid: int): _show_toast("ðŸ“¨ Prophet dispatched to %s" % _nation_name(nid)))
	EventBus.prophet_recalled.connect(func(nid: int): _show_toast("ðŸ”™ Prophet recalled from %s" % _nation_name(nid)))
	EventBus.prophet_died.connect(func(nid: int, cid: int, cause: String): _show_toast("ðŸ’€ Prophet perished in %s â€” %s" % [_nation_name(nid), cause]))
	EventBus.prophet_conversion.connect(func(nid: int, cid: int, total: int): _show_toast("âœ¨ Prophet converted %d souls in %s" % [total, _nation_name(nid)]))
	EventBus.aspect_unlocked.connect(func(aid: String): _show_toast("ðŸ”“ Divine aspect unlocked: %s" % _aspect_name(aid)))
	EventBus.aspect_power_allocated.connect(func(aid: String, pct: float): _show_toast("âš¡ Power shifted to %s: %d%%" % [_aspect_name(aid), int(pct * 100)]))
	EventBus.miracle_cast.connect(func(mid: String, _target: Variant): _show_toast("ðŸŒŸ Miracle invoked: %s" % _miracle_name(mid)))
	EventBus.skill_unlocked.connect(func(sid: String): _show_toast("ðŸ“– Divine skill mastered: %s" % sid.capitalize()))
	EventBus.event_resolved.connect(func(nid: int, eid: String, outcome: String): _show_toast("ðŸ“‹ Event concluded â€” %s" % outcome.capitalize()))
	EventBus.influence_attempted.connect(func(nid: int, aid: String, success: bool, _str: float): _show_toast("%s Influence on %s" % ["âœ…" if success else "âŒ", _nation_name(nid)]))
	EventBus.battle_fought.connect(func(aid: int, did: int, _res: Dictionary): _show_toast("âš”ï¸ Battle: %s vs %s" % [_nation_name(aid), _nation_name(did)]))
	EventBus.trade_league_formed.connect(func(league: Dictionary): _show_toast("ðŸ¤ Trade league formed: %s" % league.get("name", "Unknown")))
	EventBus.independence_declared.connect(func(vid: int): _show_toast("ðŸ´ %s declares independence!" % _nation_name(vid)))
	EventBus.vassalage_established.connect(func(sid: int, vid: int): _show_toast("â›“ï¸ %s now vassal of %s" % [_nation_name(vid), _nation_name(sid)]))
	EventBus.culture_spread.connect(func(fid, tid, _t): _show_toast("ðŸŽ­ %s culture spreads to %s" % [_nation_name(fid), _nation_name(tid)]))
	EventBus.building_destroyed.connect(func(_tx: int, _ty: int, bid: String): _show_toast("ðŸ’¥ Building destroyed: %s" % _building_name(bid)))
	EventBus.colonist_died.connect(func(nid: int, cause: String): _show_toast("ðŸ’” Colonist lost in %s â€” %s" % [_nation_name(nid), cause]))
	EventBus.colonist_arrived.connect(func(nid: int, count: int): _show_toast("ðŸš¶ %d colonists arrive in %s" % [count, _nation_name(nid)]))
	EventBus.faction_defeated.connect(func(nid: int, ftype: String): _show_toast("ðŸ Faction crushed: %s in %s" % [ftype.capitalize(), _nation_name(nid)]))
	EventBus.faction_integrated.connect(func(nid: int, ftype: String): _show_toast("ðŸ”„ Faction integrated: %s into %s" % [ftype.capitalize(), _nation_name(nid)]))
	EventBus.tech_unlocked.connect(func(nid: int, tech: String):
		_show_toast("ðŸ”¬ %s unlocked %s" % [_nation_name(nid), tech.capitalize()])
		_refresh_tech_if_visible()
	)
	EventBus.era_advanced.connect(func(nid: int, era: String):
		_show_toast("ðŸ—“ï¸ %s enters the %s era" % [_nation_name(nid), era.capitalize()])
		_refresh_tech_if_visible()
	)
	EventBus.subrace_emerged.connect(func(nid: int, _old: String, new_race: String): _show_toast("ðŸ§¬ New subrace emerges among %s: %s" % [_nation_name(nid), new_race.capitalize()]))
	EventBus.victory_achieved.connect(func(vtype: String, desc: String): _display_victory_overlay(vtype, desc))
	EventBus.defeat_triggered.connect(func(reason: String, desc: String): _display_defeat_overlay(reason, desc))

# =============================================================================
# CHRONICLE SIGNALS â€” Narrative prose entries for the Event Log
# =============================================================================

func _connect_chronicle_signals() -> void:
	# --- Diplomacy & War ---
	EventBus.war_declared.connect(func(attacker_id: int, defender_id: int):
		var a_nat = ColonyData.get_nation(attacker_id)
		var d_nat = ColonyData.get_nation(defender_id)
		var a_race = ColonyData.RACES.get(a_nat.get("primary_race", ""), {}).get("name", "warriors")
		var d_race = ColonyData.RACES.get(d_nat.get("primary_race", ""), {}).get("name", "defenders")
		var reasons = ["over disputed borderlands", "in a bid for regional dominance", "over ancient grievances", "to secure vital resources", "after a diplomatic insult", "to preempt an imminent threat", "over control of sacred sites", "for the glory of conquest"]
		ColonyData.add_chronicle_entry("Year %d: The %s of %s declared war on the %s of %s %s." % [ColonyData.current_year, a_race, a_nat.get("name", "Unknown"), d_race, d_nat.get("name", "Unknown"), reasons.pick_random()], "war")
	)

	EventBus.peace_signed.connect(func(nation_a: int, nation_b: int):
		var a_nat = ColonyData.get_nation(nation_a)
		var b_nat = ColonyData.get_nation(nation_b)
		var tones = ["A fragile peace was signed between %s and %s, though old wounds may yet fester.", "The war between %s and %s ended with a treaty of mutual accord.", "Hostilities ceased as %s and %s laid down their arms and embraced diplomacy.", "An armistice was brokered between %s and %s, bringing relief to war-weary peoples."]
		ColonyData.add_chronicle_entry("Year %d: %s" % [ColonyData.current_year, tones.pick_random() % [a_nat.get("name", "?"), b_nat.get("name", "?")]], "diplomacy")
	)

	EventBus.alliance_formed.connect(func(nation_a: int, nation_b: int):
		var a_nat = ColonyData.get_nation(nation_a)
		var b_nat = ColonyData.get_nation(nation_b)
		ColonyData.add_chronicle_entry("Year %d: %s and %s forged a military alliance, swearing to stand together against all foes." % [ColonyData.current_year, a_nat.get("name", "?"), b_nat.get("name", "?")], "diplomacy")
	)

	EventBus.trade_route_established.connect(func(from_id: int, to_id: int, resource: String):
		var f_nat = ColonyData.get_nation(from_id)
		var t_nat = ColonyData.get_nation(to_id)
		ColonyData.add_chronicle_entry("Year %d: A trade route opened between %s and %s, carrying %s across the land." % [ColonyData.current_year, f_nat.get("name", "?"), t_nat.get("name", "?"), resource], "diplomacy")
	)

	EventBus.vassalage_established.connect(func(suzerain_id: int, vassal_id: int):
		var s_nat = ColonyData.get_nation(suzerain_id)
		var v_nat = ColonyData.get_nation(vassal_id)
		ColonyData.add_chronicle_entry("Year %d: %s bent the knee to %s, swearing fealty as a vassal state." % [ColonyData.current_year, v_nat.get("name", "?"), s_nat.get("name", "?")], "diplomacy")
	)

	EventBus.independence_declared.connect(func(vassal_id: int):
		var v_nat = ColonyData.get_nation(vassal_id)
		ColonyData.add_chronicle_entry("Year %d: %s declared independence from its overlord! The banners of freedom fly high." % [ColonyData.current_year, v_nat.get("name", "?")], "diplomacy")
	)

	EventBus.trade_league_formed.connect(func(league: Dictionary):
		var member_names: Array[String] = []
		for mid in league.get("members", []):
			var mn = ColonyData.get_nation(mid)
			member_names.append(mn.get("name", "?"))
		var members_str = ", ".join(member_names)
		ColonyData.add_chronicle_entry("Year %d: The trade league '%s' was established, binding %s in a pact of commerce and prosperity." % [ColonyData.current_year, league.get("name", "Unknown"), members_str], "diplomacy")
	)

	EventBus.relation_changed.connect(func(nation_a: int, nation_b: int, new_value: float):
		if new_value < 15 and new_value >= 0:
			var a_nat = ColonyData.get_nation(nation_a)
			var b_nat = ColonyData.get_nation(nation_b)
			ColonyData.add_chronicle_entry("Year %d: Relations between %s and %s have soured to outright hostility." % [ColonyData.current_year, a_nat.get("name", "?"), b_nat.get("name", "?")], "diplomacy")
		elif new_value > 85:
			var a_nat = ColonyData.get_nation(nation_a)
			var b_nat = ColonyData.get_nation(nation_b)
			ColonyData.add_chronicle_entry("Year %d: %s and %s now regard each other as trusted friends, their bond unshakable." % [ColonyData.current_year, a_nat.get("name", "?"), b_nat.get("name", "?")], "diplomacy")
	)

	# --- Characters ---
	EventBus.leader_generated.connect(func(character_id: int, character: Dictionary):
		var nat = ColonyData.get_nation(character.get("nation_id", -1))
		var race_name = ColonyData.RACES.get(character.get("race", ""), {}).get("name", character.get("race", "unknown"))
		ColonyData.add_chronicle_entry("Year %d: %s the %s, a %s %s, rose to lead %s with a vision of %s." % [ColonyData.current_year, character.get("name", "?"), character.get("archetype", "?"), race_name, character.get("gender", "?"), nat.get("name", "?"), ["glory", "prosperity", "unity", "conquest", "wisdom"].pick_random()], "event")
	)

	EventBus.leader_died.connect(func(character_id: int, cause: String):
		var char = ColonyData.get_character(character_id)
		var nat = ColonyData.get_nation(char.get("nation_id", -1))
		var causes = {"old_age": "passed away peacefully in their sleep", "assassination": "was struck down by an assassin's blade", "battle": "fell in the heat of battle", "plague": "succumbed to a devastating plague", "execution": "was executed by their enemies", "accident": "perished in a tragic accident"}
		var cause_text = causes.get(cause, cause)
		ColonyData.add_chronicle_entry("Year %d: %s, %s of %s, %s. The realm mourns the loss of its leader." % [ColonyData.current_year, char.get("name", "A great leader"), char.get("archetype", "ruler"), nat.get("name", "Unknown"), cause_text], "event")
	)

	EventBus.leader_changed.connect(func(nation_id: int, _old_id: int, _new_id: int):
		var nat = ColonyData.get_nation(nation_id)
		ColonyData.add_chronicle_entry("Year %d: The mantle of leadership passed to a new ruler in %s, marking the dawn of a new era." % [ColonyData.current_year, nat.get("name", "Unknown")], "event")
	)

	# --- Deity & Miracles ---
	EventBus.miracle_cast.connect(func(miracle_id: String, target: Variant):
		var miracle_name: String = _miracle_name(miracle_id)
		var target_str = ""
		if target is int and target >= 0:
			target_str = " upon " + _nation_name(target)
		var descriptions = ["A divine radiance swept across the land", "The heavens opened and the hand of the divine reached down", "A miracle of staggering power was invoked", "The faithful witnessed an undeniable sign from above", "The world itself seemed to bend to divine will"]
		ColonyData.add_chronicle_entry("Year %d: %s â€” the miracle of %s%s." % [ColonyData.current_year, descriptions.pick_random(), miracle_name, target_str], "deity")
	)

	EventBus.prophet_sent.connect(func(nation_id: int, character_id: int):
		var nat = ColonyData.get_nation(nation_id)
		var char = ColonyData.get_character(character_id)
		ColonyData.add_chronicle_entry("Year %d: A prophet was dispatched to %s, carrying divine word to the people." % [ColonyData.current_year, nat.get("name", "?")], "deity")
	)

	EventBus.prophet_died.connect(func(nation_id: int, character_id: int, cause: String):
		var nat = ColonyData.get_nation(nation_id)
		var char = ColonyData.get_character(character_id)
		ColonyData.add_chronicle_entry("Year %d: The prophet %s perished in %s â€” %s. The faithful weep." % [ColonyData.current_year, char.get("name", "sent to the people"), nat.get("name", "?"), cause], "deity")
	)

	EventBus.prophet_conversion.connect(func(nation_id: int, _character_id: int, total_conversions: int):
		var nat = ColonyData.get_nation(nation_id)
		ColonyData.add_chronicle_entry("Year %d: A prophet converted %d souls in %s, swelling the ranks of the faithful." % [ColonyData.current_year, total_conversions, nat.get("name", "?")], "deity")
	)

	EventBus.power_unlocked.connect(func(power_id: String):
		ColonyData.add_chronicle_entry("Year %d: A new divine power was unlocked â€” %s. The deity's influence grows." % [ColonyData.current_year, power_id.capitalize()], "deity")
	)

	EventBus.aspect_unlocked.connect(func(aspect_id: String):
		ColonyData.add_chronicle_entry("Year %d: The divine aspect of %s was awakened, reshaping the deity's domain." % [ColonyData.current_year, _aspect_name(aspect_id)], "deity")
	)

	# --- Nations & Colonies ---
	EventBus.nation_created.connect(func(nation_id: int, nation_data: Dictionary):
		var race_name = ColonyData.RACES.get(nation_data.get("primary_race", ""), {}).get("name", "a new people")
		var biome: String = ""
		var tile = ColonyData.get_tile(nation_data.get("capital_x", 0), nation_data.get("capital_y", 0))
		if not tile.is_empty():
			biome = " in the " + tile.get("terrain", "lands")
		ColonyData.add_chronicle_entry("Year %d: The %s nation of %s was founded%s, planting their banner upon the world." % [ColonyData.current_year, race_name, nation_data.get("name", "Unknown"), biome], "event")
	)

	EventBus.colony_founded.connect(func(nation_id: int, tile_x: int, tile_y: int):
		var nat = ColonyData.get_nation(nation_id)
		var tile = ColonyData.get_tile(tile_x, tile_y)
		var terrain = tile.get("terrain", "lands")
		ColonyData.add_chronicle_entry("Year %d: %s founded a new colony upon the %s at the edge of the known world." % [ColonyData.current_year, nat.get("name", "?"), terrain], "building")
	)

	EventBus.building_placed.connect(func(tile_x: int, tile_y: int, building_id: String, nation_id: int):
		var nat = ColonyData.get_nation(nation_id)
		var bname = _building_name(building_id)
		ColonyData.add_chronicle_entry("Year %d: %s erected a %s, a testament to their growing power." % [ColonyData.current_year, nat.get("name", "?"), bname], "building")
	)

	# --- War & Battles ---
	EventBus.battle_fought.connect(func(attacker_id: int, defender_id: int, result: Dictionary):
		var a_nat = ColonyData.get_nation(attacker_id)
		var d_nat = ColonyData.get_nation(defender_id)
		var outcome: String = result.get("outcome", "drew no clear victor")
		var a_losses: int = result.get("attacker_losses", 0)
		var d_losses: int = result.get("defender_losses", 0)
		ColonyData.add_chronicle_entry("Year %d: A great battle was fought between %s and %s â€” %s. Losses: %d attackers, %d defenders." % [ColonyData.current_year, a_nat.get("name", "?"), d_nat.get("name", "?"), outcome, a_losses, d_losses], "war")
	)

	EventBus.territory_captured.connect(func(capturer_id: int, tile_x: int, tile_y: int):
		var nat = ColonyData.get_nation(capturer_id)
		ColonyData.add_chronicle_entry("Year %d: %s seized territory at the battlefront, their borders expanding by the sword." % [ColonyData.current_year, nat.get("name", "?")], "war")
	)

	# --- Technology ---
	EventBus.tech_unlocked.connect(func(nation_id: int, tech_id: String):
		var nat = ColonyData.get_nation(nation_id)
		ColonyData.add_chronicle_entry("Year %d: %s unlocked the secrets of %s, advancing their civilization." % [ColonyData.current_year, nat.get("name", "?"), tech_id.capitalize()], "event")
	)

	EventBus.era_advanced.connect(func(nation_id: int, new_era: String):
		var nat = ColonyData.get_nation(nation_id)
		ColonyData.add_chronicle_entry("Year %d: %s has entered the %s era! A new age of discovery and power begins." % [ColonyData.current_year, nat.get("name", "?"), new_era.capitalize()], "event")
	)

	# --- Culture & Subraces ---
	EventBus.subrace_emerged.connect(func(nation_id: int, old_race: String, new_race: String):
		var nat = ColonyData.get_nation(nation_id)
		var old_race_name = ColonyData.RACES.get(old_race, {}).get("name", old_race)
		var variant_data = ColonyData.RACE_VARIANTS.get(new_race, {})
		var new_name = variant_data.get("name", new_race.capitalize())
		ColonyData.add_chronicle_entry("Year %d: A new subrace, the %s, emerged among the %s of %s, shaped by their harsh environment." % [ColonyData.current_year, new_name, old_race_name, nat.get("name", "?")], "event")
	)

	EventBus.cultural_trait_emerged.connect(func(nation_id: int, trait_id: String):
		var nat = ColonyData.get_nation(nation_id)
		var trait_data = ColonyData.CULTURAL_TRAITS.get(trait_id, {})
		var trait_name = trait_data.get("name", trait_id)
		ColonyData.add_chronicle_entry("Year %d: The people of %s embraced a new cultural tradition â€” %s." % [ColonyData.current_year, nat.get("name", "?"), trait_name], "event")
	)

	EventBus.cultural_trait_faded.connect(func(nation_id: int, trait_id: String):
		var nat = ColonyData.get_nation(nation_id)
		var trait_data = ColonyData.CULTURAL_TRAITS.get(trait_id, {})
		var trait_name = trait_data.get("name", trait_id)
		ColonyData.add_chronicle_entry("Year %d: The %s tradition faded from %s, remembered only in songs and tales." % [ColonyData.current_year, trait_name, nat.get("name", "?")], "event")
	)

	# --- Mass Belief ---
	EventBus.mass_conversion.connect(func(nation_id: int, race_id: String, amount: float):
		var nat = ColonyData.get_nation(nation_id)
		var race_name = ColonyData.RACES.get(race_id, {}).get("name", race_id)
		var souls = int(nat.get("population", 0) * amount)
		ColonyData.add_chronicle_entry("Year %d: A wave of faith swept through %s â€” %d %s souls turned to the divine." % [ColonyData.current_year, nat.get("name", "?"), souls, race_name], "deity")
	)

	# --- Victory ---
	EventBus.victory_achieved.connect(func(victory_type: String, description: String):
		ColonyData.add_chronicle_entry("Year %d: A GREAT VICTORY was achieved â€” %s. The chronicles shall remember this day." % [ColonyData.current_year, description], "event")
	)

	# --- Resources ---
	EventBus.resource_critical.connect(func(nation_id: int, resource_name: String, amount: float):
		var nat = ColonyData.get_nation(nation_id)
		ColonyData.add_chronicle_entry("Year %d: %s faces a critical shortage of %s â€” their stores dwindle to near nothing." % [ColonyData.current_year, nat.get("name", "?"), resource_name], "event")
	)

	# --- Factions ---
	EventBus.faction_defeated.connect(func(nation_id: int, faction_type: String):
		var nat = ColonyData.get_nation(nation_id)
		var faction_name = ColonyData.FACTIONS.get(faction_type, {}).get("name", faction_type)
		ColonyData.add_chronicle_entry("Year %d: %s crushed the %s, removing a threat from the land." % [ColonyData.current_year, nat.get("name", "?"), faction_name], "war")
	)

	EventBus.faction_integrated.connect(func(nation_id: int, faction_type: String):
		var nat = ColonyData.get_nation(nation_id)
		var faction_name = ColonyData.FACTIONS.get(faction_type, {}).get("name", faction_type)
		ColonyData.add_chronicle_entry("Year %d: The %s were peacefully integrated into %s, their skills enriching the nation." % [ColonyData.current_year, faction_name, nat.get("name", "?")], "event")
	)

func _on_tick_advanced(tick: int, day: int, season: String, year: int) -> void:
	_current_game_tick = tick
	var label: Label = _panels["date"]
	label.text = "Year %d, %s - Day %d" % [year, season, day]
	_refresh_all()

func _on_resources_updated(_nation_id: int, _resources: Dictionary) -> void:
	_refresh_resource_panel()
	_refresh_stats_panel()

func _on_population_changed(_nation_id: int, _count: int) -> void:
	_refresh_stats_panel()

func _on_divine_power_changed(_a: float, _m: float) -> void:
	_refresh_deity_panel()

func _on_power_unlocked(power_id: String) -> void:
	print("[UI] New power unlocked: %s" % power_id)

func _on_speed_changed(mult: float) -> void:
	var label: Label = _panels["speed"]
	label.text = "Speed: %.1fx" % mult

func _on_tile_hovered(tile_x: int, tile_y: int) -> void:
	_hovered_tile_x = tile_x
	_hovered_tile_y = tile_y
	var tile: Dictionary
	if _showing_underground:
		tile = ColonyData.get_underground_tile(tile_x, tile_y)
	else:
		tile = ColonyData.get_tile(tile_x, tile_y)
	if tile.is_empty():
		return
	_refresh_tile_info(tile, tile_x, tile_y)
	if _placement_mode:
		_refresh_building_selection()

func _refresh_tile_info(tile: Dictionary, tx: int, ty: int) -> void:
	var tile_info: RichTextLabel = _panels.get("tile_info")
	if not tile_info:
		return

	var bb = "[b]Tile (%d, %d)[/b]\n" % [tx, ty]
	if _showing_underground:
		bb += "[color=#aa88ff][Underground][/color]\n"
	bb += "Terrain: %s\n" % tile["terrain"].capitalize()

	if tile.get("resource", "") != "":
		bb += "Resource: %s\n" % tile["resource"].capitalize()

	var owner = tile.get("owner", -1)
	if owner >= 0 and owner < ColonyData.nations.size():
		bb += "Owner: %s\n" % ColonyData.nations[owner].get("name", "?")

	var buildings: Array = tile.get("buildings", [])
	if buildings.size() > 0:
		bb += "Buildings:\n"
		for b in buildings:
			var bname = ColonyData.BUILDINGS.get(b, {}).get("name", b)
			bb += "  - %s\n" % bname

	var fm = _get_faction_manager()
	if fm:
		var factions = fm.get_factions_on_tile(tx, ty)
		if factions.size() > 0:
			bb += "[color=red]Faction: %s[/color]\n" % ColonyData.FACTIONS.get(factions[0]["type"], {}).get("name", "?")

	tile_info.text = bb

func _on_world_generated(_w: int, _h: int) -> void:
	_show_player_controls()
	_refresh_all()

# --- Building Placement Mode ---

func _toggle_placement_mode() -> void:
	_placement_mode = !_placement_mode
	if _placement_mode:
		_selected_building = "shrine"  # Default
	EventBus.building_placement_mode_changed.emit(_placement_mode)
	var btn: Button = _panels.get("build_btn")
	if btn:
		btn.text = "Cancel" if _placement_mode else "Build"

func _on_building_placed(tile_x: int, tile_y: int, building_id: String, nation_id: int) -> void:
	if nation_id == ColonyData.player_nation_id:
		_placement_mode = false
		EventBus.building_placement_mode_changed.emit(false)
		var btn: Button = _panels.get("build_btn")
		if btn:
			btn.text = "Build"

func _on_underground_toggled(enabled: bool) -> void:
	_showing_underground = enabled
	# Refresh hovered tile info if currently hovering
	if _hovered_tile_x >= 0 and _hovered_tile_y >= 0:
		_on_tile_hovered(_hovered_tile_x, _hovered_tile_y)

func _on_placement_tile_clicked(tile_x: int, tile_y: int) -> void:
	if not _placement_mode:
		return
	var bm = _get_building_manager()
	if bm:
		bm.place_building(tile_x, tile_y, _selected_building, ColonyData.player_nation_id)

func _on_placement_mode_changed(active: bool) -> void:
	var panel: PanelContainer = _panels["build_panel"]
	_placement_mode = active
	if active:
		panel.show()
		_refresh_building_selection()
	else:
		panel.hide()
	var btn: Button = _panels.get("build_btn")
	if btn:
		btn.text = "Cancel" if active else "Build"

func _on_season_changed(new_season: String, _year: int) -> void:
	var effects_str = _format_season_effects(new_season)
	_show_toast("ðŸŒ¤ï¸  %s: %s" % [new_season, effects_str])

func _format_season_effects(season: String) -> String:
	var rm = _get_resource_manager()
	if not rm:
		return ""
	var sm: Dictionary = rm.seasonal_modifier(season)
	var parts: Array[String] = []
	var pct: int
	if sm.has("food"):
		pct = int((sm["food"] - 1.0) * 100)
		if pct != 0:
			parts.append("Food %s%d%%" % ["+" if pct > 0 else "", pct])
	if sm.has("trade"):
		pct = int((sm["trade"] - 1.0) * 100)
		if pct != 0:
			parts.append("Trade %s%d%%" % ["+" if pct > 0 else "", pct])
	if sm.has("growth"):
		pct = int((sm["growth"] - 1.0) * 100)
		if pct != 0:
			parts.append("Growth %s%d%%" % ["+" if pct > 0 else "", pct])
	if sm.has("military_speed"):
		pct = int((sm["military_speed"] - 1.0) * 100)
		if pct != 0:
			parts.append("Mil %s%d%%" % ["+" if pct > 0 else "", pct])
	if sm.has("mortality"):
		pct = int((sm["mortality"] - 1.0) * 100)
		if pct != 0:
			parts.append("Mortality %s%d%%" % ["+" if pct > 0 else "", pct])
	if parts.is_empty():
		return "neutral effects"
	return ", ".join(parts)

func _show_toast(text: String) -> void:
	ColonyData.add_notification(text, "general")
	var container = _panels.get("toast_container")
	if not container:
		return

	var toast = Label.new()
	toast.text = text
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD
	toast.custom_minimum_size = Vector2(280, 0)
	toast.modulate = Color(1, 1, 1, 1)

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	bg.border_color = Color(0.85, 0.7, 0.2, 0.6)
	bg.border_width_left = 1; bg.border_width_right = 1
	bg.border_width_top = 1; bg.border_width_bottom = 1
	bg.corner_radius_top_left = 8; bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_left = 8; bg.corner_radius_bottom_right = 8
	toast.add_theme_stylebox_override("normal", bg)

	container.add_child(toast)

	var tween = create_tween()
	tween.set_parallel(false)
	tween.tween_interval(2.5)
	tween.tween_property(toast, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(toast.queue_free)

func _refresh_building_selection() -> void:
	var container: VBoxContainer = _panels["build_list"]
	for child in container.get_children():
		child.queue_free()

	var nat = ColonyData.get_player_nation()
	if nat.is_empty():
		return

	# Get hovered tile terrain for in-range filtering
	var hovered_terrain = ""
	var hovered_tile = ColonyData.get_tile(_hovered_tile_x, _hovered_tile_y)
	if not hovered_tile.is_empty():
		hovered_terrain = hovered_tile.get("terrain", "")

	# Gather building IDs for current category
	var category_building_ids: Array[String] = []
	for bid in ColonyData.BUILDINGS:
		var cat_bdata = ColonyData.BUILDINGS[bid]
		if cat_bdata.get("category", "") == _current_category:
			category_building_ids.append(bid)

	# Sort by tier then name
	category_building_ids.sort_custom(func(a: String, b: String) -> bool:
		var da = ColonyData.BUILDINGS[a]
		var db = ColonyData.BUILDINGS[b]
		if da.get("tier", 1) != db.get("tier", 1):
			return da.get("tier", 1) < db.get("tier", 1)
		return da.get("name", a) < db.get("name", b)
	)

	for building_id in category_building_ids:
		var bdata = ColonyData.BUILDINGS[building_id]
		var cost: Dictionary = bdata.get("cost", {})
		var effects: Dictionary = bdata.get("effects", {})

		# Validity checks
		var valid_terrain = hovered_terrain == "" or hovered_terrain in bdata.get("placement_terrain", [])
		var affordable = true
		for r in cost:
			if nat["resources"].get(r, 0.0) < cost[r]:
				affordable = false
				break
		var can_place = valid_terrain and affordable

		var hbox = HBoxContainer.new()

		# Name + tier badge
		var tier = bdata.get("tier", 1)
		var tier_str = ""
		for _i in range(tier):
			tier_str += "â˜…"
		var info = Label.new()
		info.text = "%s %s" % [bdata.get("name", building_id), tier_str]
		if not can_place:
			info.add_theme_color_override("font_color", Color.GRAY)
		hbox.add_child(info)

		# Cost compact
		var costs_text = ""
		for _r in cost:
			costs_text += "%s:%d " % [_r.capitalize().left(3), cost[_r]]
		if costs_text != "":
			var cost_label = Label.new()
			cost_label.text = "[" + costs_text.strip_edges() + "]"
			if not affordable:
				cost_label.add_theme_color_override("font_color", Color.GRAY)
			hbox.add_child(cost_label)

		# Effects summary
		var effects_text = ""
		for e in effects:
			var val = effects[e]
			var pct = int((val - 1.0) * 100)
			var sign = "+" if pct >= 0 else ""
			effects_text += "%s%s%d%% " % [e.capitalize(), sign, pct]
		if effects_text != "":
			var eff_label = Label.new()
			eff_label.text = effects_text.strip_edges()
			eff_label.add_theme_color_override("font_color", Color("#88ccff"))
			hbox.add_child(eff_label)

		# Select button
		var select_btn = Button.new()
		if _selected_building == building_id:
			select_btn.text = "âœ“"
			select_btn.disabled = true
		elif can_place:
			select_btn.text = "Build"
		else:
			select_btn.text = "Build"
			select_btn.disabled = true

		var _bid = building_id
		select_btn.pressed.connect(func():
			_selected_building = _bid
			_refresh_building_selection()
		)
		hbox.add_child(select_btn)

		container.add_child(hbox)

	# --- Upgrade section: check hovered tile for upgradeable buildings ---
	if _hovered_tile_x >= 0 and _hovered_tile_y >= 0:
		var upgrade_tile = ColonyData.get_tile(_hovered_tile_x, _hovered_tile_y)
		if not upgrade_tile.is_empty():
			var tile_buildings: Array = upgrade_tile.get("buildings", [])
			var tile_owner: int = upgrade_tile.get("owner", -1)
			if tile_owner == ColonyData.player_nation_id and tile_buildings.size() > 0:
				var has_upgrade = false
				for b_on_tile in tile_buildings:
					var b_tmp = ColonyData.BUILDINGS.get(b_on_tile, {})
					if b_tmp.get("upgrade_to", "") != "":
						has_upgrade = true
						break

				if has_upgrade:
					container.add_child(_make_separator())
					var upgrade_header = Label.new()
					upgrade_header.text = "--- Upgrades ---"
					upgrade_header.add_theme_font_size_override("font_size", 14)
					container.add_child(upgrade_header)

					for _b_on_tile in tile_buildings:
						var bdata_upg = ColonyData.BUILDINGS.get(_b_on_tile, {})
						var upgrade_to: String = bdata_upg.get("upgrade_to", "")
						if upgrade_to == "":
							continue

						var upgrade_data = ColonyData.BUILDINGS.get(upgrade_to, {})
						if upgrade_data.is_empty():
							continue

						var cur_name = bdata_upg.get("name", _b_on_tile)
						var upg_name = upgrade_data.get("name", upgrade_to)

						# Cost difference
						var old_cost: Dictionary = bdata_upg.get("cost", {})
						var new_cost: Dictionary = upgrade_data.get("cost", {})
						var cost_diff_text = ""
						var can_afford_upgrade = true

						for _rc in new_cost:
							var diff = new_cost[_rc] - old_cost.get(_rc, 0.0)
							if diff > 0:
								cost_diff_text += "%s:%d " % [_rc.capitalize().left(3), diff]
								if nat.get("resources", {}).get(_rc, 0.0) < diff:
									can_afford_upgrade = false

						var row = HBoxContainer.new()
						var upg_info = Label.new()
						upg_info.text = "%s â†’ %s" % [cur_name, upg_name]
						if cost_diff_text != "":
							upg_info.text += " [%s]" % cost_diff_text.strip_edges()
						if not can_afford_upgrade:
							upg_info.add_theme_color_override("font_color", Color.GRAY)
						row.add_child(upg_info)

						var upgrade_btn = Button.new()
						upgrade_btn.text = "Upgrade"
						if not can_afford_upgrade:
							upgrade_btn.disabled = true

						var upg_id = upgrade_to
						var _tx: int = _hovered_tile_x; var _ty: int = _hovered_tile_y
						upgrade_btn.pressed.connect(func():
							var bm = _get_building_manager()
							if bm:
								bm.place_building(_tx, _ty, upg_id, ColonyData.player_nation_id)
								_refresh_building_selection()
						)
						row.add_child(upgrade_btn)
						container.add_child(row)

	# Cancel button
	container.add_child(_make_separator())
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel Placement"
	cancel_btn.pressed.connect(func():
		_placement_mode = false
		EventBus.building_placement_mode_changed.emit(false)
	)
	container.add_child(cancel_btn)

func _on_pause_pressed() -> void:
	var btn: Button = _panels["pause"]
	if GameManager.current_state == GameManager.GameState.PAUSED:
		GameManager.change_state(GameManager.GameState.PLAYING)
		btn.text = "Pause"
	else:
		GameManager.change_state(GameManager.GameState.PAUSED)
		btn.text = "Play"

func _change_speed(dir: int) -> void:
	_speed_index = clamp(_speed_index + dir, 0, _speed_levels.size() - 1)
	var tm = _get_time_manager()
	if tm:
		tm.set_speed(_speed_levels[_speed_index])

func _on_event_triggered(nation_id: int, event_id: String, event_data: Dictionary) -> void:
	if nation_id != ColonyData.player_nation_id:
		return
	GameManager.change_state(GameManager.GameState.EVENT_DIALOG)
	_display_event(event_data)

func _display_event(event_data: Dictionary) -> void:
	var dlg: PanelContainer = _panels["event_dialog"]
	var title: Label = _panels["event_title"]
	var desc: Label = _panels["event_desc"]
	var options: VBoxContainer = _panels["event_options"]
	title.text = event_data["name"]
	desc.text = event_data["description"]
	for child in options.get_children():
		child.queue_free()
	for outcome_key in event_data["outcomes"]:
		var outcome = event_data["outcomes"][outcome_key]
		var btn = Button.new()
		btn.text = outcome["label"]
		btn.tooltip_text = outcome["description"]
		var okey = outcome_key
		var evid = event_data["id"]
		btn.pressed.connect(func():
			var em = _get_event_manager()
			if em: em.resolve_event(evid, okey)
			dlg.hide()
			GameManager.change_state(GameManager.GameState.PLAYING)
		)
		options.add_child(btn)
	dlg.show()

func _on_defeat_triggered(reason: String, description: String) -> void:
	_show_toast("\u2620 DEFEAT: %s â€” %s" % [reason, description])
	_display_defeat_overlay(reason, description)


func _display_defeat_overlay(reason: String, description: String) -> void:
	# Remove any existing overlay
	if _panels.has("defeat_overlay"):
		var old = _panels["defeat_overlay"]
		old.queue_free()

	var overlay = PanelContainer.new()
	overlay.name = "DefeatOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.02, 0.02, 0.85) # Deep red translucent background
	overlay.add_theme_stylebox_override("panel", bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)

	var icon = Label.new()
	icon.text = "DEFEAT"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 64)
	icon.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))
	vbox.add_child(icon)

	var reason_label = Label.new()
	reason_label.text = reason
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.add_theme_font_size_override("font_size", 32)
	reason_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	vbox.add_child(reason_label)

	var desc = Label.new()
	desc.text = description
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", Color(0.8, 0.6, 0.6))
	vbox.add_child(desc)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var close_btn = Button.new()
	close_btn.text = "Quit to Menu"
	close_btn.custom_minimum_size = Vector2(200, 40)
	close_btn.pressed.connect(func():
		overlay.queue_free()
		_panels.erase("defeat_overlay")
		GameManager.change_state(GameManager.GameState.MAIN_MENU)
		get_tree().reload_current_scene()
	)
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_child(_make_spacer())
	btn_hbox.add_child(close_btn)
	
	# Add a quit application button
	var quit_btn = Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(200, 40)
	quit_btn.pressed.connect(func(): get_tree().quit())
	btn_hbox.add_child(quit_btn)
	
	btn_hbox.add_child(_make_spacer())
	vbox.add_child(btn_hbox)

	center.add_child(vbox)
	overlay.add_child(center)
	
	# Fade-in animation
	overlay.modulate = Color(1, 1, 1, 0)
	add_child(overlay)
	var t = create_tween()
	t.tween_property(overlay, "modulate", Color(1, 1, 1, 1), 0.5)
	
	_panels["defeat_overlay"] = overlay

func _display_victory_overlay(victory_type: String, description: String) -> void:
	# Remove any existing overlay
	if _panels.has("victory_overlay"):
		var old = _panels["victory_overlay"]
		old.queue_free()

	var overlay = PanelContainer.new()
	overlay.name = "VictoryOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.08, 0.85) # Deep dark glass background
	overlay.add_theme_stylebox_override("panel", bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)

	var icon = Label.new()
	icon.text = "VICTORY"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 64)
	icon.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(icon)

	var type_label = Label.new()
	type_label.text = victory_type
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 32)
	type_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(type_label)

	var desc = Label.new()
	desc.text = description
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	vbox.add_child(desc)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var close_btn = Button.new()
	close_btn.text = "Continue Watching"
	close_btn.custom_minimum_size = Vector2(200, 40)
	close_btn.pressed.connect(func():
		overlay.queue_free()
		_panels.erase("victory_overlay")
		_enter_spectator_mode()
	)
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_child(_make_spacer())
	btn_hbox.add_child(close_btn)
	
	# Add Return to Menu button
	var menu_btn = Button.new()
	menu_btn.text = "Return to Menu"
	menu_btn.custom_minimum_size = Vector2(200, 40)
	menu_btn.pressed.connect(func():
		overlay.queue_free()
		_panels.erase("victory_overlay")
		GameManager.change_state(GameManager.GameState.MAIN_MENU)
		get_tree().reload_current_scene()
	)
	btn_hbox.add_child(menu_btn)
	
	
	# Add a quit application button
	var quit_btn = Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(200, 40)
	quit_btn.pressed.connect(func(): get_tree().quit())
	btn_hbox.add_child(quit_btn)
	
	btn_hbox.add_child(_make_spacer())
	vbox.add_child(btn_hbox)

	center.add_child(vbox)
	overlay.add_child(center)
	
	# Fade-in animation
	overlay.modulate = Color(1, 1, 1, 0)
	add_child(overlay)
	var t = create_tween()
	t.tween_property(overlay, "modulate", Color(1, 1, 1, 1), 0.5)
	
	_panels["victory_overlay"] = overlay

# =============================================================================
# SPECTATOR MODE
# =============================================================================

func _enter_spectator_mode() -> void:
	GameManager.change_state(GameManager.GameState.SPECTATOR)
	
	# Hide any open fullscreen overlays (diplomacy, tech tree, etc.)
	var panel_keys = [
		"policy_panel", "skill_tree_panel", "influence_panel", "prophet_panel",
		"diplomacy_panel", "deity_panel", "culture_panel", "pantheon_panel",
		"history_panel", "government_panel", "tech_panel", "log_panel"
	]
	for key in panel_keys:
		if _panels.has(key) and _panels[key].visible:
			_panels[key].hide()
	
	# Hide all player interaction controls
	_hide_player_controls()
	
	# Lift fog of war â€” all tiles visible
	var fog = _find_fog_renderer()
	if fog:
		fog.set_spectator_mode(true)
	
	# Create spectator stats overlay
	_create_spectator_overlay()


func _exit_spectator_mode() -> void:
	# Remove spectator overlay
	if _panels.has("spectator_overlay"):
		_panels["spectator_overlay"].queue_free()
		_panels.erase("spectator_overlay")
	
	# Restore fog
	var fog = _find_fog_renderer()
	if fog:
		fog.set_spectator_mode(false)
	
	# Show player controls if not in main menu
	if GameManager.current_state != GameManager.GameState.MAIN_MENU:
		_show_player_controls()


func _hide_player_controls() -> void:
	if _panels.has("top_bar"):
		_panels["top_bar"].hide()
	# Side panel (left â€” contains resources, stats, deity, tile info)
	if _panels.has("side_panel"):
		_panels["side_panel"].hide()
	
	# Bottom bar (Build, Policies, Diplomacy, etc.)
	if _panels.has("bottom_bar"):
		_panels["bottom_bar"].hide()
	
	# Building panel
	if _panels.has("build_panel"):
		_panels["build_panel"].hide()
	if _panels.has("build_btn"):
		_panels["build_btn"].hide()


func _show_player_controls() -> void:
	if _panels.has("top_bar"):
		_panels["top_bar"].show()
	if _panels.has("side_panel"):
		_panels["side_panel"].show()
	if _panels.has("bottom_bar"):
		_panels["bottom_bar"].show()
	if _panels.has("build_btn"):
		_panels["build_btn"].show()


func _find_fog_renderer() -> Node:
	var root = _scene_cache
	if root:
		var systems = root.get_node_or_null("Systems")
		if systems:
			return systems.get_node_or_null("FogRenderer")
	return null


func _create_spectator_overlay() -> void:
	# Remove existing if any
	if _panels.has("spectator_overlay"):
		_panels["spectator_overlay"].queue_free()
		_panels.erase("spectator_overlay")
	
	var overlay = PanelContainer.new()
	overlay.name = "SpectatorOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Pass clicks through to world
	_panels["spectator_overlay"] = overlay
	
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0)  # Transparent background
	overlay.add_theme_stylebox_override("panel", bg)
	
	# === Top-left stats panel ===
	var stats_panel = PanelContainer.new()
	stats_panel.name = "SpectatorStats"
	stats_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stats_panel.set_offset(SIDE_TOP, 42)
	stats_panel.set_offset(SIDE_LEFT, 10)
	stats_panel.custom_minimum_size = Vector2(280, 0)
	stats_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # Can interact with stats
	
	var stats_bg = StyleBoxFlat.new()
	stats_bg.bg_color = Color(0.05, 0.05, 0.1, 0.82)
	stats_bg.border_color = Color(0.3, 0.3, 0.5, 0.4)
	stats_bg.border_width_left = 1; stats_bg.border_width_right = 1
	stats_bg.border_width_top = 1; stats_bg.border_width_bottom = 1
	stats_bg.corner_radius_top_left = 4; stats_bg.corner_radius_top_right = 4
	stats_bg.corner_radius_bottom_left = 4; stats_bg.corner_radius_bottom_right = 4
	stats_panel.add_theme_stylebox_override("panel", stats_bg)
	
	var stats_scroll = ScrollContainer.new()
	stats_scroll.custom_minimum_size = Vector2(260, 200)
	stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var stats_vbox = VBoxContainer.new()
	stats_vbox.name = "SpectatorStatsContent"
	stats_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	stats_scroll.add_child(stats_vbox)
	stats_panel.add_child(stats_scroll)
	overlay.add_child(stats_panel)
	
	# Refresh the stats
	_refresh_spectator_stats()
	
	# Connect to tick updates for live stats
	if not EventBus.tick_advanced.is_connected(_on_spectator_tick):
		EventBus.tick_advanced.connect(_on_spectator_tick)
	
	# === Top-right "Quit to Menu" button ===
	var quit_panel = PanelContainer.new()
	quit_panel.name = "SpectatorQuit"
	quit_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quit_panel.set_offset(SIDE_TOP, 42)
	quit_panel.set_offset(SIDE_RIGHT, -10)
	quit_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var quit_bg = StyleBoxFlat.new()
	quit_bg.bg_color = Color(0.08, 0.08, 0.15, 0.85)
	quit_bg.border_color = Color(0.4, 0.2, 0.2, 0.6)
	quit_bg.border_width_left = 1; quit_bg.border_width_right = 1
	quit_bg.border_width_top = 1; quit_bg.border_width_bottom = 1
	quit_bg.corner_radius_top_left = 4; quit_bg.corner_radius_top_right = 4
	quit_bg.corner_radius_bottom_left = 4; quit_bg.corner_radius_bottom_right = 4
	quit_panel.add_theme_stylebox_override("panel", quit_bg)
	
	var quit_vbox = VBoxContainer.new()
	quit_vbox.add_theme_constant_override("separation", 8)
	
	var quit_title = Label.new()
	quit_title.text = "SPECTATOR MODE"
	quit_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quit_title.add_theme_font_size_override("font_size", 11)
	quit_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	quit_vbox.add_child(quit_title)
	
	var quit_btn = Button.new()
	quit_btn.text = "Quit to Menu"
	quit_btn.custom_minimum_size = Vector2(140, 36)
	quit_btn.pressed.connect(_on_spectator_quit)
	quit_vbox.add_child(quit_btn)
	
	quit_panel.add_child(quit_vbox)
	overlay.add_child(quit_panel)
	
	add_child(overlay)


func _refresh_spectator_stats() -> void:
	if not _panels.has("spectator_overlay"):
		return
	
	var overlay: PanelContainer = _panels["spectator_overlay"]
	var stats_panel = overlay.get_node_or_null("SpectatorStats")
	if not stats_panel:
		return
	
	var scroll = stats_panel.get_child(0) if stats_panel.get_child_count() > 0 else null
	if not scroll or not (scroll is ScrollContainer):
		return
	
	var content = scroll.get_child(0) if scroll.get_child_count() > 0 else null
	if not content or not (content is VBoxContainer):
		return
	
	# Clear previous content
	for child in content.get_children():
		child.queue_free()
	
	var title = Label.new()
	title.text = "WORLD STATUS"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	content.add_child(title)
	content.add_child(HSeparator.new())
	
	for nation in ColonyData.nations:
		var is_player = nation["id"] == ColonyData.player_nation_id
		var name_color = "#ffd700" if is_player else "#ffffff"
		var prefix = "ðŸ‘‘ " if is_player else "  "
		
		var bb = "[color=%s]%s%s[/color]\n" % [name_color, prefix, nation.get("name", "Unknown")]
		
		var race_id: String = nation.get("primary_race", "human")
		bb += "  Race: %s\n" % ColonyData.RACES.get(race_id, {}).get("name", race_id)
		bb += "  Pop: [color=#88ff88]%d[/color]\n" % nation.get("population", 0)
		bb += "  Military: [color=#ff8888]%d[/color]\n" % nation.get("military_strength", 0)
		
		# Resources
		var res: Dictionary = nation.get("resources", {})
		var res_parts: Array[String] = []
		for r in res:
			res_parts.append("[color=#88ccff]%s: %.0f[/color]" % [r.capitalize(), res[r]])
		if not res_parts.is_empty():
			bb += "  " + ", ".join(res_parts) + "\n"
		
		# Colonies
		var colonies: Array = nation.get("colonies", [])
		bb += "  Colonies: %d\n" % colonies.size()
		
		# Government
		var gov: String = nation.get("government", "kingdom")
		var gov_data = ColonyData.GOVERNMENT_TYPES.get(gov, {})
		bb += "  Gov: %s\n" % gov_data.get("name", gov.capitalize())
		
		var entry = RichTextLabel.new()
		entry.bbcode_enabled = true
		entry.fit_content = true
		entry.text = bb
		content.add_child(entry)
		content.add_child(HSeparator.new())


func _on_spectator_tick(_tick: int, _day: int, _season: String, _year: int) -> void:
	if GameManager.current_state == GameManager.GameState.SPECTATOR:
		_refresh_spectator_stats()


func _on_spectator_quit() -> void:
	_exit_spectator_mode()
	EventBus.tick_advanced.disconnect(_on_spectator_tick)
	
	# Clean up fog lift
	var fog = _find_fog_renderer()
	if fog:
		fog.set_spectator_mode(false)
	
	# Return to main menu
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
	get_tree().reload_current_scene()

# --- Panel openers ---
func _open_policy_panel() -> void: _show_panel("policy_panel", _refresh_policy_panel_content)
func _open_skill_tree_panel() -> void: _show_panel("skill_tree_panel", _refresh_skill_tree_content)
func _open_influence_panel() -> void: _show_panel("influence_panel", _refresh_influence_content)
func _open_prophet_panel() -> void: _show_panel("prophet_panel", _refresh_prophet_content)
func _open_diplomacy_panel() -> void: _show_panel("diplomacy_panel", _refresh_diplomacy_panel_content)
func _open_deity_miracles_panel() -> void: _show_panel("deity_panel", _refresh_deity_panel_content)
func _open_culture_panel() -> void: _show_panel("culture_panel", _refresh_culture_content)
func _open_history_panel() -> void: _show_panel("history_panel", _refresh_history_content)
func _open_pantheon_panel() -> void: _show_panel("pantheon_panel", _refresh_pantheon_content)
func _open_government_panel() -> void: _show_panel("government_panel", _refresh_government_content)
func _open_tech_tree_panel() -> void: _show_panel("tech_panel", _refresh_tech_content)
func _open_log_panel() -> void: _show_panel("log_panel", _refresh_log_content)
func _open_factions_panel() -> void: _show_panel("faction_panel", _refresh_factions_content)

func _show_panel(panel_key: String, refresh_func: Callable) -> void:
	# Hide all fullscreen panels first (single-panel-at-a-time)
	var target: PanelContainer = _panels[panel_key]
	for key in FULLSCREEN_PANEL_KEYS:
		var p = _panels.get(key)
		if p is PanelContainer and p.visible and p != target:
			var tween_out = create_tween()
			tween_out.set_parallel(false)
			tween_out.tween_property(p, "modulate:a", 0.0, 0.12)
			tween_out.tween_callback(p.hide)
	refresh_func.call(target)
	target.modulate = Color(1, 1, 1, 0)
	target.show()
	var tween_in = create_tween()
	tween_in.set_parallel(false)
	tween_in.tween_property(target, "modulate", Color(1, 1, 1, 1), 0.2)

func _create_fullscreen_panel(title_text: String) -> PanelContainer:
	var overlay = PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Add a dark semi-transparent background to focus on the window
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.58)
	overlay.add_theme_stylebox_override("panel", bg_style)
	overlay.hide()

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 620)
	panel.add_theme_stylebox_override("panel", _make_textured_panel_style(UI_WOOD_PANEL_PATH, Color(0.1, 0.065, 0.045, 0.98), 18, 12))
	center.add_child(panel)

	var margin = _make_margin_container(18, 16, 18, 18)
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)

	var hdr = HBoxContainer.new()
	var tl = Label.new()
	tl.text = title_text
	tl.theme_type_variation = "HeaderLarge"
	tl.add_theme_color_override("font_color", Color("#f1d891"))
	hdr.add_child(tl)
	hdr.add_child(_make_spacer())
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(42, 34)
	close_btn.pressed.connect(func(): overlay.hide())
	hdr.add_child(close_btn)
	vbox.add_child(hdr)
	vbox.add_child(_make_separator())

	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var content = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	scroll.add_child(content)
	vbox.add_child(scroll)
	margin.add_child(vbox)
	panel.add_child(margin)
	add_child(overlay)
	
	return overlay

# --- Refresh methods ---

func _refresh_all() -> void:
	_refresh_resource_panel()
	_refresh_stats_panel()
	_refresh_artifacts_panel()
	_refresh_deity_panel()

func _refresh_resource_panel() -> void:
	var text: RichTextLabel = _panels["resources"]
	var nat = ColonyData.get_player_nation()
	if nat.is_empty():
		text.text = ""
		return
	var bb = ""
	for res in nat["resources"]:
		var amount: float = nat["resources"][res]
		var color = "#ffffff"
		if amount < 10: color = "#ff4444"
		elif amount < 30: color = "#ffaa44"
		bb += "[color=#d8b458]%s[/color] [color=%s]%.0f[/color]   " % [res.capitalize(), color, amount]
	text.text = bb.strip_edges()

func _refresh_stats_panel() -> void:
	var text: RichTextLabel = _panels["stats"]
	var nat = ColonyData.get_player_nation()
	if nat.is_empty():
		text.text = ""
		return

	# Update leader portrait
	var race_id: String = nat.get("primary_race", "human")
	var portrait_path = "res://assets/portraits/%s.png" % race_id
	var portrait: TextureRect = _panels.get("leader_portrait")
	if portrait:
		if ResourceLoader.exists(portrait_path):
			portrait.texture = load(portrait_path) as Texture2D
		else:
			portrait.texture = null

	# Update leader name label
	var leader_name: Label = _panels.get("leader_name")
	var leader = ColonyData.get_leader(nat["id"])
	if leader_name:
		if not leader.is_empty():
			leader_name.text = leader["name"]
		else:
			leader_name.text = nat.get("name", "")

	var bb = "[b]%s[/b]\n" % nat.get("name", "Unknown")
	bb += "Race: %s\n" % ColonyData.RACES.get(nat["primary_race"], {}).get("name", "?")

	# Demographics
	var demos = nat.get("race_demographics", {})
	if demos.size() > 0:
		for rid in demos:
			bb += "  %s: %.0f%%\n" % [ColonyData.RACES.get(rid, {}).get("name", rid), demos[rid] * 100]

	bb += "Pop: %d\n" % nat["population"]
	bb += "Military: %d\n" % nat["military_strength"]

	# Leader (details â€” name shown in portrait HBox above)
	if not leader.is_empty():
		bb += "\n[b]Ruler:[/b]\n"
		bb += "  (%s %s, %s)\n" % [leader["race"], leader["gender"], leader["archetype"]]
		bb += "  Traits: %s\n" % ", ".join(leader["traits"])
		bb += "  Resistance: %.1f\n" % leader.get("influence_resistance", 1.0)

	# Belief
	bb += "\n[b]Believers:[/b]\n"
	var total = 0
	for _rid in demos:
		var belief = ColonyData.get_belief(nat["id"], _rid)
		var pop_share = demos[_rid]
		var believers = int(nat["population"] * pop_share * belief)
		total += believers
		bb += "  %s: %.0f%% (%d)\n" % [ColonyData.RACES.get(_rid, {}).get("name", _rid), belief * 100, believers]
	bb += "  Total believers: %d\n" % total

	# Relations
	for n in ColonyData.nations:
		if n["id"] == ColonyData.player_nation_id:
			continue
		var rel = _get_relation(n["id"])
		bb += "[color=%s]%s[/color]: %s\n" % [_relation_color(rel), n["name"], _relation_label(rel)]

	text.text = bb

func _refresh_artifacts_panel() -> void:
	var text: RichTextLabel = _panels.get("artifacts")
	if not text:
		return

	var nat = ColonyData.get_player_nation()
	if nat.is_empty():
		text.text = ""
		return

	var nation_id: int = ColonyData.player_nation_id
	var owned: Array[Dictionary] = []
	for art in ColonyData.artifacts:
		if art.get("owner_nation_id", -1) == nation_id:
			owned.append(art)

	if owned.is_empty():
		text.text = "[color=#666688]No artifacts yet[/color]"
		return

	var bb = ""
	for _art in owned:
		bb += "[color=#ffd700]%s[/color]\n" % _art.get("title", "???")
		bb += "  %s\n" % _art.get("description", "")

	text.text = bb

func _refresh_deity_panel() -> void:
	var text: RichTextLabel = _panels["deity"]
	var dm = _get_deity_manager()
	if not dm or dm.deity_class.is_empty():
		text.text = "No deity chosen"
		return

	var class_data = dm.DEITY_CLASSES.get(dm.deity_class, {})
	var bb = ""
	# --- Deity symbol inline ---
	var symbol_path = "res://assets/symbols/%s.png" % dm.deity_class
	if ResourceLoader.exists(symbol_path):
		bb = "[img=24,24]%s[/img] " % symbol_path
	bb += "[b]%s[/b] (%s)\n" % [class_data.get("name", "?"), ColonyData.deity_domain]
	bb += "Domain: %s\n" % ColonyData.deity_domain
	bb += "Rank: %d (%s)\n" % [dm.rank, _rank_name(dm.rank)]
	bb += "Power: %.0f / %.0f\n" % [dm.divine_power, dm.max_divine_power]
	bb += "Skill Points: %d\n" % dm.skill_points
	text.text = bb

func _refresh_policy_panel_content(panel: PanelContainer) -> void:
	var content: VBoxContainer = panel.find_child("Content", true, false)
	for child in content.get_children():
		child.queue_free()
	var nat_id = ColonyData.player_nation_id

	var active_label = Label.new()
	active_label.text = "Active Policies:"
	content.add_child(active_label)
	var pmgr = _get_policy_manager()
	for p in pmgr.get_active_policies(nat_id) if pmgr else []:
		var row = HBoxContainer.new()
		var info = Label.new()
		info.text = "[x] %s - %s" % [p["name"], p["description"]]
		row.add_child(info)
		var revoke = Button.new()
		revoke.text = "Revoke"
		var pname = p["name"]
		revoke.pressed.connect(func():
			var pm = _get_policy_manager()
			if pm: pm.revoke_policy(nat_id, _find_policy_id(pname))
			_refresh_policy_panel_content(panel)
		)
		row.add_child(revoke)
		content.add_child(row)

	var avail_label = Label.new()
	avail_label.text = "\nAvailable Policies:"
	content.add_child(avail_label)
	for _p in pmgr.get_available_policies(nat_id) if pmgr else []:
		var hbox = HBoxContainer.new()
		var lbl = Label.new()
		hbox.add_child(lbl)
		var avail_info = Label.new()
		avail_info.text = "%s - %s" % [_p["name"], _p["description"]]
		hbox.add_child(avail_info)
		var enact = Button.new()
		enact.text = "Enact"
		var avail_pname = _p["name"]
		enact.pressed.connect(func():
			var pm = _get_policy_manager()
			if pm: pm.enact_policy(nat_id, _find_policy_id(avail_pname))
		)
		hbox.add_child(enact)
		content.add_child(hbox)

func _refresh_skill_tree_content(panel: PanelContainer) -> void:
	var content: VBoxContainer = panel.find_child("Content", true, false)
	for child in content.get_children():
		child.queue_free()

	var dm = _get_deity_manager()
	if not dm or dm.deity_class.is_empty():
		var lbl = Label.new()
		lbl.text = "[No deity chosen]"
		content.add_child(lbl)
		return

	var sp_label = Label.new()
	sp_label.text = "Skill Points: %d" % dm.skill_points
	sp_label.add_theme_font_size_override("font_size", 16)
	content.add_child(sp_label)

	for skill in dm.get_available_skills():
		var hbox = HBoxContainer.new()
		var icon = "â—†" if not skill["unlocked"] else "â—"
		if skill["unlockable"]: icon = "â–¶"
		var info = Label.new()
		info.text = "%s [%s] %s - %s (Cost: %d)" % [icon, skill["tier"], skill["name"], skill["desc"], skill["cost"]]
		if skill["unlocked"]:
			info.add_theme_color_override("font_color", Color.GREEN)
		hbox.add_child(info)

		if skill["unlockable"]:
			var unlock_btn = Button.new()
			unlock_btn.text = "Unlock"
			var sid = skill["id"]
			unlock_btn.pressed.connect(func():
				dm.unlock_skill(sid)
				_refresh_skill_tree_content(panel)
			)
			hbox.add_child(unlock_btn)

		content.add_child(hbox)

func _refresh_influence_content(panel: PanelContainer) -> void:
	var content: VBoxContainer = panel.find_child("Content", true, false)
	for child in content.get_children():
		child.queue_free()

	var dm = _get_deity_manager()
	if not dm or dm.deity_class.is_empty():
		var lbl = Label.new()
		lbl.text = "[No deity chosen]"
		content.add_child(lbl)
		return

	var power_label = Label.new()
	power_label.text = "Divine Power: %.0f / %.0f" % [dm.divine_power, dm.max_divine_power]
	content.add_child(power_label)
	content.add_child(_make_separator())

	# List influenceable nations
	for n in ColonyData.nations:
		if n["id"] == ColonyData.player_nation_id:
			continue

		var nation_header = Label.new()
		nation_header.text = "\n[b]%s[/b] (%s)" % [n["name"], ColonyData.RACES.get(n["primary_race"], {}).get("name", "?")]
		content.add_child(nation_header)

		var leader = ColonyData.get_leader(n["id"])
		if not leader.is_empty():
			var leader_info = Label.new()
			leader_info.text = "  Ruler: %s (%s) - %.1f resist" % [leader["name"], leader["archetype"], leader.get("influence_resistance", 1.0)]
			content.add_child(leader_info)

		var belief_info = Label.new()
		var total_belief = 0.0
		for race_id in n.get("race_demographics", {}):
			total_belief += ColonyData.get_belief(n["id"], race_id)
		belief_info.text = "  Belief: %.0f%%" % (total_belief * 100)
		content.add_child(belief_info)

		var actions_hbox = HBoxContainer.new()
		var nid = n["id"]
		for action_id in ColonyData.INFLUENCE_ACTIONS:
			var action = ColonyData.INFLUENCE_ACTIONS[action_id]
			var btn = Button.new()
			btn.text = "%s (%d)" % [action["name"], int(action["cost"])]
			btn.tooltip_text = action["description"]
			var aid = action_id
			btn.pressed.connect(func():
				var im = _get_influence_manager()
				var result = im.attempt_influence(nid, aid) if im else {"success": false}
				var msg = "[%s] %s on %s" % ["OK" if result["success"] else "FAIL", action["name"], n["name"]]
				print(msg)
				_refresh_influence_content(panel)
			)
			actions_hbox.add_child(btn)
		content.add_child(actions_hbox)

func _refresh_prophet_content(panel: PanelContainer) -> void:
	var content: VBoxContainer = panel.find_child("Content", true, false)
	for child in content.get_children():
		child.queue_free()

	var dm = _get_deity_manager()
	if not dm or dm.deity_class.is_empty():
		var lbl = Label.new()
		lbl.text = "[No deity chosen]"
		content.add_child(lbl)
		return

	# Active prophets
	var prm = _get_prophet_manager()
	var actives = prm.get_active_prophets() if prm else []
	var active_label = Label.new()
	active_label.text = "Active Prophets: %d\n" % actives.size()
	content.add_child(active_label)

	for p in actives:
		var char = _get_character(p["character_id"])
		var info = Label.new()
		var nat = ColonyData.get_nation(p["nation_id"])
		var nation_name = nat.get("name", "Unknown") if not nat.is_empty() else "Unknown"
		info.text = "  %s (%s) -> %s | Ticks: %d | Converts: %d" % [
			char.get("name", "?"), char.get("race", "?"), nation_name,
			p["ticks_active"], p["conversions"]
		]
		content.add_child(info)

		var recall_btn = Button.new()
		recall_btn.text = "Recall"
		var recall_nid = p["nation_id"]
		recall_btn.pressed.connect(func():
			var pr = _get_prophet_manager()
			if pr: pr.recall_prophet(recall_nid)
			_refresh_prophet_content(panel)
		)
		content.add_child(recall_btn)

	content.add_child(_make_separator())

	# Send prophet to new nation
	var send_label = Label.new()
	send_label.text = "\nSend Prophet To:"
	content.add_child(send_label)

	for n in ColonyData.nations:
		if n["id"] == ColonyData.player_nation_id:
			continue
		var hbox = HBoxContainer.new()
		var nation_lbl = Label.new()
		nation_lbl.text = n["name"]
		hbox.add_child(nation_lbl)
		var send_btn = Button.new()
		send_btn.text = "Send (25 power)"
		var send_nid = n["id"]
		send_btn.pressed.connect(func():
			var pr = _get_prophet_manager()
			var result = pr.send_prophet(send_nid) if pr else "no manager"
			print("[Prophet] Send result: %s" % result)
			_refresh_prophet_content(panel)
		)
		hbox.add_child(send_btn)
		content.add_child(hbox)

func _refresh_diplomacy_panel_content(panel: PanelContainer) -> void:
	var content: VBoxContainer = panel.find_child("Content", true, false)
	for child in content.get_children():
		child.queue_free()

	# === Trade Leagues Section ===
	var leagues_label = Label.new()
	leagues_label.text = "[b]Trade Leagues[/b]"
	leagues_label.add_theme_font_size_override("font_size", 14)
	content.add_child(leagues_label)

	for league in ColonyData.trade_leagues:
		var members_text = ""
		for mid in league["members"]:
			var mnat = ColonyData.get_nation(mid)
			members_text += mnat.get("name", "?") + ", "
		var league_entry = Label.new()
		league_entry.text = "  %s: %s" % [league["name"], members_text.trim_suffix(", ")]
		content.add_child(league_entry)

	content.add_child(_make_separator())

	# === Vassalage & Independence Section ===
	var vassal_label = Label.new()
	vassal_label.text = "[b]Vassalage & Independence[/b]"
	vassal_label.add_theme_font_size_override("font_size", 14)
	content.add_child(vassal_label)

	var player_nat = ColonyData.get_player_nation()
	for nation in ColonyData.nations:
		if nation["id"] == player_nat["id"]:
			continue
		for other in ColonyData.nations:
			if other["id"] == nation["id"]:
				continue
			var dmgr = _get_diplomacy_manager()
			var treaty = dmgr.get_treaty(nation["id"], other["id"]) if dmgr else 0
			if dmgr and treaty == dmgr.Treaty.VASSALAGE:
				var rel_label = Label.new()
				rel_label.text = "  %s is vassal of %s" % [nation["name"], other["name"]]
				content.add_child(rel_label)

	# Independence movements
	for movement in ColonyData.independence_movements:
		var vassal = ColonyData.get_nation(movement["vassal_id"])
		var desire: float = movement["desire"]
		var bar = ColorRect.new()
		bar.color = Color.RED.lerp(Color.GREEN, 1.0 - desire)
		bar.custom_minimum_size = Vector2(desire * 200, 12)
		var desire_label = Label.new()
		desire_label.text = "  %s independence desire: %.0f%%" % [vassal.get("name", "?"), desire * 100]
		content.add_child(desire_label)
		content.add_child(bar)

	content.add_child(_make_separator())

	# === Existing Nation Relations ===
	for n in ColonyData.nations:
		if n["id"] == ColonyData.player_nation_id:
			continue
		var rel = _get_relation(n["id"])
		var hbox = HBoxContainer.new()
		# --- Nation flag ---
		var flag_path = "res://assets/flags/%s.jpg" % n["name"].to_lower()
		if ResourceLoader.exists(flag_path):
			var flag_tex = load(flag_path) as Texture2D
			if flag_tex:
				var flag_rect = TextureRect.new()
				flag_rect.texture = flag_tex
				flag_rect.custom_minimum_size = Vector2(32, 16)
				flag_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				flag_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				flag_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				hbox.add_child(flag_rect)
		var info = Label.new()
		info.text = "[%s] %s - Rel: %s (%.0f) | Pop: %d | Mil: %d" % [
			ColonyData.RACES.get(n["primary_race"], {}).get("name", "?"),
			n["name"], _relation_label(rel), rel, n["population"], n["military_strength"]
		]
		hbox.add_child(info)

		var btn_text = "Improve"
		if rel > 80: btn_text = "Alliance"
		elif rel < 20: btn_text = "Provoke"
		var action = Button.new()
		action.text = btn_text
		var nid = n["id"]
		action.pressed.connect(func():
			if rel > 80:
				EventBus.alliance_formed.emit(ColonyData.player_nation_id, nid)
			elif rel < 20:
				EventBus.war_declared.emit(ColonyData.player_nation_id, nid)
			else:
				var dm = _get_diplomacy_manager()
				if dm: dm.change_relation(ColonyData.player_nation_id, nid, 10)
		)
		hbox.add_child(action)
		content.add_child(hbox)

func _refresh_deity_panel_content(panel: PanelContainer) -> void:
	var content: VBoxContainer = panel.find_child("Content", true, false)
	for child in content.get_children():
		child.queue_free()
	var dm = _get_deity_manager()
	if not dm:
		return

	var info = Label.new()
	info.text = "Rank: %d | Power: %.0f/%.0f" % [dm.rank, dm.divine_power, dm.max_divine_power]
	content.add_child(info)
	var lbl1 = Label.new()
	lbl1.text = "--- Available Miracles ---"
	content.add_child(lbl1)

	for m in dm.get_available_miracles():
		var hbox = HBoxContainer.new()
		var lbl2 = Label.new()
		lbl2.text = "[Cost: %.0f] %s - %s" % [m["cost"], m["name"], m["desc"]]
		hbox.add_child(lbl2)
		var cast_btn = Button.new()
		cast_btn.text = "Cast"
		var mname = m["name"]
		cast_btn.pressed.connect(func():
			if dm.cast_miracle(_find_miracle_id(mname)):
				print("Cast: %s" % mname)
		)
		hbox.add_child(cast_btn)
		content.add_child(hbox)

	var locked = Label.new()
	locked.text = "\n--- Locked Miracles ---"
	content.add_child(locked)
	for _m in dm.get_locked_miracles():
		var lbl = Label.new()
		lbl.text = "[Rank %d] %s - %s" % [_m["unlock_rank"], _m["name"], _m["desc"]]
		content.add_child(lbl)

func _refresh_pantheon_content(panel: PanelContainer) -> void:
	if _refreshing_pantheon:
		return
	_refreshing_pantheon = true

	var content: VBoxContainer = panel.find_child("Content", true, false)
	for child in content.get_children():
		child.queue_free()

	var dm = _get_deity_manager()
	if not dm or dm.deity_class.is_empty():
		var lbl = Label.new()
		lbl.text = "[No deity chosen]"
		content.add_child(lbl)
		_refreshing_pantheon = false
		return

	# Header section
	var header_hbox = HBoxContainer.new()
	var active_label = Label.new()
	active_label.text = "Active Aspects: %d / %d" % [dm.active_aspects.size(), dm.max_aspects]
	header_hbox.add_child(active_label)
	header_hbox.add_child(_make_spacer())
	var sp_label = Label.new()
	sp_label.text = "Skill Points: %d" % dm.skill_points
	header_hbox.add_child(sp_label)
	content.add_child(header_hbox)

	content.add_child(_make_separator())

	# Aspect cards
	for aspect_id in dm.ASPECTS:
		var aspect_data: Dictionary = dm.ASPECTS[aspect_id]
		var card = PanelContainer.new()
		var card_vbox = VBoxContainer.new()

		# Name and domain
		var name_label = Label.new()
		name_label.text = aspect_data["name"]
		name_label.add_theme_font_size_override("font_size", 16)
		card_vbox.add_child(name_label)

		var domain_label = Label.new()
		domain_label.text = "Domain: %s" % aspect_data["domain"]
		domain_label.add_theme_color_override("font_color", Color.GOLD)
		card_vbox.add_child(domain_label)

		var desc_label = Label.new()
		desc_label.text = aspect_data["description"]
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		card_vbox.add_child(desc_label)

		# Status section
		if aspect_id in dm.active_aspects:
			# ACTIVE - show power allocation slider
			var active_status_label = Label.new()
			active_status_label.text = "Status: [ACTIVE]"
			active_status_label.add_theme_color_override("font_color", Color.GREEN)
			card_vbox.add_child(active_status_label)

			# Slider row
			var slider_hbox = HBoxContainer.new()
			var slider = HSlider.new()
			slider.min_value = 0.0
			slider.max_value = 1.0
			slider.step = 0.05
			slider.value = dm.aspect_power_allocation.get(aspect_id, 0.0)
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var pct_label = Label.new()
			pct_label.text = "%d%%" % int(slider.value * 100)
			pct_label.custom_minimum_size = Vector2(40, 0)

			var aid = aspect_id
			slider.value_changed.connect(func(val: float):
				val = snapped(val, 0.05)
				var others: Array[String] = []
				for a in dm.active_aspects:
					if a != aid:
						others.append(a)

				if others.size() > 0:
					var other_total: float = 0.0
					for o in others:
						other_total += dm.aspect_power_allocation.get(o, 0.0)

					var remaining: float = 1.0 - val
					if other_total > 0.0:
						for _o2 in others:
							var prop: float = dm.aspect_power_allocation.get(_o2, 0.0) / other_total
							dm.allocate_power(_o2, remaining * prop)
					else:
						var share: float = remaining / others.size()
						for _o3 in others:
							dm.allocate_power(_o3, share)

				dm.allocate_power(aid, val)
				_refresh_pantheon_content(panel)
			)

			slider_hbox.add_child(slider)
			slider_hbox.add_child(pct_label)
			card_vbox.add_child(slider_hbox)

			# Bonus summary
			var bonuses: Dictionary = aspect_data.get("passive_bonus", {})
			var bonus_text = ""
			for key in bonuses:
				var bval = bonuses[key]
				if bval is float:
					if bval >= 1.0:
						bonus_text += "%s: +%.0f%%  " % [key.capitalize(), (bval - 1.0) * 100]
					else:
						bonus_text += "%s: +%d%%  " % [key.capitalize(), int(bval * 100)]
				else:
					bonus_text += "%s: +%d  " % [key.capitalize(), bval]
			if bonus_text.length() > 0:
				var bonus_label = Label.new()
				bonus_label.text = "Bonus: %s" % bonus_text
				bonus_label.add_theme_color_override("font_color", Color.CYAN)
				card_vbox.add_child(bonus_label)

		elif dm.can_unlock_aspect(aspect_id):
			# AVAILABLE
			var avail_status_label = Label.new()
			avail_status_label.text = "Status: [AVAILABLE]"
			avail_status_label.add_theme_color_override("font_color", Color.YELLOW)
			card_vbox.add_child(avail_status_label)

			var unlock_hbox = HBoxContainer.new()
			unlock_hbox.add_child(_make_spacer())
			var unlock_btn = Button.new()
			unlock_btn.text = "Unlock %s" % aspect_data["name"]
			var unlock_aid = aspect_id
			unlock_btn.pressed.connect(func():
				if dm.unlock_aspect(unlock_aid):
					_refresh_pantheon_content(panel)
			)
			unlock_hbox.add_child(unlock_btn)
			card_vbox.add_child(unlock_hbox)

		else:
			# LOCKED - determine why
			var locked_status_label = Label.new()
			locked_status_label.text = "Status: [LOCKED]"
			locked_status_label.add_theme_color_override("font_color", Color.RED)
			card_vbox.add_child(locked_status_label)

			var req_text = ""
			if dm.rank < aspect_data["unlock_rank"]:
				req_text = "Requires Rank %d (current: %d)" % [aspect_data["unlock_rank"], dm.rank]
			else:
				var req_skill: String = aspect_data.get("unlock_skill_requirement", "")
				if req_skill != "" and req_skill not in dm.unlocked_skills:
					req_text = "Requires skill: %s" % req_skill.capitalize()
				elif dm.active_aspects.size() >= dm.max_aspects:
					req_text = "Max active aspects reached (%d)" % dm.max_aspects
				else:
					req_text = "Conflicts with active aspects"

			var req_label = Label.new()
			req_label.text = req_text
			req_label.add_theme_color_override("font_color", Color.GRAY)
			card_vbox.add_child(req_label)

		card.add_child(card_vbox)
		content.add_child(card)

	# Conflict warnings
	var conflicts = dm.check_aspect_conflicts()
	if conflicts.size() > 0:
		content.add_child(_make_separator())
		for c in conflicts:
			var a_name: String = dm.ASPECTS.get(c["aspect_a"], {}).get("name", c["aspect_a"])
			var b_name: String = dm.ASPECTS.get(c["aspect_b"], {}).get("name", c["aspect_b"])
			var warn = Label.new()
			warn.text = "âš  Conflict: %s conflicts with %s" % [a_name, b_name]
			warn.add_theme_color_override("font_color", Color.RED)
			content.add_child(warn)

	_refreshing_pantheon = false


func _refresh_culture_content(panel: PanelContainer) -> void:
	var content: VBoxContainer = panel.find_child("Content", true, false)
	for child in content.get_children():
		child.queue_free()

	var nat = ColonyData.get_player_nation()
	if nat.is_empty():
		var no_nation_lbl = Label.new()
		no_nation_lbl.text = "[No nation]"
		content.add_child(no_nation_lbl)
		return

	var dm = _get_deity_manager()
	if not dm or dm.deity_class.is_empty():
		var no_deity_lbl = Label.new()
		no_deity_lbl.text = "[No deity chosen]"
		content.add_child(no_deity_lbl)
		return

	# Header
	var header = Label.new()
	header.text = "Cultural Traits â€” %s" % nat.get("name", "Unknown")
	header.add_theme_font_size_override("font_size", 20)
	content.add_child(header)
	content.add_child(_make_separator())

	var nid = ColonyData.player_nation_id
	var culture: Dictionary = ColonyData.nation_culture.get(nid, {})

	if culture.is_empty():
		var no_trait_lbl = Label.new()
		no_trait_lbl.text = "No active cultural traits."
		content.add_child(no_trait_lbl)
	else:
		var active_header = Label.new()
		active_header.text = "Active Traits:"
		active_header.add_theme_font_size_override("font_size", 16)
		content.add_child(active_header)

		for trait_id in culture:
			var dominance: float = culture[trait_id]
			var td: Dictionary = ColonyData.CULTURAL_TRAITS.get(trait_id, {})
			if td.is_empty():
				continue

			var card = VBoxContainer.new()

			# Name and category
			var name_label = Label.new()
			name_label.text = "[b]%s[/b] (%s)" % [td.get("name", trait_id), td.get("category", "?")]
			name_label.bbcode_enabled = true
			name_label.add_theme_font_size_override("font_size", 15)
			card.add_child(name_label)

			# Description
			var desc_label = Label.new()
			desc_label.text = td.get("desc", "")
			card.add_child(desc_label)

			# Dominance bar
			var dom_hbox = HBoxContainer.new()
			var dom_label = Label.new()
			dom_label.text = "Dominance: "
			dom_hbox.add_child(dom_label)

			var bar_bg = PanelContainer.new()
			bar_bg.custom_minimum_size = Vector2(200, 20)
			var bg_style = StyleBoxFlat.new()
			bg_style.bg_color = Color(0.15, 0.15, 0.15)
			bar_bg.add_theme_stylebox_override("panel", bg_style)

			var fill = ColorRect.new()
			fill.color = _dominance_color(dominance)
			fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
			fill.set_anchor(SIDE_RIGHT, dominance)
			bar_bg.add_child(fill)

			var pct_label = Label.new()
			pct_label.text = " %.0f%%" % (dominance * 100)
			dom_hbox.add_child(bar_bg)
			dom_hbox.add_child(pct_label)
			card.add_child(dom_hbox)

			# Effects summary
			var effects_text = ""
			var effects: Dictionary = td.get("effects", {})
			for key in effects:
				var val: float = effects[key]
				var sign = "+" if val >= 1.0 else ""
				effects_text += "%s: %s%.0f%%  " % [key.capitalize(), sign, (val - 1.0) * 100]
			if not effects_text.is_empty():
				var eff_label = Label.new()
				eff_label.text = effects_text.strip_edges()
				card.add_child(eff_label)

			# Encourage button
			var encourage_hbox = HBoxContainer.new()
			var encourage_btn = Button.new()
			encourage_btn.text = "Encourage (5 power)"
			var tid = trait_id
			encourage_btn.pressed.connect(func():
				if dm.divine_power >= 5.0:
					dm.divine_power -= 5.0
					EventBus.divine_power_changed.emit(dm.divine_power, dm.max_divine_power)
					culture[tid] = min(1.0, culture[tid] + 0.05)
					ColonyData.nation_culture[nid] = culture
					_refresh_culture_content(panel)
			)
			encourage_hbox.add_child(encourage_btn)
			card.add_child(encourage_hbox)

			content.add_child(card)
			content.add_child(_make_separator())

	# All traits reference
	content.add_child(_make_separator())
	var all_header = Label.new()
	all_header.text = "All Cultural Traits:"
	all_header.add_theme_font_size_override("font_size", 16)
	content.add_child(all_header)

	for _trait_id in ColonyData.CULTURAL_TRAITS:
		var all_td: Dictionary = ColonyData.CULTURAL_TRAITS[_trait_id]
		var info = "[b]%s[/b] (%s) â€” %s" % [all_td["name"], all_td["category"], all_td["desc"]]
		var compats = all_td.get("compatible", [])
		var conflicts = all_td.get("conflicts", [])
		if not compats.is_empty():
			info += "\n  Compatible: %s" % ", ".join(compats)
		if not conflicts.is_empty():
			info += "\n  Conflicts: %s" % ", ".join(conflicts)
		var trait_label = RichTextLabel.new()
		trait_label.bbcode_enabled = true
		trait_label.fit_content = true
		trait_label.text = info
		content.add_child(trait_label)


func _refresh_history_content(panel: PanelContainer) -> void:
	var content: VBoxContainer = panel.find_child("Content", true, false)
	for child in content.get_children():
		child.queue_free()

	var history: Dictionary = ColonyData.world_history
	if history.is_empty():
		var lbl = Label.new()
		lbl.text = "No history generated yet."
		content.add_child(lbl)
		return

	# --- Tab bar ---
	var tab_hbox = HBoxContainer.new()
	var records_btn = Button.new()
	records_btn.text = "Records"
	records_btn.toggle_mode = true
	records_btn.button_pressed = true
	var lore_btn = Button.new()
	lore_btn.text = "Lore"
	lore_btn.toggle_mode = true

	var records_container = VBoxContainer.new()
	records_container.name = "RecordsTab"
	var lore_scroll = ScrollContainer.new()
	lore_scroll.name = "LoreTab"
	lore_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lore_scroll.hide()
	var lore_container = VBoxContainer.new()
	lore_container.name = "LoreContent"
	lore_scroll.add_child(lore_container)

	records_btn.pressed.connect(func():
		records_btn.button_pressed = true
		lore_btn.button_pressed = false
		records_container.show()
		lore_scroll.hide()
	)
	lore_btn.pressed.connect(func():
		lore_btn.button_pressed = true
		records_btn.button_pressed = false
		records_container.hide()
		lore_scroll.show()
	)

	tab_hbox.add_child(records_btn)
	tab_hbox.add_child(lore_btn)
	tab_hbox.add_child(_make_spacer())
	content.add_child(tab_hbox)
	content.add_child(_make_separator())

	content.add_child(records_container)
	content.add_child(lore_scroll)

	# Populate Records tab (existing dry lists)
	_populate_records_tab(records_container, history)

	# Populate Lore tab
	_populate_lore_tab(lore_container, history)


func _populate_records_tab(container: VBoxContainer, history: Dictionary) -> void:
	# Past Wars
	var wars_label = Label.new()
	wars_label.text = "[b]Past Wars[/b]"
	wars_label.add_theme_font_size_override("font_size", 16)
	container.add_child(wars_label)
	for war in history.get("past_wars", []):
		var label = Label.new()
		label.text = "  %s: %s vs %s â€” %s (%d years ago)" % [
			war["name"], war["aggressor_race"].capitalize(),
			war["defender_race"].capitalize(), war["outcome"].replace("_", " "),
			abs(war["year_offset"])
		]
		label.add_theme_color_override("font_color", Color("#ff6666"))
		container.add_child(label)

	container.add_child(_make_separator())

	# Migrations
	var mig_label = Label.new()
	mig_label.text = "[b]Great Migrations[/b]"
	mig_label.add_theme_font_size_override("font_size", 16)
	container.add_child(mig_label)
	for mig in history.get("migrations", []):
		var mig_lbl = Label.new()
		mig_lbl.text = "  %s moved from %s to %s (%d people, %d years ago)" % [
			mig["race"].capitalize(), mig["from_biome"], mig["to_biome"],
			mig["population_moved"], abs(mig["year_offset"])
		]
		container.add_child(mig_lbl)

	container.add_child(_make_separator())

	# Ancient Empires
	var emp_label = Label.new()
	emp_label.text = "[b]Ancient Empires[/b]"
	emp_label.add_theme_font_size_override("font_size", 16)
	container.add_child(emp_label)
	for empire in history.get("ancient_empires", []):
		var empire_lbl = Label.new()
		empire_lbl.text = "  %s â€” %s empire (collapsed: %s, %d years ago)" % [
			empire["name"], empire["dominant_race"].capitalize(),
			empire["collapse_reason"], abs(empire["year_offset"])
		]
		container.add_child(empire_lbl)

	container.add_child(_make_separator())

	# Trade Leagues
	var league_label = Label.new()
	league_label.text = "[b]Historical Trade Leagues[/b]"
	league_label.add_theme_font_size_override("font_size", 16)
	container.add_child(league_label)
	for league in history.get("trade_leagues", []):
		var league_lbl = Label.new()
		league_lbl.text = "  %s â€” founded by %s, %d members (%d years ago)" % [
			league["name"], league["founder_race"].capitalize(),
			league["member_count"], abs(league["year_offset"])
		]
		container.add_child(league_lbl)


func _populate_lore_tab(container: VBoxContainer, history: Dictionary) -> void:
	var paragraphs: Array[String] = _generate_lore_paragraphs(history)

	if paragraphs.is_empty():
		var empty_label = Label.new()
		empty_label.text = "The mists of time reveal little... Histories have yet to be written."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		empty_label.add_theme_color_override("font_color", Color("#888899"))
		container.add_child(empty_label)
		return

	for i in range(paragraphs.size()):
		var para = Label.new()
		para.text = paragraphs[i]
		para.autowrap_mode = TextServer.AUTOWRAP_WORD
		para.add_theme_font_size_override("font_size", 15)

		# Alternate colors for visual interest
		var colors = ["#e8d5a3", "#d5c8b5", "#c8d5d0", "#d5c0b8", "#c0c8d5"]
		para.add_theme_color_override("font_color", Color(colors[i % colors.size()]))
		container.add_child(para)

		if i < paragraphs.size() - 1:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 12)
			container.add_child(spacer)


func _generate_lore_paragraphs(history: Dictionary) -> Array[String]:
	var paragraphs: Array[String] = []

	# Collect all history entries into a pool
	var events: Array[Dictionary] = []

	for war in history.get("past_wars", []):
		events.append({"kind": "war", "data": war})

	for empire in history.get("ancient_empires", []):
		events.append({"kind": "empire", "data": empire})

	for mig in history.get("migrations", []):
		events.append({"kind": "migration", "data": mig})

	for league in history.get("trade_leagues", []):
		events.append({"kind": "league", "data": league})

	if events.is_empty():
		return paragraphs

	# Shuffle events randomly for varied narrative order
	events.shuffle()

	# Limit to 3-5 paragraphs
	var count = min(events.size(), randi_range(3, 5))
	for i in range(count):
		var ev = events[i]
		match ev["kind"]:
			"war":
				paragraphs.append(_narrate_war(ev["data"]))
			"empire":
				paragraphs.append(_narrate_empire(ev["data"]))
			"migration":
				paragraphs.append(_narrate_migration(ev["data"]))
			"league":
				paragraphs.append(_narrate_trade_league(ev["data"]))

	return paragraphs


func _narrate_war(war: Dictionary) -> String:
	var year = abs(war["year_offset"])
	var aggressor = _race_display_name(war["aggressor_race"])
	var defender = _race_display_name(war["defender_race"])
	var outcome = war["outcome"].replace("_", " ")
	var war_name = war["name"]

	# Rich narrative templates for wars
	var templates: Array[String] = [
		"In the year %d, the %s saw %s's armies clash with the forces of %s. The conflict ended in %s, forever altering the balance of power across the land." % [year, war_name, aggressor, defender, outcome],
		"The %s erupted in %d when %s warbands marched against %s strongholds. After seasons of bloodshed, the war concluded in %s â€” its scars still visible in the memories of both peoples." % [war_name, year, aggressor, defender, outcome],
		"Generations ago, in %d, the %s pitted %s conquerors against %s defenders. The %s that followed reshaped borders and forged legends that bards still sing of today." % [year, war_name, aggressor, defender, outcome],
		"Few remember the names of the fallen from the %s of %d, when %s and %s shed blood across the contested marches. The war's %s left a bitter peace that endured for decades." % [war_name, year, aggressor, defender, outcome],
		"The ancient %s raged in %d as %s expansion met %s resistance. In the end, the %s left neither side wholly victorious, but both forever changed." % [war_name, year, aggressor, defender, outcome],
	]

	return templates[randi() % templates.size()]


func _narrate_empire(empire: Dictionary) -> String:
	var name = empire["name"]
	var race = _race_display_name(empire["dominant_race"])
	var tiles = empire["peak_size_tiles"]
	var reason = _format_collapse_reason(empire["collapse_reason"])
	var year = abs(empire["year_offset"])

	var templates: Array[String] = [
		"The %s once stretched across %d tiles under %s rule â€” a golden age of power and prosperity. Its collapse came through %s, and now only ruins mark where its grandeur once stood." % [name, tiles, race, reason],
		"Long before the rise of the current kingdoms, the %s dominated the known world, commanding %d tiles of territory. But %s brought the empire low, scattering its people to the winds around the year %d." % [name, tiles, reason, year],
		"In the age of the %s, %s lords ruled over %d tiles from glittering capitals. When %s struck, the empire fractured into warring successor states whose ruins dot the eastern plains to this day." % [name, race, tiles, reason],
		"The %s was history's great colossus â€” %d tiles of %s dominion. But no empire is eternal: %s shattered its foundations, leaving behind only legends and scattered relics." % [name, tiles, race, reason],
		"Scholars still debate the fall of the %s, an empire of %d tiles that once united the %s peoples. What is known is that %s spelled its doom, and the world has never seen such unity since." % [name, tiles, race, reason],
	]

	return templates[randi() % templates.size()]


func _narrate_migration(mig: Dictionary) -> String:
	var race = _race_display_name(mig["race"])
	var pop = mig["population_moved"]
	var from_biome = mig["from_biome"]
	var to_biome = mig["to_biome"]
	var year = abs(mig["year_offset"])

	var templates: Array[String] = [
		"In the year %d, a great %s migration began as %d souls departed the %s, journeying toward the %s in search of new lands â€” a diaspora that would echo through the ages." % [year, race, pop, from_biome, to_biome],
		"The %s exodus of %d saw %d %s leave their ancestral %s behind. They arrived in the %s carrying little but their traditions, and those traditions took root and flourished." % [race, year, pop, race, from_biome, to_biome],
		"Around %d, %d %s packed their belongings and trekked from the %s to the %s, driven by dreams of fertile lands and safer horizons. Their descendants still tell the tale." % [year, pop, race, from_biome, to_biome],
		"Driven from the %s by forces now forgotten, %d %s undertook the long march to the %s. That migration seeded new settlements that would one day become great realms." % [from_biome, pop, race, to_biome],
		"Legends speak of the great %s migration of %d, when a tide of %d souls swept from the %s region into the %s, carrying language, crafts, and faith to untouched lands." % [race, year, pop, from_biome, to_biome],
	]

	return templates[randi() % templates.size()]


func _narrate_trade_league(league: Dictionary) -> String:
	var name = league["name"]
	var founder = _race_display_name(league["founder_race"])
	var members = league["member_count"]
	var year = abs(league["year_offset"])

	var templates: Array[String] = [
		"The %s was forged in %d by visionary %s merchants who bound together %d realms. Along its trade routes, not only goods but ideas and alliances flowed â€” a golden thread through history." % [name, year, founder, members],
		"Commerce united where armies could not: the %s, founded by %s traders in %d, linked %d nations in a pact of mutual prosperity that enriched all who joined." % [name, founder, year, members],
		"In %d, the %s arose from the ambitions of %s guilds, drawing %d trading partners into a web of commerce. Its caravans carried silk, spice, and the seeds of lasting peace." % [year, name, founder, members],
		"The %s stands as a monument to %s enterprise. From %d onward, its %d member realms traded freely, and for a time, the coin spoke louder than the sword." % [name, founder, year, members],
		"Before the age of standing armies, the %s â€” a %s-led compact of %d nations â€” proved that wealth, not war, could shape the destiny of peoples. Founded in %d, its influence outlasted empires." % [name, founder, members, year],
	]

	return templates[randi() % templates.size()]


func _race_display_name(race_id: String) -> String:
	var race_data = ColonyData.RACES.get(race_id, {})
	var name: String = race_data.get("name", race_id.capitalize())
	# Add regional flavor articles where appropriate
	var starts_with_vowel = "aeiou".contains(name[0].to_lower())
	if starts_with_vowel:
		return name  # "Elf armies" is fine
	return name  # "Human armies", "Dwarf holds" etc.


func _format_collapse_reason(reason: String) -> String:
	match reason:
		"civil_war": return "a devastating civil war"
		"plague": return "a mysterious plague"
		"invasion": return "a foreign invasion"
		"economic_collapse": return "economic collapse"
		"environmental": return "environmental catastrophe"
		"unknown": return "causes lost to time"
	return reason.replace("_", " ")


func _refresh_government_content(panel: PanelContainer) -> void:
	var content: VBoxContainer = panel.find_child("Content", true, false)
	for child in content.get_children():
		child.queue_free()

	var nat = ColonyData.get_player_nation()
	if nat.is_empty():
		var no_nat_lbl = Label.new()
		no_nat_lbl.text = "No nation data"
		content.add_child(no_nat_lbl)
		return

	var gov: String = nat.get("government", "kingdom")
	var gov_data = ColonyData.GOVERNMENT_TYPES.get(gov, {})
	if gov_data.is_empty():
		var no_gov_lbl = Label.new()
		no_gov_lbl.text = "Government: %s" % gov
		content.add_child(no_gov_lbl)
		return

	# Title
	var title = Label.new()
	title.text = "[b]%s[/b]" % gov_data.get("name", gov)
	title.add_theme_font_size_override("font_size", 20)
	content.add_child(title)

	var desc = Label.new()
	desc.text = gov_data.get("desc", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(desc)

	content.add_child(_make_separator())

	# Details
	var cat_label = Label.new()
	cat_label.text = "Category: %s" % gov_data.get("category", "?").capitalize()
	content.add_child(cat_label)
	var suc_label = Label.new()
	suc_label.text = "Succession: %s" % gov_data.get("succession_type", "?").capitalize().replace("_", " ")
	content.add_child(suc_label)

	var stability: float = gov_data.get("stability_base", 50.0)
	var stab_label = Label.new()
	stab_label.text = "Stability Base: %.0f" % stability
	content.add_child(stab_label)

	content.add_child(_make_separator())

	# Bonuses
	var bonus_label = Label.new()
	bonus_label.text = "[b]Bonuses:[/b]"
	content.add_child(bonus_label)
	var bonuses: Dictionary = gov_data.get("bonuses", {})
	if bonuses.is_empty():
		var none_label = Label.new()
		none_label.text = "  None"
		content.add_child(none_label)
	else:
		for key in bonuses:
			var val: float = bonuses[key]
			var pct = abs((val - 1.0) * 100)
			var sign = "+" if val > 1.0 else "-" if val < 1.0 else ""
			var b_label = Label.new()
			b_label.text = "  %s: %s%.0f%%" % [key.capitalize(), sign, pct]
			content.add_child(b_label)

	content.add_child(_make_separator())

	# Diplomatic bias
	var bias_header = Label.new()
	bias_header.text = "[b]Diplomatic Affinity:[/b]"
	content.add_child(bias_header)
	var bias: Dictionary = gov_data.get("diplomatic_bias", {})
	for other_gov in bias:
		var bias_val: float = bias[other_gov]
		var other_name = ColonyData.GOVERNMENT_TYPES.get(other_gov, {}).get("name", other_gov)
		var label = Label.new()
		if bias_val > 0:
			label.text = "  Likes %s (+%.0f)" % [other_name, bias_val]
		else:
			label.text = "  Dislikes %s (%.0f)" % [other_name, bias_val]
		content.add_child(label)

	content.add_child(_make_separator())

	# Policy affinities
	var aff: Dictionary = gov_data.get("policy_affinities", {})
	if not aff.is_empty():
		var pref_header = Label.new()
		pref_header.text = "[b]Policy Preferences:[/b]"
		content.add_child(pref_header)
		var preferred: Array = aff.get("preferred", [])
		var avoided: Array = aff.get("avoided", [])
		if not preferred.is_empty():
			var pref_label = Label.new()
			pref_label.text = "  Prefers: %s" % ", ".join(preferred)
			content.add_child(pref_label)
		if not avoided.is_empty():
			var avoid_label = Label.new()
			avoid_label.text = "  Avoids: %s" % ", ".join(avoided)
			content.add_child(avoid_label)

	# --- Reform Government Section ---
	content.add_child(_make_separator())
	var reform_header = Label.new()
	reform_header.text = "=== Reform Government ==="
	reform_header.add_theme_font_size_override("font_size", 18)
	content.add_child(reform_header)

	# Cooldown check
	var cooldown_tick: int = nat.get("government_reform_cooldown_tick", 0)
	var on_cooldown: bool = _current_game_tick < cooldown_tick
	var remaining_ticks: int = max(0, cooldown_tick - _current_game_tick)

	if on_cooldown:
		var cooldown_label = Label.new()
		cooldown_label.text = "Reform on cooldown â€” %d ticks remaining" % remaining_ticks
		cooldown_label.add_theme_color_override("font_color", Color.ORANGE)
		content.add_child(cooldown_label)

	var pop = nat.get("population", 0)
	var gold_cost = int(pop * 0.5)
	var cost_label = Label.new()
	cost_label.text = "Transition cost: %d gold (stability penalty applies)" % gold_cost
	cost_label.add_theme_color_override("font_color", Color.LIGHT_CORAL)
	content.add_child(cost_label)

	content.add_child(_make_separator())

	# List all government types
	for gov_id in ColonyData.GOVERNMENT_TYPES:
		var gdata: Dictionary = ColonyData.GOVERNMENT_TYPES[gov_id]
		var is_current = gov_id == gov

		var card = PanelContainer.new()
		var card_vbox = VBoxContainer.new()

		# Name + category
		var name_hbox = HBoxContainer.new()
		var name_label = Label.new()
		if is_current:
			name_label.text = "[b][color=yellow]%s[/color][/b] [i](current)[/i]" % gdata.get("name", gov_id)
		else:
			name_label.text = "[b]%s[/b]" % gdata.get("name", gov_id)
		name_label.bbcode_enabled = true
		name_label.add_theme_font_size_override("font_size", 16)
		name_hbox.add_child(name_label)
		name_hbox.add_child(_make_spacer())

		var cat_label2 = Label.new()
		cat_label2.text = "Category: %s" % gdata.get("category", "?").capitalize()
		cat_label2.add_theme_color_override("font_color", Color.LIGHT_SLATE_GRAY)
		name_hbox.add_child(cat_label2)
		card_vbox.add_child(name_hbox)

		# Description
		var desc2 = Label.new()
		desc2.text = gdata.get("desc", "")
		desc2.autowrap_mode = TextServer.AUTOWRAP_WORD
		card_vbox.add_child(desc2)

		# Succession
		var suc_label2 = Label.new()
		suc_label2.text = "Succession: %s | Stability Base: %.0f" % [
			gdata.get("succession_type", "?").capitalize().replace("_", " "),
			gdata.get("stability_base", 50.0)
		]
		card_vbox.add_child(suc_label2)

		# Bonuses
		var g_bonuses: Dictionary = gdata.get("bonuses", {})
		if not g_bonuses.is_empty():
			var bonus_parts: PackedStringArray = []
			for _key in g_bonuses:
				var g_val: float = g_bonuses[_key]
				var g_pct = abs((g_val - 1.0) * 100)
				var g_sign = "+" if g_val > 1.0 else "-" if g_val < 1.0 else ""
				bonus_parts.append("%s: %s%.0f%%" % [_key.capitalize(), g_sign, g_pct])
			var bonus_label2 = Label.new()
			bonus_label2.text = "Bonuses: %s" % ", ".join(bonus_parts)
			bonus_label2.add_theme_color_override("font_color", Color.CYAN)
			card_vbox.add_child(bonus_label2)

		# Diplomatic bias
		var g_bias: Dictionary = gdata.get("diplomatic_bias", {})
		if not g_bias.is_empty():
			var bias_parts: PackedStringArray = []
			for _other_gov in g_bias:
				var bval: float = g_bias[_other_gov]
				var g_other_name = ColonyData.GOVERNMENT_TYPES.get(_other_gov, {}).get("name", _other_gov)
				if bval > 0:
					bias_parts.append("Likes %s (+%.0f)" % [g_other_name, bval])
				else:
					bias_parts.append("Dislikes %s (%.0f)" % [g_other_name, bval])
			var bias_label2 = Label.new()
			bias_label2.text = "Diplomatic: %s" % ", ".join(bias_parts)
			bias_label2.add_theme_color_override("font_color", Color.LIGHT_SKY_BLUE)
			card_vbox.add_child(bias_label2)

		# Reform button row
		var btn_hbox = HBoxContainer.new()
		btn_hbox.add_child(_make_spacer())

		if is_current:
			var current_label = Label.new()
			current_label.text = "[CURRENT]"
			current_label.add_theme_color_override("font_color", Color.YELLOW)
			btn_hbox.add_child(current_label)
		elif on_cooldown:
			var cd_label2 = Label.new()
			cd_label2.text = "Cooldown: %d ticks" % remaining_ticks
			cd_label2.add_theme_color_override("font_color", Color.ORANGE)
			btn_hbox.add_child(cd_label2)
		else:
			var has_gold = nat.get("resources", {}).get("gold", 0) >= gold_cost
			var reform_btn = Button.new()
			if has_gold:
				reform_btn.text = "Reform â†’ %s" % gdata.get("name", gov_id)
			else:
				reform_btn.text = "Reform â†’ %s (need %d gold)" % [gdata.get("name", gov_id), gold_cost]
				reform_btn.disabled = true

			var target_gov = gov_id
			reform_btn.pressed.connect(func():
				var nat_ref = ColonyData.get_player_nation()
				if nat_ref.is_empty():
					return
				var current_gold = nat_ref.get("resources", {}).get("gold", 0)
				var cost = int(nat_ref.get("population", 0) * 0.5)
				if current_gold >= cost and _current_game_tick >= nat_ref.get("government_reform_cooldown_tick", 0):
					nat_ref["resources"]["gold"] = current_gold - cost
					nat_ref["government"] = target_gov
					nat_ref["government_reform_cooldown_tick"] = _current_game_tick + 240
					EventBus.resources_updated.emit(nat_ref["id"], nat_ref["resources"])
					_refresh_government_content(panel)
			)
			btn_hbox.add_child(reform_btn)

		card_vbox.add_child(btn_hbox)
		card.add_child(card_vbox)
		content.add_child(card)
		content.add_child(_make_separator())

func _refresh_factions_content(panel: PanelContainer) -> void:
	var content: VBoxContainer = panel.find_child("Content", true, false)
	for child in content.get_children():
		child.queue_free()

	var fm = _get_faction_manager()
	if not fm:
		var no_faction_lbl = Label.new()
		no_faction_lbl.text = "[Faction system not available]"
		content.add_child(no_faction_lbl)
		return

	var factions = ColonyData.active_factions
	if factions.size() == 0:
		var no_active_lbl = Label.new()
		no_active_lbl.text = "No active factions in the world."
		content.add_child(no_active_lbl)
		return

	for f in factions:
		var faction_data = ColonyData.FACTIONS.get(f["type"], {})
		var fname = faction_data.get("name", f["type"].capitalize())
		var threat = faction_data.get("threat_level", 1)

		var card = VBoxContainer.new()

		# Faction header
		var header = HBoxContainer.new()
		var name_label = Label.new()
		name_label.text = "[b]%s[/b]  Str: %d  Tile: (%d, %d)  Threat: %d" % [fname, f["strength"], f["tile_x"], f["tile_y"], threat]
		name_label.bbcode_enabled = true
		header.add_child(name_label)
		card.add_child(header)

		# Interaction buttons
		var interactions = faction_data.get("interactions", [])
		if interactions.size() > 0:
			var actions_hbox = HBoxContainer.new()
			var fid = f["id"]
			for interaction in interactions:
				var btn = Button.new()
				btn.text = interaction.capitalize()
				btn.tooltip_text = _faction_interaction_desc(interaction)
				var inter = interaction
				btn.pressed.connect(func():
					var result = fm.interact_with_faction(ColonyData.player_nation_id, fid, inter)
					if result.get("success", false):
						_show_toast("âœ… %s: %s" % [inter.capitalize(), result.get("outcome", "success")])
						print("[Faction] %s on %s succeeded: %s" % [inter, fname, result.get("outcome", "?")])
					else:
						_show_toast("âŒ %s: %s" % [inter.capitalize(), result.get("reason", "failed")])
					_refresh_factions_content(panel)
				)
				actions_hbox.add_child(btn)
			card.add_child(actions_hbox)

		card.add_child(_make_separator())
		content.add_child(card)


func _refresh_factions_if_visible() -> void:
	var panel: PanelContainer = _panels.get("faction_panel")
	if panel and panel.visible:
		_refresh_factions_content(panel)

func _faction_interaction_desc(interaction: String) -> String:
	match interaction:
		"fight": return "Attack the faction with military force. May gain drops on victory."
		"integrate": return "Peacefully integrate the faction into your population."
		"bribe": return "Pay gold to convince the faction to disperse."
		"enslave": return "Enslave the faction (wild tribes only). Requires 2x military strength."
		"trade": return "Attempt to trade with the faction."
	return "Interact with this faction."

# --- Tech Tree ---

func _refresh_tech_content(panel: PanelContainer) -> void:
	var content: VBoxContainer = panel.find_child("Content", true, false)
	for child in content.get_children():
		child.queue_free()

	# Scroll wrapper for large content
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inner = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	content.add_child(scroll)

	var tm = _find_tech_manager()
	if not tm:
		var no_tech_lbl = Label.new()
		no_tech_lbl.text = "[Tech system unavailable]"
		inner.add_child(no_tech_lbl)
		return

	var nat = ColonyData.get_player_nation()
	if nat.is_empty():
		var no_nat_lbl = Label.new()
		no_nat_lbl.text = "[No nation]"
		inner.add_child(no_nat_lbl)
		return

	var nid = ColonyData.player_nation_id
	var era_key: String = tm.current_era.get(nid, "stone")
	var rp: float = tm.research_points.get(nid, 0.0)
	var unlocked_array: Array = tm.unlocked_techs.get(nid, [])
	var unlocked_count = unlocked_array.size()
	var races = ColonyData.RACES
	var race_id: String = nat.get("primary_race", "human")
	var affinity: float = TechData.RACE_TECH_AFFINITY.get(race_id, 1.0)

	# === Header ===
	var header_hbox = HBoxContainer.new()
	var era_label = Label.new()
	era_label.text = "Current Era: %s" % era_key.capitalize()
	era_label.add_theme_font_size_override("font_size", 18)
	header_hbox.add_child(era_label)
	header_hbox.add_child(_make_spacer())
	var rp_label = Label.new()
	rp_label.text = "Research Points: %.1f" % rp
	rp_label.add_theme_font_size_override("font_size", 16)
	rp_label.tooltip_text = "Race affinity: %.1fx" % affinity
	header_hbox.add_child(rp_label)
	inner.add_child(header_hbox)

	# === Era Progress ===
	var eras = TechData.ERAS
	var era_idx = 0
	for i in range(eras.size()):
		if eras[i] == era_key:
			era_idx = i
			break

	var next_threshold = 0
	var next_label = ""
	if era_idx < eras.size() - 1:
		next_threshold = TechData.ERA_THRESHOLDS.get(eras[era_idx + 1], 999)
		next_label = eras[era_idx + 1].capitalize()
	else:
		next_threshold = max(unlocked_count, TechData.ERA_THRESHOLDS.get(era_key, 1))
		next_label = "MAX"

	var progress_hbox = HBoxContainer.new()
	var progress_label = Label.new()
	progress_label.text = "Progress: %d / %d toward %s" % [unlocked_count, next_threshold, next_label]
	progress_hbox.add_child(progress_label)

	var bar_bg = PanelContainer.new()
	bar_bg.custom_minimum_size = Vector2(200, 20)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.15)
	bar_bg.add_theme_stylebox_override("panel", bg_style)

	var fill = ColorRect.new()
	var ratio = float(unlocked_count) / float(next_threshold)
	fill.color = Color(0.2, 0.6, 1.0)
	fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fill.set_anchor(SIDE_RIGHT, min(ratio, 1.0))
	bar_bg.add_child(fill)
	progress_hbox.add_child(bar_bg)
	inner.add_child(progress_hbox)

	inner.add_child(_make_separator())

	# === Tech Tree ===
	for era in eras:
		var era_techs = TechData.TECH_TREES.get(era, [])
		if era_techs.is_empty():
			continue

		var era_unlocked_flag = unlocked_count >= TechData.ERA_THRESHOLDS.get(era, 999)

		var era_header = Label.new()
		if era_unlocked_flag:
			era_header.text = "â•â•â• %s â•â•â•" % era.capitalize()
		else:
			era_header.text = "â•â•â• %s (LOCKED) â•â•â•" % era.capitalize()
			era_header.add_theme_color_override("font_color", Color.GRAY)
		era_header.add_theme_font_size_override("font_size", 15)
		inner.add_child(era_header)

		if not era_unlocked_flag:
			var req_label = Label.new()
			req_label.text = "  Requires %d techs unlocked" % TechData.ERA_THRESHOLDS.get(era, 0)
			req_label.add_theme_color_override("font_color", Color.DIM_GRAY)
			inner.add_child(req_label)
			continue

		for tech in era_techs:
			var tid = tech["id"]
			var is_unlocked = tid in unlocked_array
			var is_unlockable = tm.can_unlock_tech(nid, tid)

			var row = HBoxContainer.new()
			row.custom_minimum_size = Vector2(0, 28)

			# Icon or text status marker
			var status = "[x]" if is_unlocked else "[+]" if is_unlockable else "[ ]"
			var icon_path = "res://assets/tech/%s.png" % tid
			var icon_loaded = false
			if ResourceLoader.exists(icon_path):
				var icon_tex = load(icon_path) as Texture2D
				if icon_tex:
					var icon_rect = TextureRect.new()
					icon_rect.texture = icon_tex
					icon_rect.custom_minimum_size = Vector2(16, 16)
					icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					row.add_child(icon_rect)
					icon_loaded = true

			var name_label = Label.new()
			if icon_loaded:
				name_label.text = tech["name"]
			else:
				name_label.text = "%s %s" % [status, tech["name"]]
			name_label.custom_minimum_size = Vector2(160, 0)

			if is_unlocked:
				name_label.add_theme_color_override("font_color", Color.GREEN)
			elif is_unlockable:
				name_label.add_theme_color_override("font_color", Color.YELLOW)
			else:
				name_label.add_theme_color_override("font_color", Color.GRAY)
			row.add_child(name_label)

			# Description + effects
			var effects_text = ""
			for key in tech:
				if key.begins_with("unlocks_"):
					var ename = key.trim_prefix("unlocks_").capitalize()
					var val = tech[key]
					if val is float:
						effects_text += "%s +%.0f%%  " % [ename, val * 100]
					else:
						effects_text += "%s +%s  " % [ename, str(val)]

			var desc_label = Label.new()
			var full_desc = tech["desc"]
			if not effects_text.is_empty():
				full_desc += "  |  %s" % effects_text.strip_edges()
			desc_label.text = full_desc
			desc_label.custom_minimum_size = Vector2(340, 0)
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			row.add_child(desc_label)

			# Prerequisites tooltip
			var prereqs: Array = tech.get("requires", [])
			if not prereqs.is_empty():
				var prereq_names = ""
				for req in prereqs:
					var rtech = TechData.get_tech(req)
					prereq_names += rtech.get("name", req) + ", "
				name_label.tooltip_text = "Requires: %s" % prereq_names.trim_suffix(", ")

			# Cost
			var cost_label = Label.new()
			cost_label.text = "Cost: %d" % tech["cost"]
			cost_label.custom_minimum_size = Vector2(70, 0)
			cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			if not is_unlocked and rp < tech["cost"]:
				cost_label.add_theme_color_override("font_color", Color.RED)
			row.add_child(cost_label)

			# Action
			if is_unlocked:
				var done = Label.new()
				done.text = "UNLOCKED"
				done.add_theme_color_override("font_color", Color.GREEN)
				row.add_child(done)
			elif is_unlockable:
				var unlock_btn = Button.new()
				unlock_btn.text = "Unlock"
				var btn_nid = nid
				var btn_tid = tid
				unlock_btn.pressed.connect(func():
					tm.unlock_tech(btn_nid, btn_tid)
					_refresh_tech_content(panel)
				)
				row.add_child(unlock_btn)

			inner.add_child(row)

	# === Summary ===
	inner.add_child(_make_separator())
	var total_techs = 0
	for e in TechData.TECH_TREES:
		total_techs += TechData.TECH_TREES[e].size()
	var summary_label = Label.new()
	summary_label.text = "Total Techs Unlocked: %d / %d" % [unlocked_count, total_techs]
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(summary_label)

func _refresh_tech_if_visible() -> void:
	var panel: PanelContainer = _panels.get("tech_panel")
	if panel and panel.visible:
		_refresh_tech_content(panel)

# --- Notification Log ---

func _refresh_log_content(panel: PanelContainer) -> void:
	var content: VBoxContainer = panel.find_child("Content", true, false)
	for child in content.get_children():
		child.queue_free()

	var log_entries: Array[Dictionary] = ColonyData.notification_log
	if log_entries.is_empty():
		var lbl = Label.new()
		lbl.text = "No events recorded yet."
		content.add_child(lbl)
		return

	# Filter buttons
	var filter_hbox = HBoxContainer.new()
	var categories = [
		{"name": "All", "key": ""},
		{"name": "War", "key": "war"},
		{"name": "Diplomacy", "key": "diplomacy"},
		{"name": "Building", "key": "building"},
		{"name": "Deity", "key": "deity"},
		{"name": "Events", "key": "event"},
	]
	for cat in categories:
		var btn = Button.new()
		btn.text = cat["name"]
		btn.toggle_mode = true
		btn.button_pressed = (_log_filter == cat["key"])
		var cat_key: String = cat["key"]
		btn.pressed.connect(func():
			_log_filter = cat_key
			_refresh_log_content(panel)
		)
		filter_hbox.add_child(btn)
	content.add_child(filter_hbox)
	content.add_child(_make_separator())

	# Scrollable log list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var category_colors = {
		"war": "#ff6666",
		"diplomacy": "#66aaff",
		"building": "#88dd88",
		"deity": "#ffcc44",
		"event": "#cc88ff",
		"general": "#aaaaaa",
	}

	# Iterate forward â€” chronicle entries are push_front (newest at index 0)
	for i in range(log_entries.size()):
		var entry = log_entries[i]
		var _cat: String = entry.get("category", "general")

		if _log_filter != "" and _cat != _log_filter:
			continue

		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Tick timestamp
		var tick_label = Label.new()
		tick_label.text = "[T%d]" % entry.get("tick", 0)
		tick_label.add_theme_color_override("font_color", Color("#666688"))
		tick_label.custom_minimum_size = Vector2(60, 0)
		hbox.add_child(tick_label)

		# Category badge
		var cat_label = Label.new()
		cat_label.text = "[" + _cat.capitalize() + "]"
		var cat_color: Color = Color(category_colors.get(_cat, "#aaaaaa"))
		cat_label.add_theme_color_override("font_color", cat_color)
		cat_label.custom_minimum_size = Vector2(90, 0)
		hbox.add_child(cat_label)

		# Entry text
		var text_label = Label.new()
		text_label.text = entry.get("text", "")
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(text_label)

		list.add_child(hbox)

	content.add_child(scroll)


# --- Utilities ---

func _load_ui_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _make_textured_panel_style(path: String, fallback_color: Color, texture_margin: int = 16, content_margin: int = 10) -> StyleBox:
	var tex = _load_ui_texture(path)
	if tex:
		var style = StyleBoxTexture.new()
		style.texture = tex
		style.texture_margin_left = texture_margin
		style.texture_margin_right = texture_margin
		style.texture_margin_top = texture_margin
		style.texture_margin_bottom = texture_margin
		style.content_margin_left = content_margin
		style.content_margin_right = content_margin
		style.content_margin_top = content_margin
		style.content_margin_bottom = content_margin
		return style

	var flat = StyleBoxFlat.new()
	flat.bg_color = fallback_color
	flat.border_color = Color(0.65, 0.52, 0.22, 0.85)
	flat.border_width_left = 1
	flat.border_width_right = 1
	flat.border_width_top = 1
	flat.border_width_bottom = 2
	flat.corner_radius_top_left = 4
	flat.corner_radius_top_right = 4
	flat.corner_radius_bottom_left = 4
	flat.corner_radius_bottom_right = 4
	flat.content_margin_left = content_margin
	flat.content_margin_right = content_margin
	flat.content_margin_top = content_margin
	flat.content_margin_bottom = content_margin
	return flat


func _make_margin_container(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _make_section_header(text: String) -> Label:
	var label = Label.new()
	label.text = text.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("#d8b458"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _make_spacer() -> Control:
	var s = Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s

func _make_separator() -> HSeparator:
	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color("#ffd700").darkened(0.3))
	sep.mouse_entered.connect(func():
		sep.add_theme_color_override("color", Color("#ffd700"))
	)
	sep.mouse_exited.connect(func():
		sep.remove_theme_color_override("color")
		sep.add_theme_color_override("color", Color("#ffd700").darkened(0.3))
	)
	return sep

func _find_policy_id(name: String) -> String:
	var pm = _get_policy_manager()
	if not pm: return ""
	for id in pm.all_policies:
		if pm.all_policies[id]["name"] == name:
			return id
	return ""

func _find_miracle_id(name: String) -> String:
	var dm = _get_deity_manager()
	if not dm:
		print("[GameUI] _create_class_selection_screen: dm is null! returning early!")
		return ""
	for id in dm.all_miracles:
		if dm.all_miracles[id]["name"] == name:
			return id
	return ""

func _get_relation(other_id: int) -> float:
	if ColonyData.player_nation_id >= ColonyData.diplomacy_matrix.size(): return 50.0
	if other_id >= ColonyData.diplomacy_matrix[ColonyData.player_nation_id].size(): return 50.0
	return ColonyData.diplomacy_matrix[ColonyData.player_nation_id][other_id]

func _relation_label(val: float) -> String:
	if val < 10: return "Hostile"
	if val < 30: return "Cold"
	if val < 70: return "Neutral"
	if val < 90: return "Friendly"
	return "Allied"

func _relation_color(val: float) -> String:
	if val < 10: return "#ff4444"
	if val < 30: return "#ff8844"
	if val < 70: return "#aaaaaa"
	if val < 90: return "#44aa44"
	return "#44aaff"

func _rank_name(rank: int) -> String:
	match rank:
		1: return "Local Spirit"
		2: return "Minor Deity"
		3: return "Regional Deity"
		4: return "Major Deity"
		5: return "Supreme Deity"
	return "Unknown"

func _dominance_color(dominance: float) -> Color:
	if dominance > 0.7:
		return Color(0.2, 0.8, 0.2)  # green
	elif dominance > 0.3:
		return Color(0.8, 0.8, 0.2)  # yellow
	return Color(0.8, 0.3, 0.3, 0.7)  # red faded

func _get_time_manager() -> Node:
	var sys = _find_systems_node()
	if sys: return sys.get_node_or_null("TimeManager")
	return null

func _get_deity_manager() -> Node:
	var sys = _find_systems_node()
	if sys: return sys.get_node_or_null("DeityManager")
	return null

func _get_event_manager() -> Node:
	var sys = _find_systems_node()
	if sys: return sys.get_node_or_null("EventManager")
	return null

func _get_policy_manager() -> Node:
	var sys = _find_systems_node()
	if sys: return sys.get_node_or_null("PolicyManager")
	return null

func _get_influence_manager() -> Node:
	var sys = _find_systems_node()
	if sys: return sys.get_node_or_null("InfluenceManager")
	return null

func _get_prophet_manager() -> Node:
	var sys = _find_systems_node()
	if sys: return sys.get_node_or_null("ProphetManager")
	return null

func _get_diplomacy_manager() -> Node:
	var sys = _find_systems_node()
	if sys: return sys.get_node_or_null("DiplomacyManager")
	return null

func _get_culture_manager() -> Node:
	var sys = _find_systems_node()
	if sys: return sys.get_node_or_null("CultureManager")
	return null

func _get_faction_manager() -> Node:
	var sys = _find_systems_node()
	if sys: return sys.get_node_or_null("FactionManager")
	return null

func _get_resource_manager() -> Node:
	var sys = _find_systems_node()
	if sys: return sys.get_node_or_null("ResourceManager")
	return null

func _get_building_manager() -> Node:
	var sys = _find_systems_node()
	if sys: return sys.get_node_or_null("BuildingManager")
	return null

func _find_tech_manager() -> Node:
	var sys = _find_systems_node()
	if sys: return sys.get_node_or_null("TechManager")
	return null

func _get_character(char_id: int) -> Dictionary:
	for c in ColonyData.characters:
		if c["id"] == char_id:
			return c
	return {}



func _find_systems_node() -> Node:
	var root = _scene_cache
	if not root and is_inside_tree():
		root = get_tree().current_scene
		if not root:
			root = get_parent()
	if root: return root.get_node_or_null("Systems")
	return null

# --- Toast helpers ---

func _nation_name(nid: int) -> String:
	var nat = ColonyData.get_nation(nid)
	return nat.get("name", "Nation %d" % nid) if not nat.is_empty() else "Nation %d" % nid

func _aspect_name(aid: String) -> String:
	var dm = _get_deity_manager()
	if dm: return dm.ASPECTS.get(aid, {}).get("name", aid)
	return aid

func _miracle_name(mid: String) -> String:
	var dm = _get_deity_manager()
	if dm and dm.all_miracles.has(mid):
		return dm.all_miracles[mid].get("name", mid)
	return mid.capitalize()

func _building_name(bid: String) -> String:
	return ColonyData.BUILDINGS.get(bid, {}).get("name", bid.capitalize())

func _apply_dark_theme() -> void:
	var theme = Theme.new()
	
	var title_font = load("res://assets/fonts/title_font.ttf") as Font
	var body_font = load("res://assets/fonts/body_font.ttf") as Font
	
	if body_font:
		theme.default_font = body_font
		theme.default_font_size = 14
	
	if title_font:
		theme.set_font("font", "HeaderLarge", title_font)
		theme.set_font_size("font_size", "HeaderLarge", 28)
		
	var wood_tex = _load_ui_texture(UI_WOOD_PANEL_PATH)

	var panel_style = StyleBoxTexture.new()
	if wood_tex:
		panel_style.texture = wood_tex
		panel_style.texture_margin_left = 16
		panel_style.texture_margin_right = 16
		panel_style.texture_margin_top = 16
		panel_style.texture_margin_bottom = 16
	else:
		panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.1, 0.05, 0.05, 0.95)
		panel_style.content_margin_left = 16
		panel_style.content_margin_right = 16
		panel_style.content_margin_top = 16
		panel_style.content_margin_bottom = 16

	theme.set_stylebox("panel", "PanelContainer", panel_style)
	theme.set_stylebox("panel", "Panel", panel_style)
	# Premium Button style
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.2, 0.15, 0.1, 0.95)
	btn_normal.border_color = Color(0.6, 0.5, 0.2, 0.8)
	btn_normal.border_width_left = 1; btn_normal.border_width_right = 1
	btn_normal.border_width_top = 1; btn_normal.border_width_bottom = 2
	btn_normal.corner_radius_top_left = 2; btn_normal.corner_radius_top_right = 2
	btn_normal.corner_radius_bottom_left = 2; btn_normal.corner_radius_bottom_right = 2
	
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.15, 0.15, 0.25, 0.95)
	btn_hover.border_color = Color(0.9, 0.8, 0.3, 0.9) # Glow gold on hover
	btn_hover.shadow_color = Color(0.9, 0.8, 0.3, 0.2)
	btn_hover.shadow_size = 4
	
	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	btn_pressed.border_color = Color(0.7, 0.6, 0.2, 0.9)
	btn_pressed.border_width_top = 2; btn_pressed.border_width_bottom = 1 # pressed down effect

	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("normal", "OptionButton", btn_normal)
	theme.set_stylebox("hover", "OptionButton", btn_hover)
	theme.set_stylebox("pressed", "OptionButton", btn_pressed)

	# Focus style — gold border highlight for keyboard navigation
	var focus_style = StyleBoxFlat.new()
	focus_style.bg_color = Color("#3a3a1a")
	focus_style.border_color = Color("#ffd700")
	focus_style.border_width_left = 2; focus_style.border_width_right = 2
	focus_style.border_width_top = 2; focus_style.border_width_bottom = 2
	theme.set_stylebox("focus", "Button", focus_style)

	# Font colors - cleaner off-white and bright gold
	theme.set_color("font_color", "Button", Color(0.9, 0.9, 0.92))
	theme.set_color("font_hover_color", "Button", Color(1.0, 0.9, 0.5))
	theme.set_color("font_pressed_color", "Button", Color(0.8, 0.7, 0.3))
	theme.set_color("font_color", "OptionButton", Color(0.9, 0.9, 0.92))
	theme.set_color("font_hover_color", "OptionButton", Color(1.0, 0.9, 0.5))
	theme.set_color("font_pressed_color", "OptionButton", Color(0.8, 0.7, 0.3))

	# Label defaults
	theme.set_color("font_color", "Label", Color(0.92, 0.92, 0.95))
	theme.set_color("font_color", "RichTextLabel", Color(0.92, 0.92, 0.95))
	theme.set_color("default_color", "RichTextLabel", Color(0.92, 0.92, 0.95))

	# Premium Progress bar
	var progress_bg = StyleBoxFlat.new()
	progress_bg.bg_color = Color(0.05, 0.05, 0.08, 0.8)
	progress_bg.border_width_left = 1; progress_bg.border_width_right = 1
	progress_bg.border_width_top = 1; progress_bg.border_width_bottom = 1
	progress_bg.border_color = Color(0.2, 0.2, 0.3, 0.8)
	progress_bg.corner_radius_top_left = 4; progress_bg.corner_radius_top_right = 4
	progress_bg.corner_radius_bottom_left = 4; progress_bg.corner_radius_bottom_right = 4
	
	var progress_style = StyleBoxFlat.new()
	progress_style.bg_color = Color(0.2, 0.8, 0.3, 0.9) # Bright emerald green
	progress_style.corner_radius_top_left = 4; progress_style.corner_radius_top_right = 4
	progress_style.corner_radius_bottom_left = 4; progress_style.corner_radius_bottom_right = 4
	
	theme.set_stylebox("background", "ProgressBar", progress_bg)
	theme.set_stylebox("fill", "ProgressBar", progress_style)

	# Elegant Separator
	theme.set_color("color", "HSeparator", Color(0.85, 0.7, 0.2, 0.3)) # Faint gold line

	theme.default_font_size = 16  # Increased for readability
	
	get_tree().root.theme = theme  # Apply globally
