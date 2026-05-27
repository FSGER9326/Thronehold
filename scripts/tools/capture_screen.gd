extends Node
# Quick screenshot capture: forces world gen and captures UI
# Run via: godot --headless --script res://scripts/tools/capture_screen.gd

func _ready() -> void:
	print("Auto-capturing screenshots...")
	
	# Force state to WORLD_SETUP so main.gd generates world
	GameManager.change_state(GameManager.GameState.WORLD_SETUP)
	
	# Wait for world generation to complete and render
	await get_tree().create_timer(2.0).timeout
	
	# Capture full viewport screenshot
	var img = get_viewport().get_texture().get_image()
	if img:
		var path = OS.get_user_data_dir() + "/screen_capture.png"
		img.save_png(path)
		print("Screenshot saved: " + path)
	else:
		print("ERROR: Could not capture screenshot")
	
	# Wait and capture another after some simulation ticks
	await get_tree().create_timer(3.0).timeout
	img = get_viewport().get_texture().get_image()
	if img:
		var path2 = OS.get_user_data_dir() + "/screen_after_play.png"
		img.save_png(path2)
		print("Screenshot 2 saved: " + path2)
	
	print("Done. Quitting.")
	get_tree().quit()
