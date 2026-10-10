extends SceneTree
## Check real GUI routing and capture the UI at native aspect-fitted scales.
const BASE := "res://experiments/pixel_pivot/"
const CAPTURES := "res://../docs/retro_ui/"
var failures: Array[String] = []
var checks := 0
var presentation: Control
var arena: Node2D
var player: CharacterBody2D
var hud: Control

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func pointer(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = presentation.get_node("View").position + point * presentation.display_scale
	event.global_position = event.position
	event.pressed = pressed
	root.push_input(event)

func click(point: Vector2) -> void:
	pointer(point, true)
	pointer(point, false)

func text_fits(label: Label) -> void:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	for line in label.text.split("\n"):
		check(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= label.size.x, "%s text fits its slot: %s" % [label.name, line])

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	arena.set_focused(true)
	hud.update_hud()
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path(CAPTURES)
	check(root.get_texture().get_image().save_png(folder + filename + ".png") == OK, "Runtime capture saved: " + filename)

func run() -> void:
	# Finish the native startup fullscreen transition before setting capture size.
	if DisplayServer.get_name() != "headless":
		await create_timer(0.8, true, false, true).timeout
	root.mode = Window.MODE_WINDOWED
	if DisplayServer.get_name() != "headless":
		await create_timer(0.8, true, false, true).timeout
	root.size = Vector2i(1280, 800)
	presentation = load(BASE + "pixel_pivot.tscn").instantiate()
	root.add_child(presentation)
	current_scene = presentation
	await process_frame
	await process_frame
	arena = presentation.get_node("View/World/PixelArena")
	player = arena.get_node("Slime")
	hud = arena.get_node("HUD/Control")
	arena.set_focused(true)
	player.set_physics_process(false)
	check(hud.get_theme_font("font") is FontFile, "Bundled pixel font is active")
	check(hud.get_theme_font("font").antialiasing == 0, "Font antialiasing disabled")
	check(hud.get_theme_font_size("font_size") == 8, "Native eight-pixel font grid")
	var header: Rect2 = hud.get_node("Header").get_rect()
	for name in ["Remaining", "Title", "Message", "TimeCaption", "Elapsed", "Pause", "Retry"]:
		var control: Control = hud.get_node(name)
		check(header.encloses(control.get_rect()), name + " stays inside the header")
		if control is Label:
			text_fits(control)
	check(header.end.y <= 32, "HUD leaves the wall art and room unobscured")
	await capture("gameplay")

	pointer(Vector2(180, 120), true)
	pointer(Vector2(132, 120), false)
	check(arena.started and not player.aiming, "Native launch still starts gameplay")
	hud.update_hud()
	text_fits(hud.get_node("Message"))
	click(Vector2(358, 16))
	await process_frame
	check(arena.suspended and hud.get_node("Modal").visible, "Pause button opens the pause screen")
	var paused_time: float = arena.elapsed
	await create_timer(0.04, true, false, true).timeout
	check(is_equal_approx(arena.elapsed, paused_time), "Pause button suspends the timer")
	click(Vector2(200, 180))
	check(not player.aiming, "Clicking the pause panel cannot launch")
	text_fits(hud.get_node("Modal/Panel/Title"))
	text_fits(hud.get_node("Modal/Panel/Detail"))
	await capture("paused")
	click(Vector2(224, 228))
	await process_frame
	check(not arena.suspended and not hud.get_node("Modal").visible, "Continue button returns to gameplay")

	pointer(Vector2(180, 120), true)
	check(player.aiming, "Native press begins aiming after Continue")
	pointer(Vector2(358, 16), false)
	check(not player.aiming and Engine.time_scale == 1.0, "Releasing over a header control cancels aim (aim=%s, scale=%s)" % [player.aiming, Engine.time_scale])
	check(hud.get_node("Elapsed").visible and hud.get_node("TimeCaption").text == "RUN", "Launch shows the overall run clock rather than a deadline")
	var first_eye: Node2D = arena.eyes[0]
	first_eye.try_hit(first_eye.wall, first_eye.position, first_eye.facing_normal, 288.0)
	hud.update_hud()
	check(hud.get_node("Remaining").text == "CLOSED 1 / 16" and hud.get_node("Elapsed").text == "%.1f" % arena.elapsed, "First eye updates closed count without replacing run time")
	text_fits(hud.get_node("Remaining"))
	text_fits(hud.get_node("Elapsed"))
	arena.elapsed = 42.7
	for eye in arena.eyes:
		eye.try_hit(eye.wall, eye.position, eye.facing_normal, 288.0)
	hud.update_hud()
	text_fits(hud.get_node("Remaining"))
	check(arena.cleared and not hud.get_node("Modal").visible, "Last target resolves its feedback before the clear screen")
	await create_timer(0.6, true, false, true).timeout
	hud.update_hud()
	check(hud.get_node("Modal").visible, "Clear screen reveals after the final impact")
	check(not hud.get_node("Modal/Panel/Resume").visible, "Clear screen offers replay")
	text_fits(hud.get_node("Modal/Panel/Title"))
	text_fits(hud.get_node("Modal/Panel/Detail"))
	check(hud.get_node("Modal/Panel/Detail").text.contains("CLEAR TIME"), "Clear screen includes total real clear time")
	# Let the existing pop animation finish before showing the empty sockets.
	await create_timer(0.18, true, false, true).timeout
	await capture("clear")
	click(Vector2(224, 260))
	await process_frame
	check(not arena.cleared and arena.remaining_eyes == arena.eyes.size() and arena.elapsed == 0.0, "Play Again button resets the room and timer")
	check(not hud.get_node("Modal").visible and not player.aiming, "Replay closes the modal without launching")
	arena.set_focused(false)
	check(hud.get_node("Modal").visible and hud.get_node("Modal/Panel/Resume").disabled, "Inactive window suspends play with a disabled Continue button")
	arena.set_focused(true)
	check(not hud.get_node("Modal").visible, "Returning focus resumes without an explicit pause")

	for spec in [[Vector2i(448, 384), 1, "gameplay_1x"], [Vector2i(1440, 1200), 1440.0 / 448.0, "gameplay_fit_large"]]:
		root.size = spec[0]
		await process_frame
		presentation.fit_view()
		arena.set_focused(true)
		check(is_equal_approx(presentation.display_scale, spec[1]), "Aspect-fitted UI scale: %s" % spec[1])
		click(Vector2(412, 16))
		check(not player.aiming and not arena.started, "Retry clicks cannot launch at scale %s" % spec[1])
		await capture(spec[2])
	presentation.queue_free()
	await process_frame
	check(Engine.time_scale == 1.0, "Exiting the UI restores time scale")
	print("Retro UI: ", checks, " checks, ", failures.size(), " failures: ", failures)
	quit(0 if failures.is_empty() else 1)
