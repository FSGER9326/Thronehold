extends SceneTree
# Minimal test: just create one PNG to verify headless image creation works

func _init() -> void:
	print("TEST: Starting...")
	
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	if img.is_empty():
		print("TEST: Image.create FAILED (empty)")
		quit(1)
	
	print("TEST: Image created: %dx%d" % [img.get_width(), img.get_height()])
	
	# Fill with a visible color
	for y in range(16):
		for x in range(16):
			if x < 8 and y < 8:
				img.set_pixel(x, y, Color.RED)
			elif x >= 8 and y < 8:
				img.set_pixel(x, y, Color.GREEN)
			elif x < 8 and y >= 8:
				img.set_pixel(x, y, Color.BLUE)
			else:
				img.set_pixel(x, y, Color.YELLOW)
	
	# Ensure directory
	var dir = "res://assets/tiles/"
	if not DirAccess.dir_exists_absolute(dir):
		var err = DirAccess.make_dir_recursive_absolute(dir)
		print("TEST: mkdir %s -> %d" % [dir, err])
	
	var path = dir + "test_gen.png"
	var err = img.save_png(path)
	print("TEST: save_png %s -> %d" % [path, err])
	
	# Verify file exists
	if FileAccess.file_exists(path):
		print("TEST: File verified! %s" % path)
	else:
		print("TEST: File NOT found after save!")
	
	quit(0)
