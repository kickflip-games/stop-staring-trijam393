extends SceneTree
## Native captures and real wall sweeps for action-driven feedback.
const ContactFixture = preload("res://experiments/pixel_pivot/tests/eye_contact_fixture.gd")
const BASE := "res://experiments/pixel_pivot/"
const CAPTURES := "res://../docs/juice/"
var presentation: Control
var arena: Node2D
var player: CharacterBody2D
var clock: Node
var effects: Node2D
var hud: Control
var checks := 0
var failures: Array[String] = []
var camera: Camera2D

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func wait_real(seconds: float) -> void:
	var deadline := Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < deadline:
		await process_frame
	await process_frame

func hit_sweep(eye: Node2D) -> void:
	if eye.active:
		check(ContactFixture.sweep(player, eye), "Target closes through real swept collision")

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	hud.update_hud()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(CAPTURES + filename + ".png")) == OK, "Saved " + filename)

func capture_held(filename: String) -> void:
	# Freeze only the fixture's visual clock so the requested short-lived
	# silhouette is present even if shader compilation costs a native frame.
	clock.set_process(false)
	clock.real_delta = 0.0
	await capture(filename)
	clock.set_process(true)
	clock._last_usec = Time.get_ticks_usec()

func pointer(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = presentation.get_node("View").position + point * presentation.display_scale
	event.global_position = event.position
	event.pressed = pressed
	root.push_input(event)

func test_feedback() -> void:
	await wait_real(0.12)
	check(effects.trails.is_empty() and effects.particles.is_empty() and effects.rings.is_empty(), "Idle room has no ambient feedback particles")
	check(effects.aim_amount == 0.0 and effects._screen_flash == 0.0, "Idle screen treatment resolves to the original room")
	check(effects.get_node("RoomFeedback/Screen").mouse_filter == Control.MOUSE_FILTER_IGNORE, "Screen feedback passes pointer input through")
	pointer(Vector2(240, 220), true)
	var motion := InputEventMouseMotion.new()
	motion.position = presentation.get_node("View").position + Vector2(192, 220) * presentation.display_scale
	motion.global_position = motion.position
	root.push_input(motion)
	await wait_real(0.16)
	check(player.aiming and Engine.time_scale == 0.25 and effects.aim_amount > 0.9, "Native drag slows gameplay and dims/desaturates the room")
	check(player.visual.scale.x > 1.45 and player.visual.scale.y < 0.8, "Full charge stretches only the slime visual")
	check(player.scale == Vector2.ONE and player.get_node("CollisionShape2D").scale == Vector2.ONE, "Charge never scales the physical collider")
	check(effects.get_node("Aim").playing, "Charge plays the restrained rubber cue")
	pointer(Vector2(192, 220), false)
	check(Engine.time_scale == 1.0 and not player.aiming and effects.aim_amount == 0.0, "Native launch restores full speed and room color in the same event")
	check(player.velocity == Vector2(288, 0) and effects.launch_age == 0.0, "Launch speed is retained and starts the bright trail")
	check(effects.get_node("Launch").playing and not effects.get_node("Aim").playing, "Sharp whoosh replaces the rubber cue")
	check(camera.offset == Vector2(-1, 0) and camera.zoom == Vector2.ONE, "Launch pulls the fixed camera by one logical pixel")
	check(not effects.trails.is_empty() and effects.trails[0].bright, "Bright trail exists on the launch frame")
	arena.retry()
	player.position = Vector2(200, 90)
	player.velocity = Vector2(0, -288)
	player.advance(0.16)
	check(arena.remaining_eyes == arena.eyes.size() and arena.closed_eyes == 0 and Engine.time_scale == 1.0, "Ordinary wall bounce cannot close an eye or cause hit-stop")
	check(effects.get_node("Wall").playing and not effects.get_node("Pop").playing, "Wall bounce receives its own soft thud")
	check(effects.particles.size() == 4 and effects.rings.is_empty() and effects.flashes.is_empty(), "Wall receives only a small four-pixel dust burst")
	check(camera.offset.length() <= 1.0 and player._impact_amount < 0.5, "Wall bump and squash remain modest")
	arena.retry()
	var eye: Node2D = arena.eyes[8]
	hit_sweep(eye)
	check(Engine.time_scale == 0.0 and clock._stop_until - Time.get_ticks_usec() <= 40000, "Eye contact applies the 40ms real-time hit-stop")
	check(player._impact_amount == 1.0 and player.eye_hit_this_contact, "Eye contact retains the strong squash through the wall collision")
	check(effects.get_node("Pop").playing and not effects.get_node("Wall").playing, "Eye contact avoids the duplicate wall sound")
	check(effects.particles.size() == 16 and effects.rings.size() == 1 and effects.flashes.size() == 1, "Eye contact creates pixel burst, shockwave and white flash")
	check(not eye.pupil.visible and eye.eyeball.scale.x > 1.2, "Eye bulges and hides its pupil on the hit frame")
	check(camera.offset.length() == 2.0 and hud.get_node("Remaining").text == "CLOSED 1 / 16", "Eye impact retains feedback and updates the closed count")
	await wait_real(0.22)
	check(eye.closed_visual.visible and not eye.eyeball.visible and not eye.pupil.visible, "Closed state settles into the supplied dark eyelid pose")
	check(eye.get_node("Visual/Socket").self_modulate.r < eye._socket_color.r, "Closed socket darkens")
	arena.set_process(false)
	eye.closed_remaining = 2.75
	eye._process(0.0)
	check(absf(eye.closed_visual.rotation) > 0.01, "Only this eye twitches during its local warning")
	check(hud.get_node("Elapsed").scale == Vector2.ONE, "Local warning never turns score time into a deadline")
	arena.toggle_pause()
	var remaining: float = eye.closed_remaining
	await wait_real(0.06)
	check(eye.closed_remaining == remaining, "Pause preserves the independent closed duration")
	arena.resume()
	player.begin_aim(Vector2(240, 220))
	player.velocity = Vector2(180, 80)
	var prior_position := player.position
	arena._last_tick -= 3000000
	arena.advance_time()
	check(eye.active and arena.closed_eyes == 0 and not eye.closed_timer_active, "Only the expired target reopens and clears its own timer")
	var direction: Vector2 = (player.global_position - eye.visual.global_position).normalized() * eye.tracking_limit
	check(eye.pupil.visible and eye.pupil.position == direction.round() and eye._snap_age >= 0.0, "Reopened pupil locks onto the slime during the local snap")
	check(player.position == prior_position and player.velocity == Vector2(180, 80) and player.aiming and Engine.time_scale == 0.25, "Snap open preserves movement, input and aim speed")
	check(not hud.blocks_pointer(Vector2(224, 224)), "Local reopen never blocks controls")
	arena.set_process(true)
	arena.retry()
	for target in arena.eyes:
		hit_sweep(target)
	check(arena.cleared and not player.input_enabled and Engine.time_scale == 0.0, "Final real sweep freezes and blocks input immediately")
	check(clock._stop_until - Time.get_ticks_usec() > 95000, "Final hit holds longer than an ordinary eye impact")
	check(not hud.get_node("Modal").visible and hud.blocks_pointer(Vector2(224, 224)), "Final-hit feedback remains visible before the modal while input stays blocked")
	await wait_real(0.16)
	check(effects._silenced and not effects.get_node("Pop").playing and not effects.get_node("Snap").playing, "Impact gives way to a quiet win beat")
	await wait_real(0.45)
	check(hud.get_node("Modal").visible and effects.particles.is_empty() and effects.rings.is_empty() and effects.flashes.is_empty(), "Win panel follows the resolved effects")
	check(hud.get_node("Modal/Panel/Title").text == "FINALLY." and hud.get_node("Modal/Panel/Detail").text.contains("CLEAR TIME"), "Win message includes peace and quiet and the clear time")
	for index in range(5):
		arena.retry()
		player.begin_aim(Vector2(240, 220))
		hit_sweep(arena.eyes[0])
		arena.retry()
		check(Engine.time_scale == 1.0 and camera.offset == Vector2.ZERO and arena.closed_eyes == 0 and effects.win_age == -1.0 and hud._win_age == -1.0, "Rapid retry cancels all clock, camera, eye timers and win state")
	await wait_real(0.6)
	check(not hud.get_node("Modal").visible and effects.particles.is_empty(), "A cancelled win/reopen cannot reappear after retry")

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
	arena = presentation.get_node("View/World/PixelArena")
	player = arena.get_node("Slime")
	clock = arena.get_node("Clock")
	effects = arena.get_node("Effects")
	hud = arena.get_node("HUD/Control")
	camera = arena.get_node("CameraRig/Camera2D")
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		await wait_real(0.15)
	arena.set_focused(true)
	player.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURES))
	var prefix := "before_" if "--baseline" in OS.get_cmdline_user_args() else "after_"
	if prefix == "after_":
		await test_feedback()
	await capture(prefix + "idle")
	player.begin_aim(Vector2(240, 220))
	player.update_aim(Vector2(192, 220))
	await wait_real(0.18)
	await capture(prefix + "aim")
	player.release_aim(Vector2(192, 220))
	player.advance(1.0 / 60.0)
	await capture(prefix + "launch")
	hit_sweep(arena.eyes[8])
	await capture_held(prefix + "hit")
	if prefix == "after_":
		clock.real_delta = 0.09
		effects._process(0.0)
		arena.eyes[8]._process(0.0)
		clock.real_delta = 0.0
		await capture_held(prefix + "burst")
	await wait_real(0.24)
	await capture(prefix + "closed")
	for eye in arena.eyes.slice(0, 7):
		hit_sweep(eye)
	await wait_real(0.24)
	arena.set_process(false)
	arena.eyes[8].closed_remaining = 2.75
	arena.eyes[8]._process(0.0)
	await capture(prefix + "urgent")
	if prefix == "after_":
		await capture_held(prefix + "anticipation")
	arena._last_tick -= 3000000
	arena.advance_time()
	await capture(prefix + "reopen")
	arena.set_process(true)
	for eye in arena.eyes:
		hit_sweep(eye)
	await capture_held(prefix + "final_hit")
	await wait_real(0.82)
	await capture(prefix + "win")
	arena.retry()
	presentation.queue_free()
	await process_frame
	check(Engine.time_scale == 1.0, "Scene exit restores normal time")
	print("Juice: ", checks, " checks, ", failures.size(), " failures: ", failures)
	quit(0 if failures.is_empty() else 1)
