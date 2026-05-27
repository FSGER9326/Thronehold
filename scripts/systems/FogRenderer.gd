class_name FogRenderer
extends Node2D
# =============================================================================
# Fog of War overlay drawn via _draw(). Reads ColonyData.visibility_grid:
#   0 = unexplored (black overlay)
#   1 = explored / tilelit (dark grey overlay)
#   2 = visible / active (no overlay)
#
# Border tiles between visibility states use gradient sub-rects for a smooth
# visual transition instead of hard edges.
# =============================================================================

const VISIBILITY_RADIUS: int = 5
const TILE_PX: int = 16
const GRAD_STEPS: int = 4
const STEP_PX: int = TILE_PX / GRAD_STEPS

var _spectator_mode: bool = false
var _fog_rects: Array[Dictionary] = []
var _fog_rects_dirty: bool = true


# Returns the visibility level at (x, y), treating out-of-bounds as visible
func _get_vis_level(x: int, y: int, w: int, h: int) -> int:
	if x < 0 or x >= w or y < 0 or y >= h:
		return 2
	return ColonyData.visibility_grid[y * w + x]


# Returns the overlay alpha for a given visibility level
static func _alpha_for_vis(vis: int) -> float:
	match vis:
		0: return 0.85
		1: return 0.55
		_: return 0.0


# Draws a tile with gradient sub-rects on edges where visibility changes
func _add_fog_with_gradient(ox: int, oy: int, vis: int, base_col: Color,
		w: int, h: int, x: int, y: int,
		edge_left: bool, edge_right: bool, edge_top: bool, edge_bottom: bool) -> void:
	
	var inner_l = STEP_PX if edge_left else 0
	var inner_r = TILE_PX - STEP_PX if edge_right else TILE_PX
	var inner_t = STEP_PX if edge_top else 0
	var inner_b = TILE_PX - STEP_PX if edge_bottom else TILE_PX
	var inner_w = inner_r - inner_l
	var inner_h = inner_b - inner_t
	
	# Draw solid inner core
	if inner_w > 0 and inner_h > 0:
		_fog_rects.append({"rect": Rect2(ox + inner_l, oy + inner_t, inner_w, inner_h), "color": base_col})
	
	# Draw gradient strips along each gradient edge
	var target_alpha = base_col.a
	for s in range(GRAD_STEPS):
		var t = (s + 0.5) / GRAD_STEPS  # 0.125..0.875
		
		if edge_left:
			var na = _alpha_for_vis(_get_vis_level(x - 1, y, w, h))
			var sa = lerp(na, target_alpha, t)
			_fog_rects.append({"rect": Rect2(ox + s * STEP_PX, oy + inner_t, STEP_PX, inner_h), "color": Color(base_col.r, base_col.g, base_col.b, sa)})
		
		if edge_right:
			var na = _alpha_for_vis(_get_vis_level(x + 1, y, w, h))
			var sa = lerp(na, target_alpha, t)
			_fog_rects.append({"rect": Rect2(ox + inner_r + s * STEP_PX, oy + inner_t, STEP_PX, inner_h), "color": Color(base_col.r, base_col.g, base_col.b, sa)})
		
		if edge_top:
			var na = _alpha_for_vis(_get_vis_level(x, y - 1, w, h))
			var sa = lerp(na, target_alpha, t)
			_fog_rects.append({"rect": Rect2(ox + inner_l, oy + s * STEP_PX, inner_w, STEP_PX), "color": Color(base_col.r, base_col.g, base_col.b, sa)})
		
		if edge_bottom:
			var na = _alpha_for_vis(_get_vis_level(x, y + 1, w, h))
			var sa = lerp(na, target_alpha, t)
			_fog_rects.append({"rect": Rect2(ox + inner_l, oy + inner_b + s * STEP_PX, inner_w, STEP_PX), "color": Color(base_col.r, base_col.g, base_col.b, sa)})


func set_spectator_mode(enabled: bool) -> void:
	_spectator_mode = enabled
	if enabled:
		for i in range(ColonyData.visibility_grid.size()):
			ColonyData.visibility_grid[i] = 2
	else:
		_update_visibility()
	queue_redraw()


func _ready() -> void:
	EventBus.world_generated.connect(func(_w: int, _h: int): _update_visibility())
	EventBus.tick_advanced.connect(func(tick: int, _d: int, _s: String, _y: int):
		if tick % 20 == 0:
			_update_visibility()
	)
	EventBus.territory_captured.connect(func(_c: int, _x: int, _y: int):
		_update_visibility()
	)


func _update_visibility() -> void:
	if _spectator_mode:
		return

	var w = ColonyData.world_width
	var h = ColonyData.world_height
	if ColonyData.visibility_grid.size() != w * h:
		return

	# Step 1: downgrade all currently visible tiles to explored
	for i in range(ColonyData.visibility_grid.size()):
		if ColonyData.visibility_grid[i] == 2:
			ColonyData.visibility_grid[i] = 1

	# Step 2: for each player-owned tile, reveal radius-5 around it
	var pid = ColonyData.player_nation_id
	if pid < 0:
		return

	for y in range(h):
		for x in range(w):
			var tile = ColonyData.get_tile(x, y)
			if tile.get("owner", -1) != pid:
				continue
			for dy in range(-VISIBILITY_RADIUS, VISIBILITY_RADIUS + 1):
				for dx in range(-VISIBILITY_RADIUS, VISIBILITY_RADIUS + 1):
					var tx = x + dx
					var ty = y + dy
					if tx < 0 or tx >= w or ty < 0 or ty >= h:
						continue
					var idx = ty * w + tx
					ColonyData.visibility_grid[idx] = 2

	# Rebuild cached fog rects from visibility_grid — with gradient borders
	_fog_rects.clear()
	var fog_black = Color(0, 0, 0, 0.85)
	var fog_grey = Color(0.2, 0.2, 0.2, 0.55)
	for y in range(h):
		for x in range(w):
			var idx2 = y * w + x
			var vis: int = ColonyData.visibility_grid[idx2]
			match vis:
				0:
					var e_l = x > 0 and _get_vis_level(x - 1, y, w, h) != 0
					var e_r = x < w - 1 and _get_vis_level(x + 1, y, w, h) != 0
					var e_t = y > 0 and _get_vis_level(x, y - 1, w, h) != 0
					var e_b = y < h - 1 and _get_vis_level(x, y + 1, w, h) != 0
					if e_l or e_r or e_t or e_b:
						_add_fog_with_gradient(x * TILE_PX, y * TILE_PX, vis, fog_black, w, h, x, y, e_l, e_r, e_t, e_b)
					else:
						_fog_rects.append({"rect": Rect2(x * TILE_PX, y * TILE_PX, TILE_PX, TILE_PX), "color": fog_black})
				1:
					var e_l = x > 0 and _get_vis_level(x - 1, y, w, h) == 0
					var e_r = x < w - 1 and _get_vis_level(x + 1, y, w, h) == 0
					var e_t = y > 0 and _get_vis_level(x, y - 1, w, h) == 0
					var e_b = y < h - 1 and _get_vis_level(x, y + 1, w, h) == 0
					if e_l or e_r or e_t or e_b:
						_add_fog_with_gradient(x * TILE_PX, y * TILE_PX, vis, fog_grey, w, h, x, y, e_l, e_r, e_t, e_b)
					else:
						_fog_rects.append({"rect": Rect2(x * TILE_PX, y * TILE_PX, TILE_PX, TILE_PX), "color": fog_grey})

	_fog_rects_dirty = true
	queue_redraw()


func _draw() -> void:
	if _spectator_mode:
		return

	if _fog_rects.is_empty():
		return

	for entry in _fog_rects:
		draw_rect(entry.rect, entry.color)
