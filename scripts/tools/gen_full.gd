extends SceneTree
# Verified working generator - builds on gen_min.gd which proved all concepts

const P := {
	0: "", 1: "#1a1c2c", 2: "#5d275d", 3: "#b13e53",
	4: "#ef7d57", 5: "#ffcd75", 6: "#a7f070", 7: "#38b764",
	8: "#257179", 9: "#29366f", 10: "#3b5dc9", 11: "#41a6f6",
	12: "#73eff7", 13: "#f4f4f4", 14: "#94b0c2", 15: "#566c86",
}

func _init():
	print("=== Thronehold Asset Generator v7 ===")
	var pp = load("res://scripts/tools/PixelPatterns.gd")
	var total = 0; var errs = 0
	
	# TERRAIN TILES (16x16)
	print("\n--- Terrain Tiles ---")
	for key in pp.TERRAIN_PATTERNS:
		var px = _px(pp.TERRAIN_PATTERNS[key].rows)
		var img = _img(px, 16, 16)
		if _s(img, "tiles/" + key + ".png"): total += 1
		else: errs += 1
	print("  %d files" % pp.TERRAIN_PATTERNS.size())
	
	# FLAGS (32x16)
	print("\n--- Flags ---")
	for fname in pp.FLAG_PRESETS:
		var p = pp.FLAG_PRESETS[fname]
		var img = _flag(p.primary, p.secondary, p.icon, pp)
		if _s(img, "flags/" + fname + ".png"): total += 1
		else: errs += 1
	print("  %d files" % pp.FLAG_PRESETS.size())
	
	# DEITY SYMBOLS (32x32)
	print("\n--- Deity Symbols ---")
	for cid in pp.DEITY_CLASS_SYMBOL_MAP:
		var sk = pp.DEITY_CLASS_SYMBOL_MAP[cid]
		var sp = pp.DEITY_SYMBOLS.get(sk, {})
		var bg = pp.DEITY_CLASS_COLORS.get(cid, 1)
		var img = _deity(sp, bg)
		if _s(img, "symbols/" + cid + ".png"): total += 1
		else: errs += 1
	print("  %d files" % pp.DEITY_CLASS_SYMBOL_MAP.size())
	
	# BUILDINGS (8x8)
	print("\n--- Building Icons ---")
	for key in pp.BUILDING_PATTERNS:
		var px = _px(pp.BUILDING_PATTERNS[key].rows)
		var img = _img(px, 8, 8)
		if _s(img, "buildings/" + key + ".png"): total += 1
		else: errs += 1
	print("  %d files" % pp.BUILDING_PATTERNS.size())
	
	# TECH (8x8)
	print("\n--- Tech Icons ---")
	for key in pp.TECH_PATTERNS:
		var px = _px(pp.TECH_PATTERNS[key].rows)
		var img = _img(px, 8, 8)
		if _s(img, "tech/" + key + ".png"): total += 1
		else: errs += 1
	print("  %d files" % pp.TECH_PATTERNS.size())
	
	# PORTRAITS (8x8)
	print("\n--- Leader Portraits ---")
	for key in pp.LEADER_FACES:
		var px = _px(pp.LEADER_FACES[key].rows)
		var img = _img(px, 8, 8)
		if _s(img, "portraits/" + key + ".png"): total += 1
		else: errs += 1
	print("  %d files" % pp.LEADER_FACES.size())
	
	print("\n=== TOTAL: %d files, %d errors ===" % [total, errs])
	quit(0)

# Parse hex/binary rows to flat pixel array
func _px(rows):
	var r = []
	for row in rows:
		for ch in row:
			if ch == "0" or ch == "1": r.append(int(ch))
			else: r.append(("0x" + ch).hex_to_int())
	return r

# Build Image from pixel array
func _img(px, w, h):
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for i in range(w * h):
		var p = 0
		if i < px.size(): p = px[i]
		var x = i % w; var y = i / w
		img.set_pixel(x, y, Color(P.get(p, "")) if P.get(p, "") != "" else Color(0,0,0,0))
	return img

# Build nation flag (32x16)
func _flag(pri, sec, icon_name, pp):
	var w = 32; var h = 16
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var pc = Color(P.get(pri, "#1a1c2c"))
	var sc = Color(P.get(sec, "#5d275d"))
	for y in range(h):
		for x in range(w):
			img.set_pixel(x, y, pc if x < w/2 else sc)
	var icon = pp.FLAG_ICONS.get(icon_name, {})
	if not icon.is_empty() and icon.has("rows"):
		var ipx = _px(icon.rows)
		var iw = icon.width; var ih = icon.height
		var ox = (w - iw) / 2; var oy = (h - ih) / 2
		var wc = Color(P.get(13, "#f4f4f4"))
		for y in range(ih):
			for x in range(iw):
				var si = y * iw + x
				if si < ipx.size() and ipx[si] == 1:
					img.set_pixel(ox + x, oy + y, wc)
	return img

# Build deity symbol (32x32)
func _deity(pattern, bg_idx):
	var sw = 32; var sh = 32
	var img = Image.create(sw, sh, false, Image.FORMAT_RGBA8)
	var bgc = Color(P.get(bg_idx, "#1a1c2c"))
	for y in range(sh):
		for x in range(sw):
			img.set_pixel(x, y, bgc)
	if pattern.is_empty(): return img
	var px = _px(pattern.rows)
	var wc = Color(P.get(13, "#f4f4f4"))
	for y in range(pattern.height):
		for x in range(pattern.width):
			var si = y * pattern.width + x
			if si < px.size() and px[si] == 1:
				var bx = x * 2; var by = y * 2
				for dy in range(2):
					for dx in range(2):
						img.set_pixel(bx + dx, by + dy, wc)
	return img

# Save image to assets/
func _s(img, rel):
	if img.is_empty(): return false
	var full = "res://assets/" + rel
	var d = full.get_base_dir()
	if not DirAccess.dir_exists_absolute(d):
		DirAccess.make_dir_recursive_absolute(d)
	return img.save_png(full) == OK
