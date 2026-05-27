extends SceneTree

func _init():
	print("START gen_min")
	var pp = load("res://scripts/tools/PixelPatterns.gd")
	print("pp loaded: ", pp != null)
	print("TERRAIN keys: ", pp.TERRAIN_PATTERNS.keys())
	
	for key in pp.TERRAIN_PATTERNS:
		print("Processing: ", key)
		var pattern = pp.TERRAIN_PATTERNS[key]
		var rows = pattern.rows
		print("  rows count: ", rows.size())
		var pixels = []
		for row in rows:
			for ch in row:
				if ch == "0" or ch == "1":
					pixels.append(int(ch))
				else:
					pixels.append(("0x" + ch).hex_to_int())
		print("  pixels count: ", pixels.size())
		
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		print("  image created: ", not img.is_empty())
		
		for idx in range(256):
			var px = 0
			if idx < pixels.size():
				px = pixels[idx]
			# Skip palette lookup for speed
		
		var dir = "res://assets/tiles/"
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)
		var err = img.save_png(dir + key + ".png")
		print("  saved: ", err == OK)
	
	print("DONE gen_min")
	quit(0)
