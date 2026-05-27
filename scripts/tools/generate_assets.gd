extends SceneTree
# Run: godot --headless --script res://scripts/tools/generate_assets.gd

const PALETTE := {
	0: "",          1: "#1a1c2c", 2: "#5d275d",
	3: "#b13e53",   4: "#ef7d57", 5: "#ffcd75",
	6: "#a7f070",   7: "#38b764", 8: "#257179",
	9: "#29366f",  10: "#3b5dc9", 11: "#41a6f6",
	12: "#73eff7", 13: "#f4f4f4", 14: "#94b0c2",
	15: "#566c86",
}

func _init() -> void:
	print("Thronehold Asset Generator v5")
	var pp = load("res://scripts/tools/PixelPatterns.gd")
	if pp == null: print("FATAL: pp null"); quit(1); return
	
	var total = 0; var errors = 0
	
	# --- TERRAIN (16x16) ---
	for key in pp.TERRAIN_PATTERNS:
		if _save(_make_img(pp.TERRAIN_PATTERNS[key], 16, 16), "tiles/" + key + ".png"):
			total += 1
		else:
			errors += 1
	print("Terrain: %d generated" % pp.TERRAIN_PATTERNS.size())
	
	# --- FLAGS (32x16) ---
	for fname in pp.FLAG_PRESETS:
		var p = pp.FLAG_PRESETS[fname]
		var flag = _make_flag(p.primary, p.secondary, p.icon, pp)
		if _save(flag, "flags/" + fname + ".png"):
			total += 1
		else:
			errors += 1
	print("Flags: %d generated" % pp.FLAG_PRESETS.size())
	
	# --- DEITY SYMBOLS (32x32) ---
	for cid in pp.DEITY_CLASS_SYMBOL_MAP:
		var sk = pp.DEITY_CLASS_SYMBOL_MAP[cid]
		var sp = pp.DEITY_SYMBOLS.get(sk, {})
		var bg = pp.DEITY_CLASS_COLORS.get(cid, 1)
		if _save(_make_deity(sp, bg), "symbols/" + cid + ".png"):
			total += 1
		else:
			errors += 1
	print("Deities: %d generated" % pp.DEITY_CLASS_SYMBOL_MAP.size())
	
	# --- BUILDINGS (8x8) ---
	for key in pp.BUILDING_PATTERNS:
		if _save(_make_img(pp.BUILDING_PATTERNS[key], 8, 8), "buildings/" + key + ".png"):
			total += 1
		else:
			errors += 1
	print("Buildings: %d generated" % pp.BUILDING_PATTERNS.size())
	
	# --- TECH (8x8) ---
	for key in pp.TECH_PATTERNS:
		if _save(_make_img(pp.TECH_PATTERNS[key], 8, 8), "tech/" + key + ".png"):
			total += 1
		else:
			errors += 1
	print("Tech: %d generated" % pp.TECH_PATTERNS.size())
	
	# --- PORTRAITS (8x8) ---
	for key in pp.LEADER_FACES:
		if _save(_make_img(pp.LEADER_FACES[key], 8, 8), "portraits/" + key + ".png"):
			total += 1
		else:
			errors += 1
	print("Portraits: %d generated" % pp.LEADER_FACES.size())
	
	print("TOTAL: %d files saved, %d errors" % [total, errors])
	quit(0 if errors == 0 else 1)

func _make_img(pattern: Dictionary, w: int, h: int) -> Image:
	var rows: PackedStringArray = pattern.rows
	var pixels = _parse_rows(rows)
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for idx in range(w * h):
		var px = 0
		if idx < pixels.size(): px = pixels[idx]
		var x = idx % w; var y = idx / w
		if px == 0 or not PALETTE.has(px) or PALETTE[px] == "":
			img.set_pixel(x, y, Color(0, 0, 0, 0))
		else:
			img.set_pixel(x, y, Color(PALETTE[px]))
	return img

func _parse_rows(rows: PackedStringArray) -> Array:
	var result: Array = []
	for row in rows:
		for ch in row:
			if ch == "0" or ch == "1":
				result.append(int(ch))
			else:
				result.append(("0x" + ch).hex_to_int())
	return result

func _make_flag(pri: int, sec: int, icon_name: String, pp) -> Image:
	var fw = 32; var fh = 16
	var img = Image.create(fw, fh, false, Image.FORMAT_RGBA8)
	var pc = Color(PALETTE.get(pri, "#1a1c2c"))
	var sc = Color(PALETTE.get(sec, "#5d275d"))
	for y in range(fh):
		for x in range(fw):
			img.set_pixel(x, y, pc if x < fw / 2 else sc)
	var icon = pp.FLAG_ICONS.get(icon_name, {})
	if not icon.is_empty() and icon.has("rows"):
		var ipx = _parse_rows(icon.rows)
		var iw = icon.width; var ih = icon.height
		var ox = (fw - iw) / 2; var oy = (fh - ih) / 2
		var wc = Color(PALETTE.get(13, "#f4f4f4"))
		for y in range(ih):
			for x in range(iw):
				var si = y * iw + x
				if si < ipx.size() and ipx[si] == 1:
					img.set_pixel(ox + x, oy + y, wc)
	return img

func _make_deity(pattern: Dictionary, bg_idx: int) -> Image:
	var sw = 32; var sh = 32
	var img = Image.create(sw, sh, false, Image.FORMAT_RGBA8)
	var bgc = Color(PALETTE.get(bg_idx, "#1a1c2c"))
	for y in range(sh):
		for x in range(sw):
			img.set_pixel(x, y, bgc)
	if pattern.is_empty(): return img
	var px = _parse_rows(pattern.rows)
	var wc = Color(PALETTE.get(13, "#f4f4f4"))
	for y in range(pattern.height):
		for x in range(pattern.width):
			var si = y * pattern.width + x
			if si < px.size() and px[si] == 1:
				var bx = x * 2; var by = y * 2
				for dy in range(2):
					for dx in range(2):
						img.set_pixel(bx + dx, by + dy, wc)
	return img

func _save(img: Image, rel: String) -> bool:
	if img.is_empty(): return false
	var full = "res://assets/" + rel
	var d = full.get_base_dir()
	if not DirAccess.dir_exists_absolute(d):
		DirAccess.make_dir_recursive_absolute(d)
	return img.save_png(full) == OK
