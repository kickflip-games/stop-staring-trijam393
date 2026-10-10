extends SceneTree
## Exercise the real menu input, scene changes, and aspect-fitted captures.
const HOME := "res://ui/home_screen.tscn"
const CAPTURES := "res://../docs/home_screen/"
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
	await process_frame
	await process_frame

func click(point: Vector2) -> void:
	var view: Control = current_scene.get_node("View")
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = view.position + point * current_scene.display_scale
		event.global_position = event.position
		event.pressed = pressed
		root.push_input(event)

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(CAPTURES + name + ".png")) == OK, "Saved " + name)

func text_fits(node: Node) -> void:
	if node is Label:
		for line in node.text.split("\n"):
			check(node.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, node.get_theme_font_size("font_size")).x <= node.size.x, "Text fits: " + line)
	for child in node.get_children():
		text_fits(child)

func run() -> void:
	# Finish the native startup fullscreen transition before setting capture size.
	if DisplayServer.get_name() != "headless":
		await create_timer(0.8, true, false, true).timeout
	root.mode = Window.MODE_WINDOWED
	if DisplayServer.get_name() != "headless":
		await create_timer(0.8, true, false, true).timeout
	root.size = Vector2i(1280, 800)
	var home: Control = load(HOME).instantiate()
	root.add_child(home)
	current_scene = home
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
	await settle()
	var warmup_deadline := Time.get_ticks_usec() + 5000000
	while not home._effects_ready and Time.get_ticks_usec() < warmup_deadline:
		await process_frame
	check(home._effects_ready, "Play becomes ready after the local effect warmup")
	check(ProjectSettings.get_setting("application/run/main_scene") == HOME, "Project opens the home screen")
	check(is_equal_approx(home.display_scale, 800.0 / 384.0), "Home fills the height of a 1280x800 window")
	text_fits(home.menu)
	await capture("home_fit")
	click(Vector2(224, 326))
	await settle()
	check(home.menu.get_node("Guide").visible, "How to Play opens through real pointer routing")
	check(home.menu.get_node("Guide/Panel/Back").has_focus(), "Guide receives keyboard focus")
	click(Vector2(224, 285))
	await settle()
	check(current_scene == home and home.menu.get_node("Guide").visible, "Guide blocks the Play button underneath")
	await capture("guide_fit")
	key(KEY_ESCAPE)
	await settle()
	check(not home.menu.get_node("Guide").visible, "Escape closes the controls guide")
	check(home.menu.get_node("HowToPlay").has_focus(), "Closing the guide restores menu focus")
	key(KEY_ENTER)
	await settle()
	check(home.menu.get_node("Guide").visible, "Enter opens How to Play")
	key(KEY_ENTER)
	await settle()
	check(not home.menu.get_node("Guide").visible, "Enter activates Got It")
	for spec in [[Vector2i(448, 384), 1, "home_1x"], [Vector2i(1440, 1200), 3.125, "home_fit_large"]]:
		root.size = spec[0]
		await settle()
		check(is_equal_approx(home.display_scale, spec[1]), "Home fits at scale %s" % spec[1])
		click(Vector2(224, 326))
		await settle()
		check(home.menu.get_node("Guide").visible, "Guide pointer routing works at scale %s" % spec[1])
		click(Vector2(224, 322))
		await settle()
		check(not home.menu.get_node("Guide").visible, "Got It pointer routing works at scale %s" % spec[1])
		await capture(spec[2])
	root.size = Vector2i(1280, 800)
	await settle()
	click(Vector2(224, 285))
	await settle()
	check(current_scene.scene_file_path == "res://experiments/pixel_pivot/pixel_pivot.tscn", "Play loads the actual game")
	var arena: Node2D = current_scene.get_node("View/World/PixelArena")
	arena.set_focused(true)
	var player: CharacterBody2D = arena.get_node("Slime")
	check(arena.remaining_eyes == arena.eyes.size() and not arena.started and not player.aiming, "Play click cannot leak into a slime launch")
	check(is_equal_approx(current_scene.display_scale, 800.0 / 336.0), "Gameplay fills the window at its own aspect ratio")
	click(Vector2(358, 16))
	await settle()
	check(arena.suspended, "Pause still works after entering from Home")
	await capture("paused_with_home")
	click(Vector2(224, 292))
	await settle()
	check(current_scene.scene_file_path == HOME and Engine.time_scale == 1.0, "Pause Home returns without leaking time scale")
	key(KEY_ENTER)
	await settle()
	check(current_scene.scene_file_path != HOME, "Enter starts the game from the focused Play button")
	arena = current_scene.get_node("View/World/PixelArena")
	arena.set_focused(true)
	for eye in arena.eyes:
		eye.try_hit(eye.wall, eye.position, eye.facing_normal, 288.0)
	check(arena.cleared, "Room can still clear after a return to Home")
	await create_timer(arena.get_node("HUD/Control").clear_reveal_delay + 0.08, true, false, true).timeout
	click(Vector2(224, 292))
	await settle()
	check(current_scene.scene_file_path == HOME and Engine.time_scale == 1.0, "Clear Home returns to the title screen")
	current_scene.queue_free()
	await process_frame
	check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "Home restores the window's original stretch mode")
	print("Home screen: ", checks, " checks, ", failures.size(), " failures: ", failures)
	quit(0 if failures.is_empty() else 1)
