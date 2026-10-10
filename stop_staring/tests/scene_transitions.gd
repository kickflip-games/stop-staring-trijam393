extends SceneTree
func _initialize():
	call_deferred("run_checks")
func run_checks():
	root.size = Vector2i(1280, 800)
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await create_timer(0.5).timeout
	game.show_menu()
	var transition = root.get_node("EasyTransition")
	while transition.is_transitioning:
		await process_frame
	game = current_scene
	await process_frame
	game.start_level(2)
	assert(transition.is_transitioning)
	assert(transition.layer > game._layer.layer)
	game.start_level(0)
	assert(transition.get_meta("game_destination").level == 2, "second click must not replace route")
	var started = Time.get_ticks_msec()
	var captured = false
	while transition.is_transitioning:
		await process_frame
		var progress = transition._mat.get_shader_parameter("progress")
		if not captured and progress >= 0.97 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var image = root.get_texture().get_image()
			image.save_png("/tmp/stop-staring-black-fade.png")
			assert(image.get_pixel(640, 400).get_luminance() < 0.05, "fade covers UI in black")
			captured = true
	var duration = Time.get_ticks_msec() - started
	game = current_scene
	assert(game.mode == "playing" and game.active_level == 2)
	await process_frame
	assert(game.gameplay.get_node("Player").is_physics_processing())
	assert(game.gameplay.get_node("Player").is_processing_unhandled_input())
	assert(game.elapsed < 0.1, "fade time is excluded from gameplay timer")
	assert(duration >= 450 and duration < 3000, "default transition lasts about half a second")
	print("PASS: black fade above UI, %.3fs duration, duplicate request blocked, selected level preserved, gameplay resumes after uncover" % (duration / 1000.0))
	game.queue_free()
	await process_frame
	quit()
