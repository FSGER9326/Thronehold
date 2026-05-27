extends CanvasLayer
# =============================================================================
# TutorialOverlay.gd — Step-by-step tutorial guide shown on first game launch.
# 5 steps walk the player through the core gameplay loop.
# =============================================================================

var _current_step: int = 0
var _on_complete: Callable = func(): pass

var _bg: PanelContainer
var _card: PanelContainer
var _icon_label: Label
var _title_label: Label
var _desc_label: RichTextLabel
var _dots: Array[Control] = []
var _next_btn: Button
var _dismiss_btn: Button

const STEP_ICONS = ["👑", "🏛️", "📜", "⚡", "🌟"]
const STEPS = [
	{
		"title": "Welcome, Divine One",
		"desc": "You have chosen your deity form and taken your first steps into the mortal realm. Your nation has been founded and the world awaits your influence.\n\nOn the left, you'll see your [b]Resources[/b] — keep an eye on food, wood, stone, metal, and gold. These are the lifeblood of your civilization.\n\nThe [b]bottom bar[/b] holds all your divine panels — explore them as you grow.",
	},
	{
		"title": "Your First Nation",
		"desc": "Look at the left sidebar: your nation's stats show population, military strength, and your current ruler.\n\nThe [b]Resources[/b] panel tracks your stockpiles. Below it, the [b]Nation[/b] panel shows your people's belief in you.\n\nClick on any tile on the map to see its details in the [b]Tile Info[/b] section.",
	},
	{
		"title": "Open Policies & Enact One",
		"desc": "Click the [b]Policies[/b] button in the bottom tab bar. This opens the Policies panel.\n\nYou'll see Active Policies (already in effect) and Available Policies (ones you can enact).\n\nChoose a policy and click [b]Enact[/b] to shape your nation's laws. Policies provide powerful bonuses — experiment with different combinations!",
	},
	{
		"title": "Try Divine Influence",
		"desc": "Click the [b]Influence[/b] button in the bottom bar to open the Divine Influence panel.\n\nSelect a neighboring nation and try a [b]Divine Sign[/b] — it costs only 5 divine power. Watch the belief percentage grow as your influence spreads.\n\nStronger actions like Dream Visions and Miracles become available as you gain power.",
	},
	{
		"title": "You Are Ready!",
		"desc": "You now know the essentials:\n\n• [b]Manage resources[/b] — keep your stockpiles healthy\n• [b]Enact policies[/b] — guide your nation's development\n• [b]Spread influence[/b] — convert neighboring nations\n• [b]Build structures[/b] — click Build to place shrines, farms, and more\n\nExplore the other tabs: Skill Tree, Pantheon, Culture, Diplomacy, and more. Guide your civilization to glory!",
	},
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	show_step(0)


func _build_ui() -> void:
	# --- Full-screen dim background ---
	_bg = PanelContainer.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.01, 0.01, 0.03, 0.6) # Darker glass background
	_bg.add_theme_stylebox_override("panel", bg_style)
	add_child(_bg)

	# --- Centered card ---
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.add_child(center)

	var card_margin = MarginContainer.new()
	card_margin.custom_minimum_size = Vector2(520, 0)
	card_margin.add_theme_constant_override("margin_left", 8)
	card_margin.add_theme_constant_override("margin_right", 8)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(500, 380)
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	card_style.border_color = Color(0.85, 0.7, 0.2, 0.8) # Gold border
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 12
	card_style.corner_radius_top_right = 12
	card_style.corner_radius_bottom_left = 12
	card_style.corner_radius_bottom_right = 12
	card_style.shadow_color = Color(0, 0, 0, 0.6)
	card_style.shadow_size = 20
	_card.add_theme_stylebox_override("panel", card_style)

	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 10)

	# --- Icon ---
	var icon_center = HBoxContainer.new()
	icon_center.alignment = BoxContainer.ALIGNMENT_CENTER
	_icon_label = Label.new()
	_icon_label.add_theme_font_size_override("font_size", 40)
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_center.add_child(_icon_label)
	card_vbox.add_child(icon_center)

	# --- Title ---
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color("#ffd700"))
	card_vbox.add_child(_title_label)

	# --- Separator ---
	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(0.85, 0.7, 0.2, 0.3))
	card_vbox.add_child(sep)

	# --- Description (RichTextLabel for BBCode) ---
	_desc_label = RichTextLabel.new()
	_desc_label.bbcode_enabled = true
	_desc_label.fit_content = true
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desc_label.add_theme_color_override("default_color", Color(0.82, 0.82, 0.88))
	card_vbox.add_child(_desc_label)

	# --- Step dots ---
	var dot_hbox = HBoxContainer.new()
	dot_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dot_hbox.add_theme_constant_override("separation", 10)
	for i in STEPS.size():
		var dot = PanelContainer.new()
		dot.custom_minimum_size = Vector2(8, 8)
		var dot_style = StyleBoxFlat.new()
		dot_style.corner_radius_top_left = 4
		dot_style.corner_radius_top_right = 4
		dot_style.corner_radius_bottom_left = 4
		dot_style.corner_radius_bottom_right = 4
		dot_style.bg_color = Color(0.3, 0.3, 0.45)
		dot.add_theme_stylebox_override("panel", dot_style)
		_dots.append(dot)
		dot_hbox.add_child(dot)
	card_vbox.add_child(dot_hbox)

	# --- Separator ---
	var sep2 = HSeparator.new()
	sep2.add_theme_color_override("color", Color(0.85, 0.7, 0.2, 0.3))
	card_vbox.add_child(sep2)

	# --- Buttons row ---
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 12)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# Dismiss / Skip button
	_dismiss_btn = Button.new()
	_dismiss_btn.text = "Skip Tutorial"
	_dismiss_btn.custom_minimum_size = Vector2(140, 36)
	_dismiss_btn.pressed.connect(_on_dismiss)
	_dismiss_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.65))
	btn_hbox.add_child(_dismiss_btn)

	# Next / Done button
	_next_btn = Button.new()
	_next_btn.text = "Next →"
	_next_btn.custom_minimum_size = Vector2(140, 36)
	# Button style
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.1, 0.1, 0.18, 0.85)
	btn_normal.border_color = Color(0.35, 0.35, 0.55, 0.8)
	btn_normal.border_width_left = 1
	btn_normal.border_width_right = 1
	btn_normal.border_width_top = 1
	btn_normal.border_width_bottom = 2
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	_next_btn.add_theme_stylebox_override("normal", btn_normal)
	
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.15, 0.15, 0.25, 0.95)
	btn_hover.border_color = Color(0.9, 0.8, 0.3, 0.9)
	btn_hover.shadow_color = Color(0.9, 0.8, 0.3, 0.2)
	btn_hover.shadow_size = 4
	_next_btn.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	btn_pressed.border_color = Color(0.7, 0.6, 0.2, 0.9)
	btn_pressed.border_width_top = 2
	btn_pressed.border_width_bottom = 1
	_next_btn.add_theme_stylebox_override("pressed", btn_pressed)
	_next_btn.add_theme_color_override("font_color", Color("#ffd700"))
	_next_btn.add_theme_color_override("font_hover_color", Color("#ffe44d"))

	_next_btn.pressed.connect(_on_next)
	btn_hbox.add_child(_next_btn)

	card_vbox.add_child(btn_hbox)

	# Assemble
	_card.add_child(card_vbox)
	card_margin.add_child(_card)
	center.add_child(card_margin)


func show_step(index: int) -> void:
	_current_step = index
	var step = STEPS[index]

	_icon_label.text = STEP_ICONS[index]
	_title_label.text = step["title"]
	_desc_label.text = step["desc"]

	# Update dots
	for i in _dots.size():
		var dot_style = StyleBoxFlat.new()
		dot_style.corner_radius_top_left = 4
		dot_style.corner_radius_top_right = 4
		dot_style.corner_radius_bottom_left = 4
		dot_style.corner_radius_bottom_right = 4
		if i == index:
			dot_style.bg_color = Color("#ffd700")
		elif i < index:
			dot_style.bg_color = Color(0.2, 0.6, 0.3)
		else:
			dot_style.bg_color = Color(0.3, 0.3, 0.45)
		_dots[i].add_theme_stylebox_override("panel", dot_style)

	# Update button text
	if index >= STEPS.size() - 1:
		_next_btn.text = "Done"
		_dismiss_btn.text = "Skip"
	else:
		_next_btn.text = "Next →"
		_dismiss_btn.text = "Skip Tutorial"


func _on_next() -> void:
	if _current_step >= STEPS.size() - 1:
		_complete_tutorial()
	else:
		show_step(_current_step + 1)


func _on_dismiss() -> void:
	_complete_tutorial()


func _complete_tutorial() -> void:
	ColonyData.has_seen_tutorial = true
	_on_complete.call()
	queue_free()


func set_on_complete(callback: Callable) -> void:
	_on_complete = callback
