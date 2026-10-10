extends SceneTree
## Godot --headless --path stop_staring --script res://tests/menu_levels.gd

var failures: Array[String] = []
var game: Node

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	root.size = Vector2i(1280, 800)
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await capture("/tmp/stop-staring-splash.png")
	check(game.mode == "splash", "boot shows splash")
	game.show_menu()
	await settle_transition()
	await process_frame
	await capture("/tmp/stop-staring-menu.png")
	await press("LEVEL SELECT")
	check(game.mode == "select", "level select button opens selection")
	await process_frame
	await capture("/tmp/stop-staring-level-select.png")
	await press("BACK")
	await press("START")
	check(game.mode == "playing" and game.active_level == 0, "start opens first room")
	await physics_frame
	await physics_frame
	check(game.gameplay.remaining_eyes == 1, "first room has one eye")
	var before: Node = game.gameplay
	await press("RETRY  [R]")
	check(game.gameplay != before and game.gameplay.remaining_eyes == 1 and game.elapsed < 0.05, "retry reloads targets and timer")
	for index in range(3):
		game.show_level_select()
		await settle_transition()
		await press("%02d   %s" % [index + 1, game.LEVELS[index].name.to_upper()])
		await physics_frame
		await physics_frame
		check(game.active_level == index and game.mode == "playing", "direct selection opens requested room")
		check(game.gameplay.remaining_eyes == [1, 3, 6][index], "room uses its own eye layout")
		if index == 2:
			await capture("/tmp/stop-staring-level-three.png")
		var level: Node3D = game.gameplay
		level.get_node("Player").set_physics_process(false)
		for eye in level._eyes:
			var normal: Vector3 = eye.global_basis * Vector3.DOWN
			var contact: Vector3 = eye.global_position
			contact.z = 0
			check(eye.try_hit(eye._wall, contact, normal, 10), "each configured eye accepts its wall hit")
		check(game.mode == "clear" and level.remaining_eyes == 0, "last eye opens clear screen")
		check(not level.get_node("Player").is_processing_unhandled_input(), "clear screen stops gameplay input")
		await create_timer(0.3).timeout
		if index == 1:
			await capture("/tmp/stop-staring-level-clear.png")
		if index < 2:
			await press("NEXT LEVEL")
			check(game.active_level == index + 1 and game.mode == "playing", "next button advances exactly one room")
		else:
			check(find_button("NEXT LEVEL") == null, "final room has no invalid next level")
			await press("MAIN MENU")
	check(game.mode == "menu" and game.gameplay == null, "menu removes gameplay")
	game.start_level(-1)
	game.start_level(3)
	check(game.mode == "menu", "invalid level indices are ignored")
	game.mode = "splash"
	game._show_splash()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(640, 400)
	click.pressed = true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await settle_transition()
	check(game.mode == "menu", "clicking logo skips splash")
	game.mode = "splash"
	game._show_splash()
	await create_timer(1.9).timeout
	await settle_transition()
	check(game.mode == "menu", "splash automatically reaches title")
	game.start_level(1)
	await settle_transition()
	var previous: Node = game.gameplay
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await settle_transition()
	check(game.gameplay != previous and game.active_level == 1, "R retries current room")
	key = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await settle_transition()
	check(game.mode == "menu" and game.gameplay == null, "Escape returns to menu")
	if failures.is_empty():
		print("PASS: splash, menu buttons, direct selection, three layouts, retry/timer reset, eye-clear progression, final room and menu teardown")
	else:
		for message in failures:
			push_error(message)
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)

func find_button(text: String) -> Button:
	for node in game._ui.find_children("*", "Button", true, false):
		if node.text == text:
			return node
	return null

func press(text: String) -> void:
	var button := find_button(text)
	check(button != null, "button exists: " + text)
	if button:
		button.pressed.emit()
		await settle_transition()

func settle_transition() -> void:
	var transition := root.get_node("EasyTransition")
	while transition.is_transitioning:
		await process_frame
	game = current_scene

func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func check(passed: bool, message: String) -> void:
	if not passed:
		failures.append(message)
