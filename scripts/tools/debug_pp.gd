extends SceneTree

func _init() -> void:
	print("Debug: Loading PixelPatterns...")
	var pp = load("res://scripts/tools/PixelPatterns.gd")
	if pp == null:
		print("FATAL: pp is null")
		quit(1)
	
	print("pp is: ", pp)
	print("pp is GDScript: ", pp is GDScript)
	
	var keys = pp.TERRAIN_PATTERNS.keys() if pp.has_method("get") else []
	print("TERRAIN_PATTERNS type: ", typeof(pp.TERRAIN_PATTERNS))
	print("TERRAIN_PATTERNS is Dictionary: ", pp.TERRAIN_PATTERNS is Dictionary)
	print("Keys count: ", pp.TERRAIN_PATTERNS.size() if pp.TERRAIN_PATTERNS is Dictionary else -1)
	
	var first_key = ""
	for k in pp.TERRAIN_PATTERNS:
		first_key = k
		break
	print("First key: ", first_key)
	
	var first_pattern = pp.TERRAIN_PATTERNS[first_key]
	print("First pattern type: ", typeof(first_pattern))
	print("First pattern has rows: ", first_pattern.has("rows") if first_pattern is Dictionary else false)
	
	quit(0)
