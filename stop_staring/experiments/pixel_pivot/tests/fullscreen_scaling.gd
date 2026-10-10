extends SceneTree
## Native fullscreen switching, aspect fit and pointer routing at fractional scales.
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func settle() -> void:
	await create_timer(0.8, true, false, true).timeout
	await process_frame

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event)

func mouse(scene: Control, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = scene.get_node("View").position + point * scene.display_scale
	event.global_position = event.position
	event.pressed = pressed
	root.push_input(event)

func check_fit(scene: Control) -> void:
	var view: Control = scene.get_node("View")
	var room := Vector2(scene.get_node("View/World").size)
	var available := scene.get_viewport_rect().size
	var shown := view.size * view.scale
	check(is_equal_approx(view.scale.x, view.scale.y), "Uniform scale preserves the aspect ratio")
	check(shown.x <= available.x + 0.01 and shown.y <= available.y + 0.01, "Whole view stays inside the screen")
	check(absf(shown.x - available.x) < 0.01 or absf(shown.y - available.y) < 0.01, "View fills at least one screen dimension")
	check(view.position.is_equal_approx((available - shown) * 0.5), "Necessary letterboxing stays centered")
	check(is_equal_approx(shown.x / shown.y, room.x / room.y), "Room aspect ratio stays correct")

func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/fullscreen/" + name + ".png")) == OK, "Saved " + name)

func run() -> void:
	check(ProjectSettings.get_setting("display/window/size/mode") == Window.MODE_FULLSCREEN, "Project starts fullscreen")
	if DisplayServer.get_name() != "headless":
		check(root.mode == Window.MODE_FULLSCREEN, "Native window actually opens fullscreen")
	# Let the native startup fullscreen transition finish before toggling it.
	await settle()
	for path in ["res://ui/home_screen.tscn", "res://experiments/pixel_pivot/pixel_pivot.tscn"]:
		root.mode = Window.MODE_WINDOWED
		await settle()
		root.size = Vector2i(1280, 800)
		var scene: Control = load(path).instantiate()
		root.add_child(scene)
		current_scene = scene
		if DisplayServer.get_name() != "headless":
			root.grab_focus()
		await settle()
		var is_game := scene.has_node("View/World/PixelArena")
		for size in [Vector2i(1280, 800), Vector2i(1920, 1080), Vector2i(900, 1200)]:
			root.size = size
			await settle()
			check_fit(scene)
		root.size = Vector2i(1280, 800)
		await settle()
		await capture("game_window" if is_game else "menu_window")
		if DisplayServer.get_name() != "headless":
			if is_game:
				var arena: Node = scene.get_node("View/World/PixelArena")
				arena.set_focused(true)
				var player: CharacterBody2D = arena.get_node("Slime")
				player.set_physics_process(false)
				player.velocity = Vector2(120, 30)
				mouse(scene, Vector2(180, 120), true)
				check(player.aiming, "Fractional-scale press starts aiming")
			key(KEY_F11)
			await settle()
			check(root.mode == Window.MODE_FULLSCREEN, "F11 enters fullscreen")
			check_fit(scene)
			await capture("game_fullscreen" if is_game else "menu_fullscreen")
			if is_game:
				var arena: Node = scene.get_node("View/World/PixelArena")
				arena.set_focused(true)
				var player: CharacterBody2D = arena.get_node("Slime")
				check(not player.aiming and player.velocity == Vector2(120, 30), "Fullscreen cancels aim without changing velocity")
				mouse(scene, Vector2(132, 120), false)
				check(player.velocity == Vector2(120, 30), "Release from the old gesture cannot launch")
				mouse(scene, Vector2(180, 120), true)
				mouse(scene, Vector2(132, 120), false)
				check(player.velocity.is_equal_approx(Vector2(288, 0)), "Fullscreen drag keeps the launch speed and direction")
			key(KEY_F11)
			await settle()
			check(root.mode == Window.MODE_WINDOWED, "F11 returns to windowed mode")
			check_fit(scene)
		scene.queue_free()
		await process_frame
	check(Engine.time_scale == 1.0, "Exiting restores normal time scale")
	print("Fullscreen scaling: ", checks, " checks, ", failures.size(), " failures: ", failures)
	quit(0 if failures.is_empty() else 1)
